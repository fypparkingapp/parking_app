import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum _UiLang { en, tc, sc }

/// NavigationService manages real-time navigation along a precomputed route
/// (a list of LatLng points, typically decoded from an OSRM polyline).
///
/// Responsibilities:
/// - Subscribe to GPS updates (distance filter 5 m) and expose current position
/// - Advance step when within [arrivalThresholdMeters] of the next route point
/// - Provide simple, geometry-based turn instructions for the next maneuver
/// - Detect basic off-route situations and invoke [onRerouteRequested]
class NavigationService {
  NavigationService({
    this.arrivalThresholdMeters = 20,
    this.offRouteThresholdMeters = 50,
    this.languageCode = 'en',
  });

  final double arrivalThresholdMeters;
  final double offRouteThresholdMeters;
  final String languageCode;

  _UiLang get _uiLang {
    switch (languageCode.toLowerCase()) {
      case 'tc':
        return _UiLang.tc;
      case 'sc':
        return _UiLang.sc;
      case 'en':
      default:
        return _UiLang.en;
    }
  }

  String _tr({required String en, required String tc, required String sc}) {
    switch (_uiLang) {
      case _UiLang.tc:
        return tc;
      case _UiLang.sc:
        return sc;
      case _UiLang.en:
        return en;
    }
  }

  final ValueNotifier<bool> navigating = ValueNotifier<bool>(false);
  final ValueNotifier<int> stepIndex = ValueNotifier<int>(0);
  final ValueNotifier<String> instructionText = ValueNotifier<String>('');
  final ValueNotifier<LatLng?> vehiclePosition = ValueNotifier<LatLng?>(null);

  List<LatLng> _route = const [];
  StreamSubscription<Position>? _sub;
  void Function(LatLng origin, LatLng destination)? _onRerouteRequested;
  LatLng? _destination;

  Future<void> startNavigation({
    required List<LatLng> route,
    LatLng? initialPosition,
    LatLng? destination,
    void Function(LatLng origin, LatLng destination)? onRerouteRequested,
  }) async {
    await stop();
    if (route.isEmpty) return;
    _route = route;
    _destination = destination ?? route.last;
    _onRerouteRequested = onRerouteRequested;
    stepIndex.value = 0;
    instructionText.value = _tr(
      en: 'Head to start and follow the route',
      tc: '前往起點並跟隨路線',
      sc: '前往起点并跟随路线',
    );

    // Ensure permission
    await _ensurePermission();

    // Seed position if provided
    if (initialPosition != null) {
      vehiclePosition.value = initialPosition;
    } else {
      try {
        final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.bestForNavigation);
        vehiclePosition.value = LatLng(pos.latitude, pos.longitude);
      } catch (_) {}
    }

    navigating.value = true;

    final locSettings = const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5, // meters
    );

    _sub = Geolocator.getPositionStream(locationSettings: locSettings).listen((pos) {
      final user = LatLng(pos.latitude, pos.longitude);
      vehiclePosition.value = user;
      _updateProgress(user);
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    navigating.value = false;
  }

  Future<void> dispose() async {
    await stop();
    vehiclePosition.dispose();
    instructionText.dispose();
    stepIndex.dispose();
    navigating.dispose();
  }

  Future<void> _ensurePermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
  }

  void _updateProgress(LatLng user) {
    if (_route.isEmpty) return;

    // Advance to next waypoint if close enough
    var idx = stepIndex.value;
    if (idx < _route.length) {
      final target = _route[idx];
      final d = _distance(user, target);
      if (d <= arrivalThresholdMeters) {
        idx += 1;
        stepIndex.value = idx;
      }
    }

    // Finished?
    if (idx >= _route.length) {
      instructionText.value = _tr(
        en: 'Arrived at destination',
        tc: '已到達目的地',
        sc: '已到达目的地',
      );
      stop();
      return;
    }

    // Update instruction to next maneuver using simple geometry
    instructionText.value = _buildInstruction(user, idx);

    // Off-route detection (distance to nearest segment)
    final distToRoute = _minDistanceToRoute(user);
    if (distToRoute > offRouteThresholdMeters && _onRerouteRequested != null && _destination != null) {
      _onRerouteRequested!(user, _destination!);
    }
  }

  String _buildInstruction(LatLng user, int idx) {
    // Next waypoint distance
    final next = _route[idx];
    final dist = _distance(user, next);

    // Determine maneuver if we have previous and next segments
    final prev = idx > 0 ? _route[idx - 1] : user;
    final after = idx + 1 < _route.length ? _route[idx + 1] : null;

    if (after != null) {
      final bearingIn = _bearing(prev, next);
      final bearingOut = _bearing(next, after);
      final delta = _normalizeAngle(bearingOut - bearingIn);
      final turn = _turnFromDelta(delta);
      final distStr = _fmtDistance(dist);
      return _tr(
        en: 'In $distStr, $turn',
        tc: '前方 $distStr，$turn',
        sc: '前方 $distStr，$turn',
      );
    }

    // Last leg: guide to destination
    final distStr = _fmtDistance(dist);
    return _tr(
      en: 'Continue for $distStr to destination',
      tc: '繼續行駛 $distStr 到目的地',
      sc: '继续行驶 $distStr 到目的地',
    );
  }

  double _distance(LatLng a, LatLng b) {
    return const Distance().as(LengthUnit.Meter, a, b);
  }

  double _bearing(LatLng a, LatLng b) {
    final lat1 = _toRad(a.latitude);
    final lat2 = _toRad(b.latitude);
    final dLon = _toRad(b.longitude - a.longitude);
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final brng = math.atan2(y, x);
    return (_toDeg(brng) + 360) % 360;
  }

  double _normalizeAngle(double deg) {
    var d = deg % 360;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    return d;
  }

  String _turnFromDelta(double deltaDeg) {
    final ad = deltaDeg.abs();
    if (ad < 20) {
      return _tr(en: 'continue straight', tc: '直行', sc: '直行');
    }
    if (ad < 45) {
      return deltaDeg > 0
          ? _tr(en: 'bear left', tc: '靠左', sc: '靠左')
          : _tr(en: 'bear right', tc: '靠右', sc: '靠右');
    }
    if (ad < 135) {
      return deltaDeg > 0
          ? _tr(en: 'turn left', tc: '左轉', sc: '左转')
          : _tr(en: 'turn right', tc: '右轉', sc: '右转');
    }
    return _tr(en: 'make a U-turn', tc: '掉頭', sc: '掉头');
  }

  String _fmtDistance(double m) {
    if (m >= 1000) {
      final km = (m / 1000).toStringAsFixed(1);
      return _tr(en: '$km km', tc: '$km 公里', sc: '$km 公里');
    }
    final meters = m.toStringAsFixed(0);
    return _tr(en: '$meters m', tc: '$meters 米', sc: '$meters 米');
  }

  double _toRad(double deg) => deg * math.pi / 180.0;
  double _toDeg(double rad) => rad * 180.0 / math.pi;

  double _minDistanceToRoute(LatLng p) {
    if (_route.length < 2) return double.infinity;
    double minD = double.infinity;
    for (var i = 0; i < _route.length - 1; i++) {
      final d = _distancePointToSegment(p, _route[i], _route[i + 1]);
      if (d < minD) minD = d;
    }
    return minD;
  }

  // Returns distance from point P to segment AB (meters) using projection on great-circle approximated by planar on small scale
  double _distancePointToSegment(LatLng p, LatLng a, LatLng b) {
    // Work in meters using a local projection approximation: convert lat/lng to meters relative to A.
    final mPerDegLat = 111320.0;
    final mPerDegLng = 40075000 * math.cos(_toRad(a.latitude)) / 360.0;
    final ax = 0.0;
    final ay = 0.0;
    final bx = (b.longitude - a.longitude) * mPerDegLng;
    final by = (b.latitude - a.latitude) * mPerDegLat;
    final px = (p.longitude - a.longitude) * mPerDegLng;
    final py = (p.latitude - a.latitude) * mPerDegLat;

    final abx = bx - ax;
    final aby = by - ay;
    final apx = px - ax;
    final apy = py - ay;
    final ab2 = abx * abx + aby * aby;
    if (ab2 == 0) return math.sqrt(apx * apx + apy * apy);
    var t = (apx * abx + apy * aby) / ab2;
    t = t.clamp(0.0, 1.0);
    final cx = ax + t * abx;
    final cy = ay + t * aby;
    final dx = px - cx;
    final dy = py - cy;
    return math.sqrt(dx * dx + dy * dy);
  }
}
