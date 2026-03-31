/// Route API + BottomSheet UI (OSRM + flutter_map)
///
/// Drop this file into `lib/` and wire it into your Home screen.
/// It fetches a route from the user's current location to a selected carpark
/// from **your own OSRM server** (e.g., http://192.168.0.100:8964) and
/// returns `List<LatLng>` you can draw with `PolylineLayer`.
///
/// The provided bottom sheet is **non‑modal** (via `showBottomSheet`) so the
/// map stays clickable while the prompt is open, per your requirement.
///
/// deps (pubspec.yaml):
///   http: ^1.2.2
///   geolocator: ^10.1.0
///   latlong2: ^0.9.0
///   flutter_map: ^7.0.2   // you already use this

part of 'route_api.dart';

/// Lightweight model for a carpark you select on the map/list.
class Carpark {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final int? freeSpaces;

  const Carpark({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.freeSpaces,
  });

  LatLng get ll => LatLng(lat, lng);
}

/// Result of an OSRM route call
class RouteResult {
  final List<LatLng> points; // decoded for drawing
  final double distanceMeters;
  final double durationSeconds;
  final double motorwayDistanceMeters;
  final double majorRoadDistanceMeters;
  final List<String> stepNames;
  final bool hasFerry;

  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    this.motorwayDistanceMeters = 0,
    this.majorRoadDistanceMeters = 0,
    this.stepNames = const [],
    this.hasFerry = false,
  });

  static const empty =
      RouteResult(
        points: [],
        distanceMeters: 0,
        durationSeconds: 0,
        motorwayDistanceMeters: 0,
        majorRoadDistanceMeters: 0,
        stepNames: [],
        hasFerry: false,
      );
}

class OsrmRouteApi {
  final String baseUrl;
  final String profile; 

  const OsrmRouteApi({required this.baseUrl, this.profile = 'driving'});

  /// Snap a coordinate to the nearest road using OSRM /nearest.
  Future<LatLng?> nearest(LatLng point) async {
    final url = Uri.parse(
      '$baseUrl/nearest/v1/$profile/${point.longitude},${point.latitude}'
      '?number=1',
    );
    final res = await _getWithRetry(url);
    if (res.statusCode != 200) {
      throw Exception('OSRM ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['code'] != 'Ok') {
      throw Exception('OSRM error: ${data['code']} ${data['message'] ?? ''}');
    }
    final waypoints = data['waypoints'];
    if (waypoints is! List || waypoints.isEmpty) return null;
    final loc = waypoints.first['location'];
    if (loc is! List || loc.length < 2) return null;
    final lon = (loc[0] as num).toDouble();
    final lat = (loc[1] as num).toDouble();
    return LatLng(lat, lon);
  }

  Future<RouteResult> routeGeoJson({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final url = Uri.parse(
      '$baseUrl/route/v1/$profile/${origin.longitude},${origin.latitude};'
      '${destination.longitude},${destination.latitude}'
      '?geometries=geojson&overview=full&steps=false',
    );

    final res = await http.get(url);
    if (res.statusCode != 200) {
      throw Exception('OSRM ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['code'] != 'Ok') {
      throw Exception('OSRM error: ${data['code']} ${data['message'] ?? ''}');
    }

    final route = (data['routes'] as List).first as Map<String, dynamic>;
    final distance = (route['distance'] as num).toDouble();
    final duration = (route['duration'] as num).toDouble();

    final coords = (route['geometry']['coordinates'] as List)
        .cast<List>()
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList(growable: false);

    return RouteResult(points: coords, distanceMeters: distance, durationSeconds: duration);
  }

  /// Calls /route and returns up to [alternatives] + 1 routes (GeoJSON geometry).
  Future<List<RouteResult>> routeGeoJsonAlternatives({
    required LatLng origin,
    required LatLng destination,
    int alternatives = 0,
    bool steps = false,
    String? exclude,
  }) async {
    var requestedAlternatives = alternatives;
    if (requestedAlternatives < 0) requestedAlternatives = 0;
    final includeRoadMetrics = steps;

    Future<http.Response> doRequest({
      required int alts,
      required bool steps,
      required String overview,
    }) {
      final altQuery = alts > 0 ? '&alternatives=$alts' : '';
      final stepsQuery = steps ? '&steps=true' : '&steps=false';
      final overviewQuery = '&overview=$overview';
      final excludeQuery = (exclude != null && exclude.trim().isNotEmpty)
          ? '&exclude=${Uri.encodeQueryComponent(exclude)}'
          : '';
      final url = Uri.parse(
        '$baseUrl/route/v1/$profile/${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?geometries=geojson$overviewQuery$stepsQuery$altQuery$excludeQuery',
      );
      return _getWithRetry(url);
    }

    // Geometry request: keep response small by never requesting steps here.
    http.Response res = await doRequest(
      alts: requestedAlternatives,
      steps: false,
      overview: 'full',
    );

    if (res.statusCode != 200) {
      // Some OSRM deployments cap the maximum alternatives (e.g. "current maxium(3)").
      if (res.statusCode == 400 && requestedAlternatives > 0) {
        final maxAlt = _tryParseOsrmMaxAlternatives(res.body);
        if (maxAlt != null && maxAlt >= 0 && maxAlt < requestedAlternatives) {
          requestedAlternatives = maxAlt;
          res = await doRequest(
            alts: requestedAlternatives,
            steps: false,
            overview: 'full',
          );
        }
      }
      if (res.statusCode != 200) {
        throw Exception('OSRM ${res.statusCode}: ${res.body}');
      }
    }

    final geomData = jsonDecode(res.body) as Map<String, dynamic>;
    if (geomData['code'] != 'Ok') {
      throw Exception('OSRM error: ${geomData['code']} ${geomData['message'] ?? ''}');
    }

    final routes = (geomData['routes'] as List)
        .cast<Map<String, dynamic>>()
        .map((route) {
          final distance = (route['distance'] as num).toDouble();
          final duration = (route['duration'] as num).toDouble();
          final coords = (route['geometry']['coordinates'] as List)
              .cast<List>()
              .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
              .toList(growable: false);
          return RouteResult(
            points: coords,
            distanceMeters: distance,
            durationSeconds: duration,
            motorwayDistanceMeters: 0,
            majorRoadDistanceMeters: 0,
            hasFerry: false,
          );
        })
        .toList(growable: false);

    if (!includeRoadMetrics || routes.isEmpty) return routes;

    // Metrics request: request steps but omit geometry (overview=false) to reduce payload
    // and lower the chance of OSRM closing the connection on large responses.
    try {
      http.Response metricsRes = await doRequest(
        alts: requestedAlternatives,
        steps: true,
        overview: 'false',
      );
      if (metricsRes.statusCode == 200) {
        final metricsData = jsonDecode(metricsRes.body) as Map<String, dynamic>;
        if (metricsData['code'] == 'Ok') {
          final metricRoutes = (metricsData['routes'] as List).cast<Map<String, dynamic>>();
          final n = mathMin(routes.length, metricRoutes.length);
          final enriched = <RouteResult>[];
          for (var i = 0; i < n; i++) {
            final r = routes[i];
            final m = metricRoutes[i];
            final motorwayDistance = _motorwayDistanceMeters(m['legs']);
            final majorRoadDistance = _majorRoadDistanceMeters(m['legs']);
            final stepNames = _stepNames(m['legs']);
            final hasFerry = _hasFerry(m['legs']);
            enriched.add(
              RouteResult(
                points: r.points,
                distanceMeters: r.distanceMeters,
                durationSeconds: r.durationSeconds,
                motorwayDistanceMeters: motorwayDistance,
                majorRoadDistanceMeters: majorRoadDistance,
                stepNames: stepNames,
                hasFerry: hasFerry,
              ),
            );
          }
          // If OSRM returns fewer metric routes, keep the remainder with zeros.
          if (routes.length > n) {
            enriched.addAll(routes.sublist(n));
          }
          return enriched;
        }
      }
    } catch (_) {
      // Fall back to geometry-only routes.
    }

    return routes;
  }

  /// Calls /route with one or more intermediate waypoints.
  ///
  /// OSRM supports multiple coordinates separated by ';'.
  /// This is useful when you want to force a route to pass through a specific
  /// corridor (e.g. to reduce toll usage).
  Future<RouteResult> routeGeoJsonWaypoints({
    required List<LatLng> coordinates,
    bool steps = false,
    String? exclude,
  }) async {
    if (coordinates.length < 2) {
      throw ArgumentError.value(
        coordinates.length,
        'coordinates',
        'Must provide at least origin + destination',
      );
    }

    final includeRoadMetrics = steps;

    final coordString = coordinates
        .map((p) => '${p.longitude},${p.latitude}')
        .join(';');

    Future<http.Response> doRequest({
      required bool steps,
      required String overview,
    }) {
      final stepsQuery = steps ? '&steps=true' : '&steps=false';
      final overviewQuery = '&overview=$overview';
      final excludeQuery = (exclude != null && exclude.trim().isNotEmpty)
          ? '&exclude=${Uri.encodeQueryComponent(exclude)}'
          : '';
      final url = Uri.parse(
        '$baseUrl/route/v1/$profile/$coordString'
        '?geometries=geojson$overviewQuery$stepsQuery$excludeQuery',
      );
      return _getWithRetry(url);
    }

    final geomRes = await doRequest(steps: false, overview: 'full');
    if (geomRes.statusCode != 200) {
      throw Exception('OSRM ${geomRes.statusCode}: ${geomRes.body}');
    }

    final geomData = jsonDecode(geomRes.body) as Map<String, dynamic>;
    if (geomData['code'] != 'Ok') {
      throw Exception(
        'OSRM error: ${geomData['code']} ${geomData['message'] ?? ''}',
      );
    }

    final route = (geomData['routes'] as List).first as Map<String, dynamic>;
    final distance = (route['distance'] as num).toDouble();
    final duration = (route['duration'] as num).toDouble();
    final coords = (route['geometry']['coordinates'] as List)
        .cast<List>()
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList(growable: false);

    if (!includeRoadMetrics || coords.isEmpty) {
      return RouteResult(
        points: coords,
        distanceMeters: distance,
        durationSeconds: duration,
        motorwayDistanceMeters: 0,
        majorRoadDistanceMeters: 0,
        stepNames: const [],
        hasFerry: false,
      );
    }

    try {
      final metricsRes = await doRequest(steps: true, overview: 'false');
      if (metricsRes.statusCode == 200) {
        final metricsData = jsonDecode(metricsRes.body) as Map<String, dynamic>;
        if (metricsData['code'] == 'Ok') {
          final metricRoute =
              (metricsData['routes'] as List).first as Map<String, dynamic>;
          final motorwayDistance = _motorwayDistanceMeters(metricRoute['legs']);
          final majorRoadDistance = _majorRoadDistanceMeters(metricRoute['legs']);
          final stepNames = _stepNames(metricRoute['legs']);
          final hasFerry = _hasFerry(metricRoute['legs']);
          return RouteResult(
            points: coords,
            distanceMeters: distance,
            durationSeconds: duration,
            motorwayDistanceMeters: motorwayDistance,
            majorRoadDistanceMeters: majorRoadDistance,
            stepNames: stepNames,
            hasFerry: hasFerry,
          );
        }
      }
    } catch (_) {
      // Fall back to geometry-only route.
    }

    return RouteResult(
      points: coords,
      distanceMeters: distance,
      durationSeconds: duration,
      motorwayDistanceMeters: 0,
      majorRoadDistanceMeters: 0,
      stepNames: const [],
      hasFerry: false,
    );
  }

  static int mathMin(int a, int b) => a < b ? a : b;

  static Future<http.Response> _getWithRetry(
    Uri url, {
    int maxAttempts = 2,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        return await http.get(url).timeout(timeout);
      } on TimeoutException catch (e) {
        lastError = e;
      } on http.ClientException catch (e) {
        lastError = e;
      } on Exception catch (e) {
        lastError = e;
      }
      await Future<void>.delayed(Duration(milliseconds: 250 * (attempt + 1)));
    }
    throw lastError ?? Exception('OSRM request failed');
  }

  static int? _tryParseOsrmMaxAlternatives(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final msg = decoded['message']?.toString() ?? '';
        final m = RegExp(r'max(?:im|imu|imum|ium)\((\d+)\)', caseSensitive: false).firstMatch(msg);
        if (m != null) return int.tryParse(m.group(1)!);
        final m2 = RegExp(r'max(?:im|imu|imum|ium)\s*[:=]?\s*(\d+)', caseSensitive: false).firstMatch(msg);
        if (m2 != null) return int.tryParse(m2.group(1)!);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static double _motorwayDistanceMeters(Object? legs) {
    if (legs is! List) return 0;
    var total = 0.0;
    for (final leg in legs) {
      if (leg is! Map) continue;
      final steps = leg['steps'];
      if (steps is! List) continue;
      for (final step in steps) {
        if (step is! Map) continue;
        final distance = step['distance'];
        if (distance is! num) continue;
        if (_stepIsMotorway(step)) {
          total += distance.toDouble();
        }
      }
    }
    return total;
  }

  static double _majorRoadDistanceMeters(Object? legs) {
    if (legs is! List) return 0;
    var total = 0.0;
    for (final leg in legs) {
      if (leg is! Map) continue;
      final steps = leg['steps'];
      if (steps is! List) continue;
      for (final step in steps) {
        if (step is! Map) continue;
        final distance = step['distance'];
        if (distance is! num) continue;
        final name = step['name']?.toString() ?? '';
        if (_stepIsMotorway(step) || _stepNameLooksMajor(name)) {
          total += distance.toDouble();
        }
      }
    }
    return total;
  }

  static List<String> _stepNames(Object? legs) {
    if (legs is! List) return const [];
    final seen = <String>{};
    final names = <String>[];
    for (final leg in legs) {
      if (leg is! Map) continue;
      final steps = leg['steps'];
      if (steps is! List) continue;
      for (final step in steps) {
        if (step is! Map) continue;
        final name = (step['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        if (seen.add(name)) names.add(name);
      }
    }
    return names;
  }

  static bool _hasFerry(Object? legs) {
    if (legs is! List) return false;
    for (final leg in legs) {
      if (leg is! Map) continue;
      final steps = leg['steps'];
      if (steps is! List) continue;
      for (final step in steps) {
        if (step is! Map) continue;
        final mode = step['mode']?.toString().toLowerCase();
        if (mode == 'ferry') return true;
      }
    }
    return false;
  }

  static bool _stepIsMotorway(Map<dynamic, dynamic> step) {
    final intersections = step['intersections'];
    if (intersections is! List) return false;
    for (final ix in intersections) {
      if (ix is! Map) continue;
      final classes = ix['classes'];
      if (classes is! List) continue;
      if (classes.contains('motorway')) return true;
    }
    return false;
  }

  static bool _stepNameLooksMajor(String name) {
    if (name.isEmpty) return false;
    final n = name.toLowerCase();
    if (n.contains('expressway') || n.contains('highway') || n.contains('bypass') || n.contains('interchange')) {
      return true;
    }
    // Basic Chinese signals for major/grade-separated roads.
    if (name.contains('公路') || name.contains('繞道') || name.contains('交匯處')) {
      return true;
    }
    return false;
  }

  /// Calls /route with encoded polyline5 geometry (if you prefer it)
  Future<RouteResult> routePolyline({
    required LatLng origin,
    required LatLng destination,
    bool polyline6 = false,
  }) async {
    final geom = polyline6 ? 'polyline6' : 'polyline';
    final div = polyline6 ? 1e6 : 1e5;
    final url = Uri.parse(
      '$baseUrl/route/v1/$profile/${origin.longitude},${origin.latitude};'
      '${destination.longitude},${destination.latitude}'
      '?geometries=$geom&overview=full&steps=false',
    );

    final res = await http.get(url);
    if (res.statusCode != 200) {
      throw Exception('OSRM ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['code'] != 'Ok') {
      throw Exception('OSRM error: ${data['code']} ${data['message'] ?? ''}');
    }

    final route = (data['routes'] as List).first as Map<String, dynamic>;
    final distance = (route['distance'] as num).toDouble();
    final duration = (route['duration'] as num).toDouble();
    final enc = route['geometry'] as String;

    final pts = _decodePolyline(enc, div);
    return RouteResult(points: pts, distanceMeters: distance, durationSeconds: duration);
  }

  // Google Encoded Polyline decoder (5/6 precision)
  List<LatLng> _decodePolyline(String e, double div) {
    int index = 0, lat = 0, lng = 0;
    final pts = <LatLng>[];
    while (index < e.length) {
      int b, shift = 0, result = 0;
      do { b = e.codeUnitAt(index++) - 63; result |= (b & 31) << shift; shift += 5; } while (b >= 32);
      final dlati = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlati;
      shift = 0; result = 0;
      do { b = e.codeUnitAt(index++) - 63; result |= (b & 31) << shift; shift += 5; } while (b >= 32);
      final dlngi = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlngi;
      pts.add(LatLng(lat / div, lng / div));
    }
    return pts;
  }
}

