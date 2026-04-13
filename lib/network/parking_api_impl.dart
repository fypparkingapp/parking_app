part of 'parking_api.dart';

/// Model class for a carpark
class Carpark {
  final String _id;
  final String _nameEn;
  final String _nameTc;
  final String _nameSc;
  final String _addressEn;
  final String _addressTc;
  final String _addressSc;
  final double _latitude;
  final double _longitude;
  final String _operator;
  final Map<String, Map<String, dynamic>> _vacancies;
  final String? _photoUrl;
  final String? _openingStatus;
  final List<CarparkRate> _privateCarRates;

  Carpark({
    required String id,
    required String nameEn,
    required String nameTc,
    required String nameSc,
    required String addressEn,
    required String addressTc,
    required String addressSc,
    required double latitude,
    required double longitude,
    required String operatorName,
    String? photoUrl,
    String? openingStatus,
    List<CarparkRate>? privateCarRates,
    Map<String, Map<String, dynamic>>? vacancies,
  }) : _id = id,
       _nameEn = nameEn,
       _nameTc = nameTc,
       _nameSc = nameSc,
       _addressEn = addressEn,
       _addressTc = addressTc,
       _addressSc = addressSc,
       _latitude = latitude,
       _longitude = longitude,
       _operator = operatorName,
       _photoUrl = photoUrl,
       _openingStatus = openingStatus,
       _privateCarRates = privateCarRates ?? const [],
       _vacancies = vacancies ?? {};

  // Getters
  String get id => _id;
  String get nameEn => _nameEn;
  String get nameTc => _nameTc;
  String get nameSc => _nameSc;
  String get addressEn => _addressEn;
  String get addressTc => _addressTc;
  String get addressSc => _addressSc;
  double get latitude => _latitude;
  double get longitude => _longitude;
  String get operatorName => _operator;
  Map<String, Map<String, dynamic>> get vacancies => _vacancies;
  String? get photoUrl => _photoUrl;
  String? get openingStatus => _openingStatus;
  List<CarparkRate> get privateCarRates => _privateCarRates;

  // Computed getter: Combine English and Chinese addresses
  String get fullAddress {
    final chinese = _addressTc.isNotEmpty ? _addressTc : _addressSc;
    if (_addressEn.isNotEmpty && chinese.isNotEmpty) {
      return '$_addressEn / $chinese';
    }
    if (_addressEn.isNotEmpty) return _addressEn;
    if (chinese.isNotEmpty) return chinese;
    return '';
  }

  // Backward compatibility: Return privateCar vacancy for existing code
  int? get vacancy => (vacancies['privateCar']?['vacancy'] is num)
      ? vacancies['privateCar']!['vacancy'].toInt()
      : null;

  factory Carpark.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    List<dynamic>? asList(dynamic value) {
      if (value is List) return value;
      if (value == null) return null;
      return [value];
    }

    final operatorName = json['operator']?.toString() ?? '';
    final normalizedOperator = operatorName.toLowerCase();
    final isLinkReit =
        normalizedOperator == 'linkreit' ||
        normalizedOperator.contains('linkreit');

    Map<String, dynamic>? govPrices = json['govPrices'] is Map<String, dynamic>
        ? json['govPrices'] as Map<String, dynamic>
        : null;
    final linkPrices = isLinkReit && json['linkPrices'] is Map<String, dynamic>
        ? json['linkPrices'] as Map<String, dynamic>
        : null;

    if (govPrices == null && json['privateCar'] is Map<String, dynamic>) {
      final privateCar = json['privateCar'] as Map<String, dynamic>;
      govPrices = {
        'privateCar': {
          'hourly': asList(privateCar['hourlyCharges'] ?? privateCar['hourly']),
          'dayNight': asList(
            privateCar['dayNightParks'] ?? privateCar['dayNight'],
          ),
          'monthly': asList(
            privateCar['monthlyCharges'] ?? privateCar['monthly'],
          ),
          'dayPass': asList(privateCar['dayPass']),
          'dayNightParks': asList(
            privateCar['dayNightParks'] ?? privateCar['dayNight'],
          ),
        },
      };
    }

    final namesByLang = _stringStringMap(json['namesByLang']);
    final addressesByLang = _stringStringMap(json['displayAddressesByLang']);

    List<CarparkRate> privateCarRates = [];
    if (isLinkReit) {
      privateCarRates = _parseLinkRates(linkPrices);
    }
    if (privateCarRates.isEmpty) {
      privateCarRates = _parseGovPrivateCarRates(govPrices);
    }
    if (privateCarRates.isEmpty) {
      privateCarRates = _parseWilsonRates(json['wilsonPlans']);
    }
    if (privateCarRates.isEmpty) {
      privateCarRates = _deriveRatesFromRemarks(json);
    }

    final vacancies = <String, Map<String, dynamic>>{};
    if (isLinkReit && json['linkVacancy'] is num) {
      vacancies['privateCar'] = {
        'vacancy': (json['linkVacancy'] as num).toInt(),
        'vacancy_type': 'LinkREIT',
        'vacancyEV': null,
        'vacancyDIS': null,
        'lastupdate': json['linkModifiedDate']?.toString() ?? '',
      };
    }

    Map<String, dynamic>? vacancyFromTransport(Map<String, dynamic>? source) {
      if (source == null) return null;
      int? toInt(dynamic value) {
        if (value is num) return value.toInt();
        return int.tryParse(value?.toString() ?? '');
      }

      final vacancy = toInt(source['space']);
      final ev = toInt(source['spaceEV']);
      final disabled = toInt(source['spaceDIS']);
      final unloading = toInt(source['spaceUNL']);
      if ([vacancy, ev, disabled, unloading].every((v) => v == null)) {
        return null;
      }
      final lastUpdate =
          source['lastupdate']?.toString() ??
          json['modifiedDate']?.toString() ??
          json['publishedDate']?.toString() ??
          '';
      final vacancyType = source['vacancy_type']?.toString() ?? 'gov';
      return {
        if (vacancy != null) 'vacancy': vacancy,
        if (ev != null) 'vacancyEV': ev,
        if (disabled != null) 'vacancyDIS': disabled,
        if (unloading != null) 'vacancyUNL': unloading,
        'vacancy_type': vacancyType,
        'lastupdate': lastUpdate,
      };
    }

    final govVacancy = isLinkReit
        ? null
        : vacancyFromTransport(json['privateCar'] as Map<String, dynamic>?);
    if (govVacancy != null) {
      vacancies['privateCar'] = govVacancy;
    }

    final name = json['name']?.toString() ?? '';
    final displayAddress = json['displayAddress']?.toString() ?? '';
    final nameEn = _firstNonEmptyString([
      _firstFromLangMap(namesByLang, ['en_US', 'en']),
      json['linkNameEn'],
      json['govNameEn'],
      json['name_en'],
      json['nameEn'],
      json['park_Name_en'],
      name,
    ]);
    final nameTc = _firstNonEmptyString([
      _firstFromLangMap(namesByLang, ['zh_TW', 'zh_HK', 'tc', 'zh']),
      json['linkNameTc'],
      json['govNameTc'],
      json['name_tc'],
      json['nameTc'],
      json['park_Name_tc'],
      name,
    ]);
    final nameSc = _firstNonEmptyString([
      _firstFromLangMap(namesByLang, ['zh_CN', 'cn', 'zh']),
      json['linkNameSc'],
      json['govNameSc'],
      json['name_sc'],
      json['nameSc'],
      nameTc,
      json['park_Name_sc'],
      name,
    ]);

    final address = json['address']?.toString() ?? '';
    final addressEn = _firstNonEmptyString([
      _firstFromLangMap(addressesByLang, ['en_US', 'en']),
      json['linkAddressEn'],
      json['govAddressEn'],
      json['displayAddressEn'],
      displayAddress,
      json['address_en'],
      json['addressEn'],
      address,
    ]);
    final addressTc = _firstNonEmptyString([
      _firstFromLangMap(addressesByLang, ['zh_TW', 'zh_HK', 'tc', 'zh']),
      json['linkAddressTc'],
      json['govAddressTc'],
      json['displayAddressTc'],
      json['displayAddressZh'],
      json['displayAddress_tc'],
      json['address_tc'],
      json['address_sc'],
      json['addressTc'],
      displayAddress,
      address,
    ]);
    final addressSc = _firstNonEmptyString([
      _firstFromLangMap(addressesByLang, ['zh_CN', 'cn', 'zh']),
      json['linkAddressSc'],
      json['govAddressSc'],
      json['displayAddressSc'],
      json['displayAddress_sc'],
      json['address_sc'],
      addressTc,
      displayAddress,
      address,
    ]);

    final latitude =
        parseDouble(json['lat']) ?? parseDouble(json['latitude']) ?? 0.0;
    final longitude =
        parseDouble(json['lng']) ?? parseDouble(json['longitude']) ?? 0.0;

    String? photoUrl;
    if (json['image_url'] != null) {
      photoUrl = json['image_url']?.toString();
    } else if (json['photo'] != null) {
      photoUrl = json['photo']?.toString();
    } else if (json['photoUrl'] != null) {
      photoUrl = json['photoUrl']?.toString();
    } else if (json['renditionUrls'] is Map) {
      final renditions = json['renditionUrls'] as Map;
      photoUrl = _firstNonEmptyString([
        renditions['carpark_photo'],
        renditions['banner'],
        renditions['square'],
        renditions['thumbnail'],
      ]);
    }

    return Carpark(
      id: _firstNonEmptyString([
        json['sourceId'],
        json['park_Id'],
        json['park_id'],
        json['id'],
      ]),
      nameEn: nameEn,
      nameTc: nameTc,
      nameSc: nameSc,
      addressEn: addressEn,
      addressTc: addressTc,
      addressSc: addressSc,
      latitude: latitude,
      longitude: longitude,
      operatorName: operatorName,
      photoUrl: _normalizePhotoUrl(photoUrl),
      openingStatus: json['opening_status']?.toString(),
      privateCarRates: privateCarRates,
      vacancies: vacancies,
    );
  }

  static Map<String, String> _stringStringMap(dynamic raw) {
    if (raw is Map) {
      return raw.map(
        (key, value) =>
            MapEntry(key.toString(), value == null ? '' : value.toString()),
      );
    }
    return const {};
  }

  static String _firstFromLangMap(Map<String, String> map, List<String> keys) {
    for (final key in keys) {
      final variants = <String>{
        key,
        key.toLowerCase(),
        key.toUpperCase(),
        key.replaceAll('-', '_'),
        key.replaceAll('_', '-'),
      };
      for (final variant in variants) {
        final value = map[variant];
        if (value != null && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
    }
    return '';
  }

  static String _firstNonEmptyString(
    List<dynamic> values, {
    String fallback = '',
  }) {
    for (final value in values) {
      if (value == null) continue;
      final str = value.toString().trim();
      if (str.isNotEmpty) return str;
    }
    return fallback;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': _id,
      'nameEn': _nameEn,
      'nameTc': _nameTc,
      'nameSc': _nameSc,
      'addressEn': _addressEn,
      'addressTc': _addressTc,
      'addressSc': _addressSc,
      'latitude': _latitude,
      'longitude': _longitude,
      'operator': _operator,
      'photoUrl': _photoUrl,
      'openingStatus': _openingStatus,
      'vacancies': _vacancies.map(
        (key, value) => MapEntry(key, Map<String, dynamic>.from(value)),
      ),
      'privateCarRates': _privateCarRates.map((rate) => rate.toJson()).toList(),
    };
  }

  factory Carpark.fromCacheJson(Map<String, dynamic> json) {
    final vacancies = (json['vacancies'] as Map<String, dynamic>? ?? {}).map(
      (key, value) => MapEntry(key, Map<String, dynamic>.from(value as Map)),
    );
    final rates =
        (json['privateCarRates'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(CarparkRate.fromJson)
            .toList() ??
        const <CarparkRate>[];
    return Carpark(
      id: json['id']?.toString() ?? '',
      nameEn: json['nameEn']?.toString() ?? '',
      nameTc: json['nameTc']?.toString() ?? '',
      nameSc: json['nameSc']?.toString() ?? '',
      addressEn: json['addressEn']?.toString() ?? '',
      addressTc: json['addressTc']?.toString() ?? '',
      addressSc: json['addressSc']?.toString() ?? '',
      latitude: (json['latitude'] is num)
          ? (json['latitude'] as num).toDouble()
          : 0,
      longitude: (json['longitude'] is num)
          ? (json['longitude'] as num).toDouble()
          : 0,
      operatorName: json['operator']?.toString() ?? '',
      photoUrl: json['photoUrl']?.toString(),
      openingStatus: json['openingStatus']?.toString(),
      privateCarRates: rates,
      vacancies: vacancies,
    );
  }
}

List<CarparkRate> _parseGovPrivateCarRates(Map<String, dynamic>? govPrices) {
  if (govPrices == null) return const <CarparkRate>[];
  final privateCar = govPrices['privateCar'];
  if (privateCar is! Map<String, dynamic>) return const <CarparkRate>[];

  CarparkRate? pickBest(dynamic listValue, {String? fallbackType}) {
    if (listValue is! List || listValue.isEmpty) return null;
    Map<String, dynamic>? preferred;
    for (final item in listValue.whereType<Map<String, dynamic>>()) {
      if (item['price'] is num && (item['price'] as num) > 0) {
        preferred = item;
        break;
      }
      preferred ??= item;
    }
    if (preferred == null) return null;
    final map = Map<String, dynamic>.from(preferred);
    if (fallbackType != null) {
      final type = map['type']?.toString().trim();
      if (type == null || type.isEmpty) {
        map['type'] = fallbackType;
      }
    }
    // Remove noisy remarks from govPrices-derived rates.
    map.remove('remark');
    return CarparkRate.fromJson(map);
  }

  final rates = <CarparkRate>[];
  final hourly = pickBest(privateCar['hourly'], fallbackType: 'hourly');
  if (hourly != null) rates.add(hourly);
  final dayNight = pickBest(
    privateCar['dayNight'] ?? privateCar['dayNightParks'],
  );
  if (dayNight != null) rates.add(dayNight);
  final monthly = pickBest(privateCar['monthly'], fallbackType: 'monthly-park');
  if (monthly != null) rates.add(monthly);

  return rates;
}

List<CarparkRate> _parseLinkRates(Map<String, dynamic>? linkPrices) {
  if (linkPrices == null) return const <CarparkRate>[];

  const weekday = ['MON', 'TUE', 'WED', 'THU', 'FRI'];
  const weekend = ['SAT', 'SUN', 'PH'];

  final rates = <CarparkRate>[];
  void addRate(
    dynamic value,
    String type,
    List<String> days, {
    bool excludePublicHoliday = false,
    String? remark,
  }) {
    if (value is! num) return;
    rates.add(
      CarparkRate(
        weekdays: days,
        excludePublicHoliday: excludePublicHoliday,
        periodStart: null,
        periodEnd: null,
        price: value.toDouble(),
        covered: null,
        type: type,
        remark: remark,
        usageMinimum: null,
        reserved: null,
        validUntil: null,
      ),
    );
  }

  addRate(
    linkPrices['hourly_weekday'],
    'hourly',
    weekday,
    excludePublicHoliday: true,
  );
  addRate(linkPrices['hourly_weekend'], 'hourly', weekend);
  addRate(
    linkPrices['twelve_hour_weekday'],
    '12-hour',
    weekday,
    excludePublicHoliday: true,
  );
  addRate(linkPrices['twelve_hour_weekend'], '12-hour', weekend);
  addRate(
    linkPrices['twenty_four_hour_weekday'],
    '24-hour',
    weekday,
    excludePublicHoliday: true,
  );
  addRate(linkPrices['twenty_four_hour_weekend'], '24-hour', weekend);

  return _dedupeRates(rates);
}

List<CarparkRate> _parseWilsonRates(dynamic rawPlans) {
  if (rawPlans is! List) return const <CarparkRate>[];

  String? normalizeType(String serviceType, String unit) {
    final type = serviceType.toLowerCase();
    if (type.contains('hourly') || unit == 'per_hour') return 'hourly';
    if (type.contains('day park')) {
      return unit == 'day_pass' ? 'day-pass' : 'day-park';
    }
    if (type.contains('night park')) {
      return type.contains('monthly') ? 'night-park (monthly)' : 'night-park';
    }
    if (type.contains('monthly')) return 'monthly-park';
    if (type.contains('12 hours')) return '12-hour';
    if (type.contains('24 hours')) return '24-hour';
    return null;
  }

  bool excludePublicHoliday(String rule) {
    return RegExp(
      r'EXCL\.?\s*PH|EXCLUDING\s+PUBLIC\s+HOLIDAYS',
      caseSensitive: false,
    ).hasMatch(rule);
  }

  List<String> parseWeekdays(String rule) {
    final normalized = rule.toUpperCase();
    final days = <String>{};
    if (normalized.contains('MON-SAT')) {
      days.addAll(['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT']);
    }
    if (normalized.contains('MON-FRI')) {
      days.addAll(['MON', 'TUE', 'WED', 'THU', 'FRI']);
    }
    if (normalized.contains('SUN')) days.add('SUN');
    if (normalized.contains('SAT')) days.add('SAT');
    if (normalized.contains('PH')) days.add('PH');

    const order = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN', 'PH'];
    return order.where(days.contains).toList();
  }

  String? parsePeriodStart(String? timeOfDay) {
    if (timeOfDay == null) return null;
    final parts = timeOfDay.split('-');
    if (parts.length < 2) return null;
    return parts.first.trim();
  }

  String? parsePeriodEnd(String? timeOfDay) {
    if (timeOfDay == null) return null;
    final parts = timeOfDay.split('-');
    if (parts.length < 2) return null;
    return parts.last.trim();
  }

  final rates = <CarparkRate>[];
  for (final plan in rawPlans.whereType<Map>()) {
    final carTypeId = plan['carTypeId'];
    final carTypeEn = plan['carTypeEn']?.toString().toLowerCase() ?? '';
    final carTypeZh = plan['carTypeZh']?.toString() ?? '';
    final supportsPrivateCar =
        (carTypeId is num && <int>{1, 3}.contains(carTypeId.toInt())) ||
        carTypeEn.contains('private car') ||
        carTypeZh.contains('私家車');
    if (!supportsPrivateCar) continue;
    if (plan['isEnable'] == false) continue;
    final amount = plan['amount'];
    if (amount is! num || amount <= 0) continue;

    final serviceType = plan['serviceTypeEn']?.toString() ?? '';
    final unit = plan['unit']?.toString() ?? '';
    final rule = plan['ruleEn']?.toString() ?? '';
    final timeOfDay = plan['timeOfDay']?.toString();
    final normalizedType = normalizeType(serviceType, unit);
    if (normalizedType == null) continue;

    rates.add(
      CarparkRate(
        weekdays: parseWeekdays(rule),
        excludePublicHoliday: excludePublicHoliday(rule),
        periodStart: parsePeriodStart(timeOfDay),
        periodEnd: parsePeriodEnd(timeOfDay),
        price: amount.toDouble(),
        covered: null,
        type: normalizedType,
        remark: null,
        usageMinimum: null,
        reserved: null,
        validUntil: null,
      ),
    );
  }

  return _dedupeRates(rates);
}

String? _normalizePhotoUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('/')) {
    return 'https://parkapi2.ryanpumpkin.com$url';
  }
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  if (uri.scheme == 'https' || uri.scheme == 'data') {
    return url;
  }
  if (uri.hasAuthority) {
    return uri.replace(scheme: 'https').toString();
  }
  return url;
}

class CarparkRate {
  final List<String> weekdays;
  final bool excludePublicHoliday;
  final String? periodStart;
  final String? periodEnd;
  final double? price;
  final String? covered;
  final String? type;
  final String? remark;
  final num? usageMinimum;
  final String? reserved;
  final String? validUntil;

  const CarparkRate({
    required this.weekdays,
    required this.excludePublicHoliday,
    this.periodStart,
    this.periodEnd,
    this.price,
    this.covered,
    this.type,
    this.remark,
    this.usageMinimum,
    this.reserved,
    this.validUntil,
  });

  factory CarparkRate.fromJson(Map<String, dynamic> json) {
    double? parsePrice(dynamic raw) {
      if (raw is num) return raw.toDouble();
      if (raw is String) {
        final cleaned = raw.replaceAll(',', '');
        final numericMatch = RegExp(
          r'([0-9]+(?:\.[0-9]+)?)',
        ).firstMatch(cleaned);
        if (numericMatch != null) {
          return double.tryParse(numericMatch.group(1)!);
        }
        return double.tryParse(cleaned);
      }
      return null;
    }

    final rawRemark =
        json['remark']?.toString() ?? json['description']?.toString();
    final rawPeriodStart = json['periodStart'] ?? json['from'];
    final rawPeriodEnd = json['periodEnd'] ?? json['to'];

    return CarparkRate(
      weekdays: (json['weekdays'] is List)
          ? (json['weekdays'] as List)
                .whereType<String>()
                .map((w) => w.toUpperCase())
                .toList()
          : const [],
      excludePublicHoliday:
          json['excludePublicHoliday'] == true ||
          json['excludePublicHolidays'] == true,
      periodStart: rawPeriodStart?.toString(),
      periodEnd: rawPeriodEnd?.toString(),
      price: parsePrice(json['price']) ?? _extractPriceFromText(rawRemark),
      covered: json['covered']?.toString(),
      type: json['type']?.toString(),
      remark: null,
      usageMinimum: () {
        final value = json['usageMinimum'];
        if (value is num) return value;
        if (value is String) return num.tryParse(value);
        return null;
      }(),
      reserved: json['reserved']?.toString(),
      validUntil:
          json['validUntil']?.toString() ??
          json['validUntilEnd']?.toString() ??
          json['validUntilStart']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'weekdays': weekdays,
      'excludePublicHoliday': excludePublicHoliday,
      'periodStart': periodStart,
      'periodEnd': periodEnd,
      'price': price,
      'covered': covered,
      'type': type,
      'remark': remark,
      'usageMinimum': usageMinimum,
      'reserved': reserved,
      'validUntil': validUntil,
    };
  }

  static double? _extractPriceFromText(String? text) {
    if (text == null || text.isEmpty) return null;
    final match = RegExp(
      r'(?:HK\$|\$)\s*([0-9]+(?:\.[0-9]+)?)',
      caseSensitive: false,
    ).firstMatch(text.replaceAll(',', ''));
    if (match != null) {
      return double.tryParse(match.group(1)!);
    }
    return null;
  }
}

List<CarparkRate> _deriveRatesFromRemarks(Map<String, dynamic> json) {
  return const <CarparkRate>[];
}

List<CarparkRate> _dedupeRates(List<CarparkRate> rates) {
  final result = <CarparkRate>[];
  final seen = <String>{};

  for (final rate in rates) {
    final weekdays = [...rate.weekdays]..sort();
    final key = [
      rate.type ?? '',
      rate.periodStart ?? '',
      rate.periodEnd ?? '',
      weekdays.join(','),
      rate.excludePublicHoliday ? '1' : '0',
      rate.price?.toStringAsFixed(2) ?? '',
      rate.covered ?? '',
      rate.reserved ?? '',
      rate.usageMinimum?.toString() ?? '',
    ].join('|');
    if (seen.add(key)) {
      result.add(rate);
    }
  }

  return result;
}

/// Service to fetch carparks
class ParkingApi {
  static const String _carparkApiUrl =
      'https://api.data.gov.hk/v1/carpark-info-vacancy';
  static const String _govVacancyApiUrl =
      'https://resource.data.one.gov.hk/td/carpark/vacancy_all.json';
  static const String _ryanCarparkApiUrl =
      'https://parkapi2.ryanpumpkin.com/carparks';
  static const Duration _cacheDuration = Duration(minutes: 10);
  static const String _prefsKeyData = 'parking_api.carparks.data';
  static const String _prefsKeyTimestamp = 'parking_api.carparks.timestamp';

  static List<Carpark>? _memoryCache;
  static DateTime? _memoryCacheTimestamp;
  static Future<List<Carpark>>? _pendingFetch;

  static Future<void> clearCache() async {
    _memoryCache = null;
    _memoryCacheTimestamp = null;
    _pendingFetch = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeyData);
    await prefs.remove(_prefsKeyTimestamp);
  }

  static Future<List<Carpark>> fetchCarparks({
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();

    if (!forceRefresh) {
      final cached = _memoryCache;
      final cachedAt = _memoryCacheTimestamp;
      if (cached != null &&
          cachedAt != null &&
          now.difference(cachedAt) <= _cacheDuration) {
        return cached;
      }
      final inflight = _pendingFetch;
      if (inflight != null) return inflight;
    }

    final prefs = await SharedPreferences.getInstance();

    if (!forceRefresh) {
      final diskCache = _loadCache(prefs);
      if (diskCache != null &&
          now.difference(diskCache.timestamp) <= _cacheDuration) {
        _memoryCache = diskCache.data;
        _memoryCacheTimestamp = diskCache.timestamp;
        return diskCache.data;
      }
    }

    final fetch = _fetchAndPersist(prefs);
    if (!forceRefresh) {
      _pendingFetch = fetch;
    }

    try {
      final result = await fetch;
      final immutable = List<Carpark>.unmodifiable(result);
      _memoryCache = immutable;
      _memoryCacheTimestamp = DateTime.now();
      return immutable;
    } catch (e) {
      if (!forceRefresh) {
        final stale = _loadCache(prefs);
        if (stale != null) {
          _memoryCache = stale.data;
          _memoryCacheTimestamp = stale.timestamp;
          return stale.data;
        }
      }
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Error fetching carparks: $e');
    } finally {
      if (!forceRefresh) {
        _pendingFetch = null;
      }
    }
  }

  static Future<List<Carpark>> _fetchAndPersist(SharedPreferences prefs) async {
    final carparks = await _downloadCarparkData();
    try {
      await prefs.setString(
        _prefsKeyData,
        jsonEncode(carparks.map((c) => c.toJson()).toList()),
      );
      await prefs.setInt(
        _prefsKeyTimestamp,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ParkingApi: failed to persist cache -> $e');
      }
    }
    return carparks;
  }

  static _CarparkCache? _loadCache(SharedPreferences prefs) {
    final raw = prefs.getString(_prefsKeyData);
    final ts = prefs.getInt(_prefsKeyTimestamp);
    if (raw == null || ts == null) return null;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final carparks = decoded
          .whereType<Map<String, dynamic>>()
          .map(Carpark.fromCacheJson)
          .toList(growable: false);
      return _CarparkCache(
        List<Carpark>.unmodifiable(carparks),
        DateTime.fromMillisecondsSinceEpoch(ts),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ParkingApi: failed to read cache -> $e');
      }
      return null;
    }
  }

  static Future<List<Carpark>> _downloadCarparkData() async {
    final ryanMetadata = await _fetchRyanMetadata();
    final govVacancies = await _fetchGovVacancyMap();

    final response = await http.get(Uri.parse(_carparkApiUrl));
    if (response.statusCode != 200) {
      throw Exception('Failed to load carpark data: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    List<dynamic>? rows;
    if (decoded is List) {
      rows = decoded;
    } else if (decoded is Map && decoded['results'] is List) {
      rows = decoded['results'] as List;
    }

    if (rows == null) {
      throw Exception('Unexpected carpark response structure');
    }

    String? resolveId(Map<String, dynamic> row) {
      return Carpark._firstNonEmptyString([
        row['sourceId'],
        row['park_Id'],
        row['park_id'],
        row['id'],
      ]);
    }

    final govById = <String, Map<String, dynamic>>{};
    for (final row in rows.whereType<Map<String, dynamic>>()) {
      final id = resolveId(row);
      if (id != null) {
        govById[id] = row;
      }
    }

    final carparks = <Carpark>[];

    for (final entry in ryanMetadata.entries) {
      final id = entry.key;
      final ryanRow = Map<String, dynamic>.from(entry.value);
      final govRow = govById[id];

      if (govRow != null) {
        // Use gov vacancy data; Ryan provides names/prices/metadata.
        ryanRow['privateCar'] =
            govVacancies[id] ?? govRow['privateCar'] ?? ryanRow['privateCar'];
        ryanRow['opening_status'] ??= govRow['opening_status'];
        ryanRow['lat'] = ryanRow['lat'] ?? govRow['lat'] ?? govRow['latitude'];
        ryanRow['lng'] = ryanRow['lng'] ?? govRow['lng'] ?? govRow['longitude'];
        void overridePhoto(String key) {
          if (govRow.containsKey(key)) {
            ryanRow[key] = govRow[key];
          }
        }

        overridePhoto('renditionUrls');
        overridePhoto('photo');
        overridePhoto('photoUrl');
      }

      // If no gov row, still apply vacancy feed when available.
      ryanRow['privateCar'] ??= govVacancies[id];

      final carpark = Carpark.fromJson(ryanRow);
      if (carpark.latitude != 0.0 && carpark.longitude != 0.0) {
        carparks.add(carpark);
      }
    }

    // Include any gov-only carparks not present in Ryan metadata as a fallback.
    for (final entry in govById.entries) {
      if (ryanMetadata.containsKey(entry.key)) continue;
      final merged = Map<String, dynamic>.from(entry.value);
      merged['privateCar'] = govVacancies[entry.key] ?? merged['privateCar'];
      final fallback = Carpark.fromJson(merged);
      if (fallback.latitude != 0.0 && fallback.longitude != 0.0) {
        carparks.add(fallback);
      }
    }

    if (kDebugMode) {
      debugPrint('ParkingApi: returning ${carparks.length} carparks');
    }
    return carparks;
  }

  static Future<Map<String, Map<String, dynamic>>> _fetchRyanMetadata() async {
    try {
      final response = await http.get(Uri.parse(_ryanCarparkApiUrl));
      if (response.statusCode != 200) {
        return const {};
      }
      final decoded = jsonDecode(response.body);
      List<dynamic>? rows;
      if (decoded is List) {
        rows = decoded;
      } else if (decoded is Map && decoded['value'] is List) {
        rows = decoded['value'] as List;
      }
      if (rows == null) return const {};

      final map = <String, Map<String, dynamic>>{};
      for (final row in rows.whereType<Map<String, dynamic>>()) {
        final id = Carpark._firstNonEmptyString([
          row['sourceId'],
          row['park_Id'],
          row['park_id'],
          row['id'],
        ]);
        if (id.isEmpty) continue;
        map[id] = row;
      }
      return map;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ParkingApi: failed to fetch Ryan metadata -> $e');
      }
      return const {};
    }
  }

  static Future<Map<String, Map<String, dynamic>>> _fetchGovVacancyMap() async {
    try {
      final response = await http.get(Uri.parse(_govVacancyApiUrl));
      if (response.statusCode != 200) return const {};
      String body = response.body.trim();
      if (body.startsWith('?')) {
        body = body.substring(1);
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map || decoded['car_park'] is! List) return const {};

      final result = <String, Map<String, dynamic>>{};
      for (final item in (decoded['car_park'] as List).whereType<Map>()) {
        final id = item['park_id']?.toString();
        if (id == null || id.isEmpty) continue;

        Map<String, dynamic>? pickPrivateCarVacancy() {
          final vehicleTypes = item['vehicle_type'];
          if (vehicleTypes is! List) return null;
          for (final vt in vehicleTypes.whereType<Map>()) {
            final type = vt['type']?.toString().toUpperCase();
            if (type != 'P') continue;
            final categories = vt['service_category'];
            if (categories is! List) continue;
            for (final cat in categories.whereType<Map>()) {
              final vacancy = cat['vacancy'];
              if (vacancy == null) continue;
              final num? vacancyNum = (vacancy is num)
                  ? vacancy
                  : num.tryParse(vacancy.toString());
              if (vacancyNum == null) continue;
              return {
                'space': vacancyNum.toInt(),
                'vacancy_type': cat['vacancy_type']?.toString() ?? '',
                'lastupdate': cat['lastupdate']?.toString() ?? '',
              };
            }
          }
          return null;
        }

        final vacancy = pickPrivateCarVacancy();
        if (vacancy != null) {
          result[id] = vacancy;
        }
      }
      return result;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ParkingApi: failed to fetch gov vacancy -> $e');
      }
      return const {};
    }
  }
}

class _CarparkCache {
  const _CarparkCache(this.data, this.timestamp);

  final List<Carpark> data;
  final DateTime timestamp;
}
