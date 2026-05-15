import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:parking_app/config/api_config.dart';

enum LocalPoiCategory {
  districtLocality,
  residentialHousing,
  education,
  transportation,
  shoppingRetail,
  businessOffice,
  diningFood,
  medicalHealth,
  governmentPublic,
  cultureLeisure,
  religionSocialService,
  naturalLandscape,
}

enum LocalPoiSubcategory {
  campus,
  school,
  mall,
  majorDestination,
  officeTower,
  industrialArea,
  housingEstate,
  hospital,
  governmentOffice,
  hotel,
  themePark,
  artsVenue,
}

class GeocodingResult {
  const GeocodingResult({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    this.nameZh,
    this.nameEn,
    this.districtZh,
    this.districtEn,
    this.aliasesZh = const [],
    this.aliasesEn = const [],
    this.category,
    this.subcategory,
  });

  final String displayName;
  final double latitude;
  final double longitude;
  final String? nameZh;
  final String? nameEn;
  final String? districtZh;
  final String? districtEn;
  final List<String> aliasesZh;
  final List<String> aliasesEn;
  final LocalPoiCategory? category;
  final LocalPoiSubcategory? subcategory;

  bool get hasPoiMetadata => category != null;
}

class GeocodingService {
  GeocodingService({
    http.Client? client,
    Uri? baseUri,
    Uri? mapGovBaseUri,
    Uri? fallbackBaseUri,
    this.userAgent = 'wilson-parking/1.0 (contact@example.com)',
    Future<List<GeocodingResult>> Function(String query, {required int limit})?
    platformLookup,
  }) : _client = client ?? http.Client(),
       _mapGovBaseUri =
           mapGovBaseUri ??
           Uri.parse(ApiConfig.mapGovLocationSearchUrl) {
    final hasLegacyFallbackParams =
        baseUri != null || fallbackBaseUri != null || platformLookup != null;
    if (hasLegacyFallbackParams && kDebugMode) {
      debugPrint(
        'GeocodingService now uses map.gov.hk only; legacy fallback parameters are ignored.',
      );
    }
  }

  final http.Client _client;
  final Uri _mapGovBaseUri;
  final String userAgent;
  static final RegExp _hanScriptPattern = RegExp(
    r'[\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF]',
  );

  void dispose() => _client.close();

  Future<List<GeocodingResult>> geocodeMany(
    String query, {
    int limit = 5,
    String? bbox = '113.8332,22.1500,114.4425,22.5619',
    String? fallbackLabel,
  }) async {
    Future<List<GeocodingResult>> resolve(String rawQuery) async {
      final trimmed = rawQuery.trim();
      if (trimmed.isEmpty) return const [];
      final mapGovResults = await _queryMapGovLocationSearch(
        trimmed,
        limit: limit,
      );
      if (mapGovResults.isNotEmpty) {
        if (kDebugMode) {
          debugPrint(
            'Geocode map.gov.hk hit for "$trimmed": ${mapGovResults.length} results',
          );
        }
        return mapGovResults;
      }
      return const [];
    }

    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final primary = await resolve(trimmed);
    if (primary.isNotEmpty) return primary;
    final lower = trimmed.toLowerCase();
    if (lower.contains('hong kong') || trimmed.contains('香港')) {
      return const [];
    }
    final queryIsChinese = _containsHanScript(trimmed);
    final defaultSuffix = queryIsChinese ? '香港' : 'Hong Kong';
    final providedSuffix = fallbackLabel?.trim();
    final suffix = (providedSuffix == null || providedSuffix.isEmpty)
        ? defaultSuffix
        : (queryIsChinese && !_containsHanScript(providedSuffix))
        ? '香港'
        : providedSuffix;
    final fallbackQueries = <String>['$trimmed, $suffix', '$suffix $trimmed'];
    if (queryIsChinese) {
      fallbackQueries.add('$suffix$trimmed');
    }

    final seenQueries = <String>{};
    for (final fallbackQuery in fallbackQueries) {
      if (!seenQueries.add(fallbackQuery)) continue;
      final matches = await resolve(fallbackQuery);
      if (matches.isNotEmpty) {
        return matches;
      }
    }

    return const [];
  }

  Future<GeocodingResult?> geocode(
    String query, {
    int limit = 1,
    String? bbox = '113.8332,22.1500,114.4425,22.5619',
    String? fallbackLabel,
  }) async {
    final results = await geocodeMany(
      query,
      limit: limit,
      bbox: bbox,
      fallbackLabel: fallbackLabel,
    );
    return results.isNotEmpty ? results.first : null;
  }

  bool _containsHanScript(String text) {
    return _hanScriptPattern.hasMatch(text);
  }

  Future<List<GeocodingResult>> _queryMapGovLocationSearch(
    String query, {
    required int limit,
  }) async {
    final uri = _mapGovBaseUri.replace(queryParameters: {'q': query});
    late final http.Response res;
    try {
      res = await _client.get(
        uri,
        headers: {
          // map.gov.hk can reject generic clients; use browser-like headers.
          'User-Agent': 'Mozilla/5.0',
          'Accept': 'application/json, text/plain, */*',
          'Referer': ApiConfig.mapGovReferer,
          'Origin': ApiConfig.mapGovBase,
          'Accept-Language': 'en-US,en;q=0.9,zh-HK;q=0.8,zh;q=0.7',
        },
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Geocode map.gov.hk "$query" failed: $error');
      }
      return const [];
    }
    if (kDebugMode) {
      debugPrint('Geocode map.gov.hk "$query": ${res.statusCode}');
    }
    if (res.statusCode != 200) return const [];
    final dynamic data;
    try {
      data = jsonDecode(res.body);
    } catch (_) {
      return const [];
    }
    if (data is! List || data.isEmpty) return const [];

    final results = <GeocodingResult>[];
    final seen = <String>{};
    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      final x = _asDouble(item['x']);
      final y = _asDouble(item['y']);
      if (x == null || y == null) continue;

      final wgs = _hk1980ToWgs84(easting: x, northing: y);
      if (wgs == null) continue;

      final nameZh = _compactText(item['nameZH']?.toString());
      final nameEn = _compactText(item['nameEN']?.toString());
      final addressZh = _compactText(item['addressZH']?.toString());
      final addressEn = _compactText(item['addressEN']?.toString());
      final districtZh = _compactText(item['districtZH']?.toString());
      final districtEn = _compactText(item['districtEN']?.toString());

      final prefersZh = _containsHanScript(query);
      final displayName = _firstNonEmpty([
        prefersZh ? nameZh : nameEn,
        prefersZh ? nameEn : nameZh,
        query,
      ]);
      if (displayName.isEmpty) continue;

      final dedupeKey =
          '${displayName.toLowerCase()}|${wgs.latitude.toStringAsFixed(6)}|${wgs.longitude.toStringAsFixed(6)}';
      if (!seen.add(dedupeKey)) continue;

      results.add(
        GeocodingResult(
          displayName: displayName,
          latitude: wgs.latitude,
          longitude: wgs.longitude,
          nameZh: nameZh.isEmpty ? null : nameZh,
          nameEn: nameEn.isEmpty ? null : nameEn,
          districtZh: districtZh.isEmpty ? null : districtZh,
          districtEn: districtEn.isEmpty ? null : districtEn,
          aliasesZh: [
            if (districtZh.isNotEmpty) districtZh,
            if (addressZh.isNotEmpty) addressZh,
          ],
          aliasesEn: [
            if (districtEn.isNotEmpty) districtEn,
            if (addressEn.isNotEmpty) addressEn,
          ],
        ),
      );
      if (results.length >= limit) break;
    }
    return results;
  }

  double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  String _compactText(String? value) {
    if (value == null) return '';
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _firstNonEmpty(List<String> options) {
    for (final option in options) {
      if (option.isNotEmpty) return option;
    }
    return '';
  }

  _Wgs84Coordinate? _hk1980ToWgs84({
    required double easting,
    required double northing,
  }) {
    final hk80 = _inverseHk1980Tmerc(easting: easting, northing: northing);
    final ecefHk80 = _geodeticToEcef(
      latitudeRad: hk80.latitudeRad,
      longitudeRad: hk80.longitudeRad,
      semiMajorAxis: _hk80A,
      reciprocalFlattening: _hk80Rf,
    );
    final ecefWgs = _helmertToWgs84(
      x: ecefHk80.x,
      y: ecefHk80.y,
      z: ecefHk80.z,
    );
    final geodeticWgs = _ecefToGeodetic(
      x: ecefWgs.x,
      y: ecefWgs.y,
      z: ecefWgs.z,
      semiMajorAxis: _wgs84A,
      reciprocalFlattening: _wgs84Rf,
    );
    if (geodeticWgs.latitudeRad.isNaN || geodeticWgs.longitudeRad.isNaN) {
      return null;
    }
    return _Wgs84Coordinate(
      latitude: geodeticWgs.latitudeRad * _radToDeg,
      longitude: geodeticWgs.longitudeRad * _radToDeg,
    );
  }

  _RadCoordinate _inverseHk1980Tmerc({
    required double easting,
    required double northing,
  }) {
    final b = _hk80A * (1.0 - 1.0 / _hk80Rf);
    final e2 = (_hk80A * _hk80A - b * b) / (_hk80A * _hk80A);
    final ep2 = e2 / (1.0 - e2);

    final x = (easting - _hk80FalseEasting) / _hk80K0;
    final y = (northing - _hk80FalseNorthing) / _hk80K0;
    final meridional =
        _meridionalArc(
          latitudeRad: _hk80Lat0,
          semiMajorAxis: _hk80A,
          eccentricitySq: e2,
        ) +
        y;
    final mu =
        meridional /
        (_hk80A * (1 - e2 / 4 - 3 * e2 * e2 / 64 - 5 * math.pow(e2, 3) / 256));

    final e1 = (1 - math.sqrt(1 - e2)) / (1 + math.sqrt(1 - e2));
    final phi1 =
        mu +
        (3 * e1 / 2 - 27 * math.pow(e1, 3) / 32) * math.sin(2 * mu) +
        (21 * e1 * e1 / 16 - 55 * math.pow(e1, 4) / 32) * math.sin(4 * mu) +
        (151 * math.pow(e1, 3) / 96) * math.sin(6 * mu) +
        (1097 * math.pow(e1, 4) / 512) * math.sin(8 * mu);

    final n1 = _hk80A / math.sqrt(1 - e2 * math.pow(math.sin(phi1), 2));
    final t1 = math.pow(math.tan(phi1), 2);
    final c1 = ep2 * math.pow(math.cos(phi1), 2);
    final r1 =
        _hk80A * (1 - e2) / math.pow(1 - e2 * math.pow(math.sin(phi1), 2), 1.5);
    final d = x / n1;

    final latitude =
        phi1 -
        (n1 * math.tan(phi1) / r1) *
            (math.pow(d, 2) / 2 -
                (5 + 3 * t1 + 10 * c1 - 4 * math.pow(c1, 2) - 9 * ep2) *
                    math.pow(d, 4) /
                    24 +
                (61 +
                        90 * t1 +
                        298 * c1 +
                        45 * math.pow(t1, 2) -
                        252 * ep2 -
                        3 * math.pow(c1, 2)) *
                    math.pow(d, 6) /
                    720);
    final longitude =
        _hk80Lon0 +
        (d -
                (1 + 2 * t1 + c1) * math.pow(d, 3) / 6 +
                (5 -
                        2 * c1 +
                        28 * t1 -
                        3 * math.pow(c1, 2) +
                        8 * ep2 +
                        24 * math.pow(t1, 2)) *
                    math.pow(d, 5) /
                    120) /
            math.cos(phi1);
    return _RadCoordinate(latitudeRad: latitude, longitudeRad: longitude);
  }

  double _meridionalArc({
    required double latitudeRad,
    required double semiMajorAxis,
    required double eccentricitySq,
  }) {
    return semiMajorAxis *
        ((1 -
                    eccentricitySq / 4 -
                    3 * math.pow(eccentricitySq, 2) / 64 -
                    5 * math.pow(eccentricitySq, 3) / 256) *
                latitudeRad -
            (3 * eccentricitySq / 8 +
                    3 * math.pow(eccentricitySq, 2) / 32 +
                    45 * math.pow(eccentricitySq, 3) / 1024) *
                math.sin(2 * latitudeRad) +
            (15 * math.pow(eccentricitySq, 2) / 256 +
                    45 * math.pow(eccentricitySq, 3) / 1024) *
                math.sin(4 * latitudeRad) -
            (35 * math.pow(eccentricitySq, 3) / 3072) *
                math.sin(6 * latitudeRad));
  }

  _EcefCoordinate _geodeticToEcef({
    required double latitudeRad,
    required double longitudeRad,
    required double semiMajorAxis,
    required double reciprocalFlattening,
  }) {
    final semiMinorAxis = semiMajorAxis * (1.0 - 1.0 / reciprocalFlattening);
    final eccentricitySq =
        (semiMajorAxis * semiMajorAxis - semiMinorAxis * semiMinorAxis) /
        (semiMajorAxis * semiMajorAxis);
    final nu =
        semiMajorAxis /
        math.sqrt(1 - eccentricitySq * math.pow(math.sin(latitudeRad), 2));
    final x = nu * math.cos(latitudeRad) * math.cos(longitudeRad);
    final y = nu * math.cos(latitudeRad) * math.sin(longitudeRad);
    final z = (nu * (1 - eccentricitySq)) * math.sin(latitudeRad);
    return _EcefCoordinate(x: x, y: y, z: z);
  }

  _EcefCoordinate _helmertToWgs84({
    required double x,
    required double y,
    required double z,
  }) {
    final transformedX =
        _hk80Dx + (1 + _hk80Scale) * x - _hk80Rz * y + _hk80Ry * z;
    final transformedY =
        _hk80Dy + _hk80Rz * x + (1 + _hk80Scale) * y - _hk80Rx * z;
    final transformedZ =
        _hk80Dz - _hk80Ry * x + _hk80Rx * y + (1 + _hk80Scale) * z;
    return _EcefCoordinate(x: transformedX, y: transformedY, z: transformedZ);
  }

  _GeodeticCoordinate _ecefToGeodetic({
    required double x,
    required double y,
    required double z,
    required double semiMajorAxis,
    required double reciprocalFlattening,
  }) {
    final flattening = 1.0 / reciprocalFlattening;
    final semiMinorAxis = semiMajorAxis * (1.0 - flattening);
    final eccentricitySq =
        (semiMajorAxis * semiMajorAxis - semiMinorAxis * semiMinorAxis) /
        (semiMajorAxis * semiMajorAxis);
    final secondEccentricitySq =
        (semiMajorAxis * semiMajorAxis - semiMinorAxis * semiMinorAxis) /
        (semiMinorAxis * semiMinorAxis);

    final p = math.sqrt(x * x + y * y);
    final theta = math.atan2(semiMajorAxis * z, semiMinorAxis * p);
    final longitude = math.atan2(y, x);
    var latitude = math.atan2(
      z + secondEccentricitySq * semiMinorAxis * math.pow(math.sin(theta), 3),
      p - eccentricitySq * semiMajorAxis * math.pow(math.cos(theta), 3),
    );

    var height = 0.0;
    for (var i = 0; i < 5; i++) {
      final nu =
          semiMajorAxis /
          math.sqrt(1 - eccentricitySq * math.pow(math.sin(latitude), 2));
      height = p / math.cos(latitude) - nu;
      latitude = math.atan2(z, p * (1 - eccentricitySq * nu / (nu + height)));
    }

    final nu =
        semiMajorAxis /
        math.sqrt(1 - eccentricitySq * math.pow(math.sin(latitude), 2));
    height = p / math.cos(latitude) - nu;
    return _GeodeticCoordinate(
      latitudeRad: latitude,
      longitudeRad: longitude,
      height: height,
    );
  }
}

class _Wgs84Coordinate {
  const _Wgs84Coordinate({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class _RadCoordinate {
  const _RadCoordinate({required this.latitudeRad, required this.longitudeRad});

  final double latitudeRad;
  final double longitudeRad;
}

class _EcefCoordinate {
  const _EcefCoordinate({required this.x, required this.y, required this.z});

  final double x;
  final double y;
  final double z;
}

class _GeodeticCoordinate {
  const _GeodeticCoordinate({
    required this.latitudeRad,
    required this.longitudeRad,
    required this.height,
  });

  final double latitudeRad;
  final double longitudeRad;
  final double height;
}

const double _degToRad = math.pi / 180.0;
const double _radToDeg = 180.0 / math.pi;

const double _hk80A = 6378388.0;
const double _hk80Rf = 297.0;
const double _hk80Lat0 = 22.31213333333334 * _degToRad;
const double _hk80Lon0 = 114.1785555555556 * _degToRad;
const double _hk80K0 = 1.0;
const double _hk80FalseEasting = 836694.05;
const double _hk80FalseNorthing = 819069.8;
const double _hk80Dx = -162.619;
const double _hk80Dy = -276.959;
const double _hk80Dz = -161.764;
const double _hk80Rx = (0.067753 / 3600.0) * _degToRad;
const double _hk80Ry = (-2.24365 / 3600.0) * _degToRad;
const double _hk80Rz = (-1.15883 / 3600.0) * _degToRad;
const double _hk80Scale = -1.09425e-6;

const double _wgs84A = 6378137.0;
const double _wgs84Rf = 298.257223563;
