import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Thin TDAS client for `/tdas/api/route`.
///
/// We only use it to understand cross-harbour tunnel usage and ETA so we can
/// filter OSRM alternatives on the client.
class TdasService {
  const TdasService({this.baseUrl = 'https://tdas-api.hkemobility.gov.hk'});

  final String baseUrl;

  Future<TdasRouteInsight?> fetchRoute({
    required LatLng start,
    required LatLng end,
    TunnelCode? forceTunnel,
    String type = 'ST',
    int? departInMinutes,
    String lang = 'en',
    http.Client? client,
  }) async {
    const bufferMeters = 300;
    final body = <String, dynamic>{
      'start': {
        'lat': start.latitude,
        'long': start.longitude,
        'buffer': bufferMeters,
      },
      'end': {
        'lat': end.latitude,
        'long': end.longitude,
        'buffer': bufferMeters,
      },
      'lang': lang,
      'type': type,
      if (departInMinutes != null) 'departIn': departInMinutes,
      if (forceTunnel != null) 'tunnel': forceTunnel.code,
    };

    final uri = Uri.parse('$baseUrl/tdas/api/route');
    final httpClient = client ?? http.Client();
    try {
      debugPrint(
        'TDAS request -> $uri '
        'start=${start.latitude},${start.longitude} '
        'end=${end.latitude},${end.longitude} '
        'type=$type lang=$lang '
        'departIn=${departInMinutes ?? '-'} '
        'tunnel=${forceTunnel?.code ?? '-'}',
      );
      final res = await httpClient.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Referer': 'https://www.hkemobility.gov.hk/tc/route-search/pt',
          'Origin': 'https://www.hkemobility.gov.hk',
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36',
        },
        body: jsonEncode(body),
      );
      final bodyPreview = res.body.length > 300
          ? '${res.body.substring(0, 300)}...'
          : res.body;
      debugPrint('TDAS response <- ${res.statusCode} $bodyPreview');
      if (res.statusCode != 200) {
        return null;
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return TdasRouteInsight.fromJson(data);
    } finally {
      if (client == null) httpClient.close();
    }
  }

  /// Heuristic: detect which cross-harbour tunnel (tolled) a route uses based
  /// on proximity to tunnel portals.
  TunnelCode? detectTunnelFromGeometry(List<LatLng> pts) {
    if (pts.isEmpty) return null;
    TunnelCode? closest;
    double minMeters = double.infinity;
    final dist = const Distance();
    for (final entry in _tunnelPortals.entries) {
      for (final p in pts) {
        final d = dist(p, entry.value);
        if (d < minMeters) {
          minMeters = d;
          closest = entry.key;
        }
      }
    }
    // Only treat it as tunnel usage if the route comes reasonably close.
    if (minMeters < 800) {
      return closest;
    }
    return null;
  }

  // Portal locations are midpoints near each cross-harbour tunnel.
  static const Map<TunnelCode, LatLng> _tunnelPortals = {
    TunnelCode.cht: LatLng(22.2831538, 114.1824155),
    TunnelCode.eht: LatLng(22.2886509, 114.2120586),
    TunnelCode.wht: LatLng(22.2893329, 114.1447912),
  };
}

enum TunnelCode { cht, eht, wht }

extension TunnelCodeX on TunnelCode {
  String get code {
    switch (this) {
      case TunnelCode.cht:
        return 'cht';
      case TunnelCode.eht:
        return 'eht';
      case TunnelCode.wht:
        return 'wht';
    }
  }

  String get label {
    switch (this) {
      case TunnelCode.cht:
        return 'Cross-Harbour Tunnel';
      case TunnelCode.eht:
        return 'Eastern Harbour Crossing';
      case TunnelCode.wht:
        return 'Western Harbour Crossing';
    }
  }
}

class TdasRouteInsight {
  final String journeySpeed;
  final double distanceMeters;
  final String etaHhMm;
  final bool usesCht;
  final bool usesEht;
  final bool usesWht;
  final List<TdasTunnelAlternate> alternates;

  const TdasRouteInsight({
    required this.journeySpeed,
    required this.distanceMeters,
    required this.etaHhMm,
    required this.usesCht,
    required this.usesEht,
    required this.usesWht,
    required this.alternates,
  });

  TunnelCode? get tunnelUsed {
    if (usesCht) return TunnelCode.cht;
    if (usesEht) return TunnelCode.eht;
    if (usesWht) return TunnelCode.wht;
    return null;
  }

  factory TdasRouteInsight.fromJson(Map<String, dynamic> json) {
    return TdasRouteInsight(
      journeySpeed: (json['jSpeed'] ?? '').toString(),
      distanceMeters: (json['distM'] as num?)?.toDouble() ?? 0,
      etaHhMm: (json['eta'] ?? '').toString(),
      usesCht: json['cht'] == true,
      usesEht: json['eht'] == true,
      usesWht: json['wht'] == true,
      alternates: (json['ar'] as List?)
              ?.map((e) => TdasTunnelAlternate.fromJson(e as Map<String, dynamic>))
              .toList(growable: false) ??
          const [],
    );
  }
}

class TdasTunnelAlternate {
  final String name;
  final String distanceWithUnit;
  final String etaHhMm;

  const TdasTunnelAlternate({
    required this.name,
    required this.distanceWithUnit,
    required this.etaHhMm,
  });

  TunnelCode? get tunnel {
    switch (name.toLowerCase()) {
      case 'cht':
        return TunnelCode.cht;
      case 'eht':
        return TunnelCode.eht;
      case 'wht':
        return TunnelCode.wht;
    }
    return null;
  }

  factory TdasTunnelAlternate.fromJson(Map<String, dynamic> json) {
    return TdasTunnelAlternate(
      name: (json['name'] ?? '').toString(),
      distanceWithUnit: (json['distU'] ?? '').toString(),
      etaHhMm: (json['eta'] ?? '').toString(),
    );
  }
}
