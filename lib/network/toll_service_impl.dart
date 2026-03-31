part of 'toll_service.dart';

/// Estimates toll cost for a driving route in Hong Kong.
///
/// Data sources:
/// - Fixed tolls: Transport Department toll rates page.
/// - Time-varying tolls (Road Harbour Crossings + Tai Lam Tunnel): HKeMobility
///   online enquiry backend (`/api/drss/toll/*`).
class TollService {
  TollService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, double?> _rateCache = {};
  final Map<String, Future<double?>> _rateInFlight = {};

  void dispose() => _client.close();

  List<TollFacilityInfo> listFacilities() {
    return _facilities
        .map(
          (facility) => TollFacilityInfo(
            id: facility.id,
            nameEn: facility.nameEn,
            nameTc: facility.nameTc,
            nameSc: facility.nameSc,
            hkMobilityTunnelCode: facility.hkMobilityTunnelCode,
            fixedRates: facility.fixedRates,
          ),
        )
        .toList(growable: false);
  }

  Future<double?> fetchRateForFacility({
    required TollFacilityInfo facility,
    required HkVehicleType vehicleType,
    required DateTime dateTime,
  }) async {
    if (facility.hkMobilityTunnelCode != null) {
      return _fetchTimeVaryingRate(
        tunnelCode: facility.hkMobilityTunnelCode!,
        vehicleType: vehicleType,
        dateTimeParam: formatDateTimeParam(dateTime),
      );
    }
    return facility.fixedRates?[vehicleType];
  }

  Future<String> fetchHkNowParam() async {
    final uri = Uri.https('www.hkemobility.gov.hk', '/api/drss/toll/time');
    try {
      final res = await _client.get(uri, headers: _hkMobilityHeaders);
      if (res.statusCode != 200) return formatDateTimeParam(DateTime.now());
      final decoded = jsonDecode(res.body);
      if (decoded is! String) return formatDateTimeParam(DateTime.now());
      final m = RegExp(
        r'^(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2})',
      ).firstMatch(decoded);
      if (m == null) return formatDateTimeParam(DateTime.now());
      return '${m.group(1)} ${m.group(2)}';
    } catch (_) {
      return formatDateTimeParam(DateTime.now());
    }
  }

  Future<TollEstimate> estimateForRoute({
    required List<LatLng> route,
    required LatLng origin,
    required LatLng destination,
    required String dateTimeParam,
    Iterable<String>? stepNames,
    String languageCode = 'en',
    HkVehicleType vehicleType = HkVehicleType.privateCar,
  }) async {
    final used = _detectFacilities(
      route: route,
      origin: origin,
      destination: destination,
      stepNames: stepNames,
    );
    if (used.isEmpty) return const TollEstimate(totalHkd: 0, charges: []);

    final charges = <TollCharge>[];
    for (final facility in used) {
      final facilityName = facility.nameForLanguageCode(languageCode);
      if (facility.hkMobilityTunnelCode != null) {
        final amount = await _fetchTimeVaryingRate(
          tunnelCode: facility.hkMobilityTunnelCode!,
          vehicleType: vehicleType,
          dateTimeParam: dateTimeParam,
        );
        charges.add(
          TollCharge(
            facilityId: facility.id,
            facilityName: facilityName,
            amountHkd: amount,
            isTimeVarying: true,
          ),
        );
        continue;
      }

      final fixed = facility.fixedRates?[vehicleType];
      charges.add(
        TollCharge(
          facilityId: facility.id,
          facilityName: facilityName,
          amountHkd: fixed,
          isTimeVarying: false,
        ),
      );
    }

    double total = 0;
    for (final c in charges) {
      if (c.amountHkd != null) total += c.amountHkd!;
    }
    return TollEstimate(totalHkd: total, charges: charges);
  }

  Future<double?> _fetchTimeVaryingRate({
    required String tunnelCode,
    required HkVehicleType vehicleType,
    required String dateTimeParam,
  }) async {
    final cacheKey = '$tunnelCode|${vehicleType.apiCode}|$dateTimeParam';
    if (_rateCache.containsKey(cacheKey)) return _rateCache[cacheKey];
    final inFlight = _rateInFlight[cacheKey];
    if (inFlight != null) return inFlight;

    final future = _fetchTimeVaryingRateUncached(
      tunnelCode: tunnelCode,
      vehicleType: vehicleType,
      dateTimeParam: dateTimeParam,
    ).then((value) {
      if (value != null) _rateCache[cacheKey] = value;
      return value;
    }).whenComplete(() {
      _rateInFlight.remove(cacheKey);
    });

    _rateInFlight[cacheKey] = future;
    return await future;
  }

  Future<double?> _fetchTimeVaryingRateUncached({
    required String tunnelCode,
    required HkVehicleType vehicleType,
    required String dateTimeParam,
  }) async {
    final useAll = vehicleType == HkVehicleType.taxi;
    final uri = Uri.https('www.hkemobility.gov.hk', '/api/drss/toll/rate', {
      'tunnel': tunnelCode,
      'vehicleType': useAll ? 'all' : vehicleType.apiCode,
      'date': dateTimeParam,
    });

    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final res = await _client
            .get(uri, headers: _hkMobilityHeaders)
            .timeout(const Duration(seconds: 10));

        if (res.statusCode == 200) {
          final decoded = jsonDecode(res.body);
          if (decoded is Map) {
            final key = useAll ? vehicleType.apiCode : vehicleType.apiCode;
            final v = decoded[key];
            if (v is num) return v.toDouble();

            final firstNum = decoded.values.firstWhere(
              (e) => e is num,
              orElse: () => null,
            );
            if (firstNum is num) return firstNum.toDouble();
          }
          return null;
        }

        // Retry on rate-limit or transient server errors.
        if (res.statusCode == 429 || res.statusCode >= 500) {
          await Future<void>.delayed(
            Duration(milliseconds: 250 * (attempt + 1)),
          );
          continue;
        }

        return null;
      } catch (_) {
        await Future<void>.delayed(
          Duration(milliseconds: 250 * (attempt + 1)),
        );
      }
    }

    return null;
  }

  List<_TollFacility> _detectFacilities({
    required List<LatLng> route,
    required LatLng origin,
    required LatLng destination,
    Iterable<String>? stepNames,
  }) {
    if (route.isEmpty) return const [];
    final used = <_TollFacility>[];
    final seenIds = <String>{};

    final normalizedStepNames = (stepNames ?? const <String>[])
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    final hasSteps = normalizedStepNames.isNotEmpty;
    final stepMatchedIds = hasSteps
        ? _facilityIdsFromStepNames(normalizedStepNames)
        : const <String>{};

    for (final facility in _facilities) {
      if (seenIds.contains(facility.id)) continue;
      if (!facility.appliesForTrip(origin: origin, destination: destination)) {
        continue;
      }

      if (hasSteps && _stepNameDetectableFacilityIds.contains(facility.id)) {
        if (stepMatchedIds.contains(facility.id)) {
          used.add(facility);
          seenIds.add(facility.id);
          // When OSRM step names confirm usage, don't also apply proximity
          // detection for the same facility (prevents double-charging).
          continue;
        }
        if (_stepNameOnlyFacilityIds.contains(facility.id)) {
          continue;
        }
      }

      if (_isNearRoute(
        route: route,
        points: facility.detectionPoints,
        thresholdMeters: facility.radiusMeters,
        minPointHits: facility.minPointHits,
      )) {
        used.add(facility);
        seenIds.add(facility.id);
      }
    }

    _pruneHarbourTunnelDuplicates(used: used, route: route);
    return used;
  }

  static void _pruneHarbourTunnelDuplicates({
    required List<_TollFacility> used,
    required List<LatLng> route,
  }) {
    const harbourIds = {'cht', 'ehc', 'whc'};
    final harbour = used
        .where((f) => harbourIds.contains(f.id))
        .toList(growable: false);
    if (harbour.length <= 1) return;

    final dist = const Distance();
    double minDistance(_TollFacility f) {
      var best = double.infinity;
      for (final p in f.detectionPoints) {
        for (final r in route) {
          final d = dist(p, r);
          if (d < best) best = d;
        }
      }
      return best;
    }

    var keep = harbour.first;
    var keepMeters = minDistance(keep);
    for (final f in harbour.skip(1)) {
      final m = minDistance(f);
      if (m < keepMeters) {
        keep = f;
        keepMeters = m;
      }
    }

    used.removeWhere((f) => harbourIds.contains(f.id) && f.id != keep.id);
  }

  static const Set<String> _stepNameDetectableFacilityIds = {
    'cht',
    'ehc',
    'whc',
    'tlt',
    'aberdeen',
    'shing_mun',
    'lion_rock',
    'route9_tunnels',
    'tates_cairn',
  };

  static const Set<String> _stepNameOnlyFacilityIds = {
    // For cross-harbour tunnels, geometry proximity is too noisy (routes can
    // pass nearby on either side). Prefer OSRM step names and ensure only one
    // is chosen.
    'cht',
    'ehc',
    'whc',
  };

  static Set<String> _facilityIdsFromStepNames(List<String> stepNames) {
    int? firstIndex(Map<String, int> map, String key) =>
        map.containsKey(key) ? map[key] : null;

    final counts = <String, int>{};
    final firstHitAt = <String, int>{};

    bool hasAt(String stepName, String pattern) =>
        _stepNameContains(stepName, pattern);

    for (var i = 0; i < stepNames.length; i++) {
      final n = stepNames[i];

      // Cross-harbour tunnels: mutually exclusive; avoid letting "海底隧道" match EHC/WHC.
      final isEhc =
          hasAt(n, 'eastern harbour crossing') || n.contains('東區海底隧道');
      final isWhc =
          hasAt(n, 'western harbour crossing') || n.contains('西區海底隧道');
      final isCht =
          hasAt(n, 'cross harbour tunnel') ||
          hasAt(n, 'cross-harbour tunnel') ||
          (n.contains('海底隧道') &&
              !n.contains('東區海底隧道') &&
              !n.contains('西區海底隧道'));

      void hit(String id) {
        counts[id] = (counts[id] ?? 0) + 1;
        firstHitAt.putIfAbsent(id, () => i);
      }

      if (isEhc) hit('ehc');
      if (isWhc) hit('whc');
      if (isCht) hit('cht');

      if (hasAt(n, 'tai lam tunnel') || n.contains('大欖隧道')) hit('tlt');
      if (hasAt(n, "tate's cairn tunnel") ||
          hasAt(n, 'tates cairn tunnel') ||
          n.contains('大老山隧道')) {
        hit('tates_cairn');
      }
      if (hasAt(n, 'shing mun tunnel') ||
          hasAt(n, 'shing mun tunnels') ||
          n.contains('城門隧道')) {
        hit('shing_mun');
      }
      if (hasAt(n, 'aberdeen tunnel') || n.contains('香港仔隧道')) hit('aberdeen');
      if (hasAt(n, 'lion rock tunnel') || n.contains('獅子山隧道')) hit('lion_rock');

      final isRoute9 =
          hasAt(n, 'sha tin heights tunnel') ||
          hasAt(n, "eagle's nest tunnel") ||
          hasAt(n, 'eagles nest tunnel') ||
          hasAt(n, 'tai wai tunnel') ||
          n.contains('沙田嶺隧道') ||
          n.contains('鷹巢山隧道') ||
          n.contains('大圍隧道');
      if (isRoute9) hit('route9_tunnels');
    }

    final result = <String>{};

    // Choose at most one cross-harbour tunnel.
    const harbourIds = ['cht', 'ehc', 'whc'];
    String? pick;
    var bestCount = 0;
    var bestIndex = 1 << 30;
    for (final id in harbourIds) {
      final c = counts[id] ?? 0;
      if (c <= 0) continue;
      final idx = firstIndex(firstHitAt, id) ?? bestIndex;
      if (c > bestCount || (c == bestCount && idx < bestIndex)) {
        pick = id;
        bestCount = c;
        bestIndex = idx;
      }
    }
    if (pick != null) result.add(pick);

    for (final entry in counts.entries) {
      if (entry.value <= 0) continue;
      if (harbourIds.contains(entry.key)) continue;
      result.add(entry.key);
    }

    return result;
  }

  static bool _stepNameContains(String stepName, String pattern) {
    final pCompact = _compactAscii(pattern);
    if (pCompact.isNotEmpty) {
      return _compactAscii(stepName).contains(pCompact);
    }
    return stepName.toLowerCase().contains(pattern.toLowerCase());
  }

  static String _compactAscii(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  bool _isNearRoute({
    required List<LatLng> route,
    required List<LatLng> points,
    required double thresholdMeters,
    int minPointHits = 1,
  }) {
    final dist = const Distance();
    var hits = 0;
    final requiredHits = minPointHits <= 0 ? 1 : minPointHits;
    for (final p in points) {
      for (final r in route) {
        if (dist(p, r) <= thresholdMeters) {
          hits += 1;
          if (hits >= requiredHits) return true;
          break;
        }
      }
    }
    return false;
  }

  static String formatDateTimeParam(DateTime dt) {
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  static const Map<String, String> _hkMobilityHeaders = {
    'Accept': 'application/json',
    'User-Agent': 'parking_app',
    'Origin': 'https://www.hkemobility.gov.hk',
    'Referer': 'https://www.hkemobility.gov.hk/en/toll-rate/',
  };

  static const List<_TollFacility> _facilities = [
    _TollFacility.timeVaryingTunnel(
      id: 'cht',
      nameEn: 'Cross Harbour Tunnel',
      nameTc: '紅磡海底隧道',
      nameSc: '红磡海底隧道',
      hkMobilityTunnelCode: 'cht',
      detectionPoints: [LatLng(22.291910, 114.181980)],
      radiusMeters: 650,
    ),
    _TollFacility.timeVaryingTunnel(
      id: 'ehc',
      nameEn: 'Eastern Harbour Crossing',
      nameTc: '東區海底隧道',
      nameSc: '东区海底隧道',
      hkMobilityTunnelCode: 'ehc',
      detectionPoints: [LatLng(22.294832, 114.222258)],
      radiusMeters: 650,
    ),
    _TollFacility.timeVaryingTunnel(
      id: 'whc',
      nameEn: 'Western Harbour Crossing',
      nameTc: '西區海底隧道',
      nameSc: '西区海底隧道',
      hkMobilityTunnelCode: 'whc',
      detectionPoints: [LatLng(22.295519, 114.151347)],
      radiusMeters: 650,
    ),
    _TollFacility.timeVaryingTunnel(
      id: 'tlt',
      nameEn: 'Tai Lam Tunnel',
      nameTc: '大欖隧道',
      nameSc: '大榄隧道',
      hkMobilityTunnelCode: 'tlt',
      detectionPoints: [LatLng(22.381466, 114.063477)],
      radiusMeters: 650,
    ),
    _TollFacility.fixedTunnel(
      id: 'aberdeen',
      nameEn: 'Aberdeen Tunnel',
      nameTc: '香港仔隧道',
      nameSc: '香港仔隧道',
      fixedRates: {
        HkVehicleType.privateCar: 8,
        HkVehicleType.motorcycle: 8,
        HkVehicleType.taxi: 8,
      },
      detectionPoints: [LatLng(22.256678, 114.180082)],
      radiusMeters: 700,
    ),
    _TollFacility.fixedTunnel(
      id: 'shing_mun',
      nameEn: 'Shing Mun Tunnels',
      nameTc: '城門隧道',
      nameSc: '城门隧道',
      fixedRates: {
        HkVehicleType.privateCar: 8,
        HkVehicleType.motorcycle: 8,
        HkVehicleType.taxi: 8,
      },
      detectionPoints: [LatLng(22.377354, 114.154293)],
      radiusMeters: 650,
    ),
    _TollFacility.fixedTunnel(
      id: 'lion_rock',
      nameEn: 'Lion Rock Tunnel',
      nameTc: '獅子山隧道',
      nameSc: '狮子山隧道',
      fixedRates: {
        HkVehicleType.privateCar: 8,
        HkVehicleType.motorcycle: 8,
        HkVehicleType.taxi: 8,
      },
      detectionPoints: [LatLng(22.351235, 114.177349)],
      radiusMeters: 700,
    ),
    _TollFacility.fixedTunnel(
      id: 'route9_tunnels',
      nameEn: "Route 9 Tunnels (Sha Tin Heights / Eagle's Nest / Tai Wai)",
      nameTc: '九號幹線隧道（沙田嶺／尖山／大圍）',
      nameSc: '九号干线隧道（沙田岭／尖山／大围）',
      fixedRates: {
        HkVehicleType.privateCar: 8,
        HkVehicleType.motorcycle: 8,
        HkVehicleType.taxi: 8,
      },
      detectionPoints: [LatLng(22.350055, 114.156605)],
      radiusMeters: 650,
    ),
    _TollFacility.fixedTunnel(
      id: 'tates_cairn',
      nameEn: "Tate's Cairn Tunnel",
      nameTc: '大老山隧道',
      nameSc: '大老山隧道',
      fixedRates: {
        HkVehicleType.privateCar: 20,
        HkVehicleType.motorcycle: 15,
        HkVehicleType.taxi: 20,
      },
      // Use the toll plaza to avoid false positives from nearby surface roads
      // around Diamond Hill / East Kowloon.
      detectionPoints: [LatLng(22.369807, 114.213204)],
      radiusMeters: 650,
    ),
    _TollFacility.fixedTunnel(
      id: 'discovery_bay_link',
      nameEn: 'Discovery Bay Tunnel Link (DB-bound)',
      nameTc: '愉景灣隧道連接路（往愉景灣）',
      nameSc: '愉景湾隧道连接路（往愉景湾）',
      fixedRates: {
        HkVehicleType.privateCar: 250,
      },
      detectionPoints: [LatLng(22.310105, 114.002241)],
      radiusMeters: 700,
      destinationProximityRuleMeters: 8000,
    ),
  ];
}

class TollFacilityInfo {
  const TollFacilityInfo({
    required this.id,
    required this.nameEn,
    required this.nameTc,
    required this.nameSc,
    required this.hkMobilityTunnelCode,
    required this.fixedRates,
  });

  final String id;
  final String nameEn;
  final String nameTc;
  final String nameSc;
  final String? hkMobilityTunnelCode;
  final Map<HkVehicleType, double>? fixedRates;

  bool get isTimeVarying => hkMobilityTunnelCode != null;

  String nameForLanguageCode(String languageCode) {
    switch (languageCode.toLowerCase()) {
      case 'tc':
        return nameTc.isNotEmpty ? nameTc : nameEn;
      case 'sc':
        return nameSc.isNotEmpty
            ? nameSc
            : (nameTc.isNotEmpty ? nameTc : nameEn);
      case 'en':
      default:
        return nameEn.isNotEmpty
            ? nameEn
            : (nameTc.isNotEmpty ? nameTc : nameSc);
    }
  }
}

enum HkVehicleType { privateCar, motorcycle, taxi }

extension on HkVehicleType {
  String get apiCode {
    switch (this) {
      case HkVehicleType.privateCar:
        return 'pc';
      case HkVehicleType.motorcycle:
        return 'mc';
      case HkVehicleType.taxi:
        return 'taxi';
    }
  }
}

class TollEstimate {
  final double totalHkd;
  final List<TollCharge> charges;

  const TollEstimate({required this.totalHkd, required this.charges});

  bool get hasTolls => charges.isNotEmpty;
  bool get hasPayableTolls => charges.any((c) => (c.amountHkd ?? 0) > 0);
  bool get hasUnknown => charges.any((c) => c.amountHkd == null);
  bool get isTollFree => charges.isEmpty || (!hasPayableTolls && !hasUnknown);
}

class TollCharge {
  final String facilityId;
  final String facilityName;
  final double? amountHkd;
  final bool isTimeVarying;

  const TollCharge({
    required this.facilityId,
    required this.facilityName,
    required this.amountHkd,
    required this.isTimeVarying,
  });
}

class _TollFacility {
  final String id;
  final String nameEn;
  final String nameTc;
  final String nameSc;
  final String? hkMobilityTunnelCode;
  final Map<HkVehicleType, double>? fixedRates;
  final List<LatLng> detectionPoints;
  final double radiusMeters;
  final int minPointHits;

  /// If set, toll is applied only when destination is within this radius of the
  /// first detection point (used for one-way DB-bound charging).
  final double? destinationProximityRuleMeters;

  const _TollFacility._({
    required this.id,
    required this.nameEn,
    required this.nameTc,
    required this.nameSc,
    required this.hkMobilityTunnelCode,
    required this.fixedRates,
    required this.detectionPoints,
    required this.radiusMeters,
    required this.minPointHits,
    required this.destinationProximityRuleMeters,
  });

  const _TollFacility.fixedTunnel({
    required String id,
    required String nameEn,
    required String nameTc,
    required String nameSc,
    required Map<HkVehicleType, double> fixedRates,
    required List<LatLng> detectionPoints,
    required double radiusMeters,
    int minPointHits = 1,
    double? destinationProximityRuleMeters,
  }) : this._(
         id: id,
         nameEn: nameEn,
         nameTc: nameTc,
         nameSc: nameSc,
         hkMobilityTunnelCode: null,
         fixedRates: fixedRates,
         detectionPoints: detectionPoints,
         radiusMeters: radiusMeters,
         minPointHits: minPointHits,
         destinationProximityRuleMeters: destinationProximityRuleMeters,
       );

  const _TollFacility.timeVaryingTunnel({
    required String id,
    required String nameEn,
    required String nameTc,
    required String nameSc,
    required String hkMobilityTunnelCode,
    required List<LatLng> detectionPoints,
    required double radiusMeters,
    int minPointHits = 1,
  }) : this._(
         id: id,
         nameEn: nameEn,
         nameTc: nameTc,
         nameSc: nameSc,
         hkMobilityTunnelCode: hkMobilityTunnelCode,
         fixedRates: null,
         detectionPoints: detectionPoints,
         radiusMeters: radiusMeters,
         minPointHits: minPointHits,
         destinationProximityRuleMeters: null,
       );

  bool appliesForTrip({required LatLng origin, required LatLng destination}) {
    if (destinationProximityRuleMeters == null) return true;
    if (detectionPoints.isEmpty) return false;
    final d = const Distance()(destination, detectionPoints.first);
    return d <= destinationProximityRuleMeters!;
  }

  String nameForLanguageCode(String languageCode) {
    switch (languageCode.toLowerCase()) {
      case 'tc':
        return nameTc.isNotEmpty ? nameTc : nameEn;
      case 'sc':
        return nameSc.isNotEmpty
            ? nameSc
            : (nameTc.isNotEmpty ? nameTc : nameEn);
      case 'en':
      default:
        return nameEn.isNotEmpty
            ? nameEn
            : (nameTc.isNotEmpty ? nameTc : nameSc);
    }
  }
}
