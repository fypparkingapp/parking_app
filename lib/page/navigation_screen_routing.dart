part of 'navigation_screen.dart';

// Heuristic waypoint used to find a lower-toll alternative for routes that would
// otherwise go through Tai Lam Tunnel from the Yuen Long / Tin Shui Wai area.
const LatLng _tuenMunWaypoint = LatLng(22.3893, 113.9720);

// Tai Lam Tunnel corridor probe points (same as TollService detection points).
const List<LatLng> _taiLamTunnelProbePoints = [
  LatLng(22.4209200, 114.0644197),
  LatLng(22.4153790, 114.0630920),
  LatLng(22.4337560, 114.0616030),
];

extension _NavigationScreenRouting on _NavigationScreenState {
  static const double _taiLamTunnelProbeRadiusMeters = 650;
  static const int _taiLamTunnelProbeMinHits = 2;

  void _startTdasFetch(LatLng origin, LatLng destination) {
    if (!mounted) return;
    final token = ++_tdasRequestToken;
    final cacheKey = _tdasCacheKey(origin, destination);
    final cached = _tdasCache[cacheKey];
    if (cached != null) {
      _safeSetState(() => _tdasInsight = cached);
      return;
    }
    _safeSetState(() => _tdasInsight = null);
    unawaited(() async {
      final insight = await _fetchTdasInsightTracked(origin, destination);
      if (!mounted || token != _tdasRequestToken) return;
      if (insight != null) {
        _tdasCache[cacheKey] = insight;
      }
      _safeSetState(() => _tdasInsight = insight);
    }());
  }

  void _resetTdasState() {
    if (!mounted) return;
    _safeSetState(() {
      _tdasInsight = null;
      _tdasLoading = false;
    });
  }

  Future<void> _refreshTdasIfNeeded() async {
    if (!mounted || _tdasInsight != null || _origin == null || _tdasLoading) {
      return;
    }
    final origin = _origin!;
    final destination = LatLng(
      widget.carpark.latitude,
      widget.carpark.longitude,
    );
    final cacheKey = _tdasCacheKey(origin, destination);
    final cached = _tdasCache[cacheKey];
    if (cached != null) {
      _safeSetState(() => _tdasInsight = cached);
      return;
    }
    final insight = await _fetchTdasInsightTracked(origin, destination);
    if (!mounted) return;
    if (insight != null) {
      _tdasCache[cacheKey] = insight;
    }
    _safeSetState(() => _tdasInsight = insight);
  }

  Future<void> _refreshTdasNow() async {
    if (!mounted || _origin == null || _tdasLoading) return;
    final origin = _origin!;
    final destination = LatLng(
      widget.carpark.latitude,
      widget.carpark.longitude,
    );
    final cacheKey = _tdasCacheKey(origin, destination);
    final cached = _tdasCache[cacheKey];
    if (cached != null) {
      _safeSetState(() => _tdasInsight = cached);
      return;
    }
    final insight = await _fetchTdasInsightTracked(origin, destination);
    if (!mounted) return;
    if (insight != null) {
      _tdasCache[cacheKey] = insight;
    }
    _safeSetState(() => _tdasInsight = insight);
  }

  String _tdasCacheKey(LatLng origin, LatLng destination) =>
      '${origin.latitude.toStringAsFixed(6)},${origin.longitude.toStringAsFixed(6)}'
      '->${destination.latitude.toStringAsFixed(6)},${destination.longitude.toStringAsFixed(6)}';

  Future<TdasRouteInsight?> _fetchTdasInsightTracked(
    LatLng origin,
    LatLng destination,
  ) async {
    _safeSetState(() => _tdasLoading = true);
    try {
      return await _fetchTdasInsight(origin, destination);
    } finally {
      if (mounted) {
        _safeSetState(() => _tdasLoading = false);
      }
    }
  }

  void _stopNavigation() {
    _nav.stop();
    _safeSetState(() {});
  }

  bool _routeLooksLikeTaiLamTunnel(List<LatLng> route) {
    if (route.isEmpty) return false;
    final dist = const Distance();
    var hits = 0;
    for (final probe in _taiLamTunnelProbePoints) {
      for (final p in route) {
        if (dist(probe, p) <= _taiLamTunnelProbeRadiusMeters) {
          hits += 1;
          break;
        }
      }
      if (hits >= _taiLamTunnelProbeMinHits) return true;
    }
    return false;
  }

  String _routeSignature(routing.RouteResult r) =>
      '${r.distanceMeters.round()}|${r.durationSeconds.round()}|${r.points.length}';

  Future<List<routing.RouteResult>> _maybeAddTuenMunWaypointRoute({
    required List<routing.RouteResult> candidates,
    required LatLng origin,
    required LatLng destination,
  }) async {
    if (!_avoidTolls || candidates.isEmpty) return candidates;

    // Only attempt the extra waypoint route if at least one candidate seems to
    // pass through the Tai Lam Tunnel corridor.
    final hasTaiLam = candidates.any(
      (r) => _routeLooksLikeTaiLamTunnel(r.points),
    );
    if (!hasTaiLam) return candidates;

    final seen = <String>{for (final r in candidates) _routeSignature(r)};

    try {
      final forced = await _api.routeGeoJsonWaypoints(
        coordinates: [origin, _tuenMunWaypoint, destination],
        steps: true,
      );
      // If forcing via Tuen Mun still ends up near Tai Lam Tunnel, ignore it.
      if (_routeLooksLikeTaiLamTunnel(forced.points)) return candidates;

      final key = _routeSignature(forced);
      if (seen.add(key)) {
        return [...candidates, forced];
      }
    } catch (_) {
      // Ignore and keep existing candidates.
    }

    return candidates;
  }

  Future<void> _fetchRoute({bool preserveCamera = false}) async {
    if (_loading) return;
    _safeSetState(() {
      _loading = true;
      _error = null;
      _tollFilterNote = null;
    });
    try {
      final origin = _manualOrigin ?? await routing.getCurrentLatLng();
      final destination = LatLng(
        widget.carpark.latitude,
        widget.carpark.longitude,
      );
      final alternatives = _avoidTolls ? 3 : 2;
      var results = await _api.routeGeoJsonAlternatives(
        origin: origin,
        destination: destination,
        alternatives: alternatives,
        steps: true,
      );
      if (_avoidTolls) {
        final noTolls = await _api.routeGeoJsonAlternatives(
          origin: origin,
          destination: destination,
          alternatives: alternatives,
          steps: true,
          exclude: 'toll',
        );
        final noMotorways = await _api.routeGeoJsonAlternatives(
          origin: origin,
          destination: destination,
          alternatives: 0,
          steps: true,
          exclude: 'motorway',
        );
        if (noTolls.isNotEmpty || noMotorways.isNotEmpty) {
          final seen = <String>{for (final r in results) _routeSignature(r)};
          for (final r in [...noTolls, ...noMotorways]) {
            final key = _routeSignature(r);
            if (seen.add(key)) results = [...results, r];
          }
        }
      }
      results = await _maybeAddTuenMunWaypointRoute(
        candidates: results,
        origin: origin,
        destination: destination,
      );
      if (!mounted) return;
      if (results.isEmpty) {
        _resetTdasState();
        _safeSetState(() {
          _error = AppLocalizations.of(context)!.no_routes_available;
          _routes = const [];
          _routeResult = null;
          _origin = origin;
          _tollEstimates = const [];
        });
        return;
      }
      final prepared = await _prepareRoutesWithTolls(
        candidates: results,
        origin: origin,
        destination: destination,
      );

      if (!mounted) return;
      _startTdasFetch(origin, destination);
      _safeSetState(() {
        _origin = origin;
        _routes = prepared.routes;
        _selectedRouteIndex = 0;
        _routeResult = prepared.routes.isNotEmpty ? prepared.routes[0] : null;
        _tollEstimates = prepared.tolls;
        _tollFilterNote = prepared.note;
      });
      final shouldAutoStart = _pendingAutoStart && prepared.routes.isNotEmpty;
      if (shouldAutoStart) {
        _pendingAutoStart = false;
      }
      _scheduleRouteCardsJump();
      if (prepared.routes.isNotEmpty && !preserveCamera) {
        _fitCameraToRoute(prepared.routes[0].points);
      }
      if (shouldAutoStart) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _routeResult == null || _nav.navigating.value) return;
          _startNavigation();
        });
      }
    } catch (e) {
      if (!mounted) return;
      _resetTdasState();
      _safeSetState(() {
        _error = AppLocalizations.of(context)!.route_fetch_failed(e);
        _routes = const [];
        _routeResult = null;
        _origin = null;
        _tollEstimates = const [];
      });
    } finally {
      if (mounted) {
        _safeSetState(() => _loading = false);
      }
    }
  }

  Future<
    ({List<routing.RouteResult> routes, List<TollEstimate> tolls, String? note})
  >
  _prepareRoutesWithTolls({
    required List<routing.RouteResult> candidates,
    required LatLng origin,
    required LatLng destination,
  }) async {
    if (candidates.isEmpty) {
      return (
        routes: const <routing.RouteResult>[],
        tolls: const <TollEstimate>[],
        note: null,
      );
    }

    final roadOnly = candidates
        .where((r) => !r.hasFerry)
        .toList(growable: false);
    final tollCandidates = roadOnly.isNotEmpty ? roadOnly : candidates;

    final String? hkNowParam = _tollTimeMode == TollTimeMode.now
        ? await _tollService.fetchHkNowParam()
        : null;

    final tolls = await Future.wait(
      tollCandidates.map((r) {
        final dateTimeParam = _dateTimeParamForRoute(
          route: r,
          hkNowParam: hkNowParam,
        );
        return _tollService.estimateForRoute(
          route: r.points,
          origin: origin,
          destination: destination,
          dateTimeParam: dateTimeParam,
          stepNames: r.stepNames,
          languageCode: widget.languageCode,
          vehicleType: _vehicleType,
        );
      }),
    );

    final annotated = List<_AnnotatedRoute>.generate(
      tollCandidates.length,
      (i) => (route: tollCandidates[i], toll: tolls[i]),
      growable: false,
    );

    var filtered = [...annotated];
    String? note;
    filtered.sort(_compareAnnotatedByPriorities);
    if (_avoidTolls) {
      final verifiedTollFree = filtered
          .where((item) => item.toll.isTollFree)
          .toList(growable: false);
      if (verifiedTollFree.isNotEmpty) {
        verifiedTollFree.sort(_compareAnnotatedByPriorities);
        filtered = verifiedTollFree;
        if (filtered.first.route.majorRoadDistanceMeters <= 0) {
          note = AppLocalizations.of(
            context,
          )!.toll_free_route_may_avoid_major_roads;
        }
      } else {
        final anyKnown = filtered.any((item) => !item.toll.hasUnknown);
        if (!anyKnown) {
          note = AppLocalizations.of(
            context,
          )!.toll_info_unavailable_showing_best_route;
        } else {
          final sortedByMinToll = [...filtered];
          sortedByMinToll.sort((a, b) {
            final t = _compareTolls(a.toll, b.toll);
            if (t != 0) return t;
            return _compareAnnotatedByPriorities(a, b, includePrice: false);
          });
          filtered = sortedByMinToll;
          note = AppLocalizations.of(
            context,
          )!.no_toll_free_route_showing_lowest_toll_route;
        }
      }
    }

    return (
      routes: filtered.map((e) => e.route).toList(growable: false),
      tolls: filtered.map((e) => e.toll).toList(growable: false),
      note: note,
    );
  }

  Future<TdasRouteInsight?> _fetchTdasInsight(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      LatLng snappedOrigin = origin;
      try {
        final snapped = await _api.nearest(origin);
        if (snapped != null) snappedOrigin = snapped;
      } catch (_) {
        // Ignore snapping failures and fall back to the original point.
      }
      return await _tdas.fetchRoute(
        start: snappedOrigin,
        end: destination,
        type:
            _routePriorities.isNotEmpty &&
                _routePriorities.first == RouteSortKey.distance
            ? 'SD'
            : 'ST',
      );
    } catch (_) {
      return null;
    }
  }

  double _majorShare(routing.RouteResult r) => r.distanceMeters <= 0
      ? 0
      : (r.majorRoadDistanceMeters / r.distanceMeters);

  int _compareRoutesByTime(routing.RouteResult a, routing.RouteResult b) {
    final t = a.durationSeconds.compareTo(b.durationSeconds);
    if (t != 0) {
      if ((a.durationSeconds - b.durationSeconds).abs() <= 120) {
        final m = _majorShare(b).compareTo(_majorShare(a));
        if (m != 0) return m;
      }
      return t;
    }
    final m = _majorShare(b).compareTo(_majorShare(a));
    if (m != 0) return m;
    return a.distanceMeters.compareTo(b.distanceMeters);
  }

  int _compareRoutesByDistance(routing.RouteResult a, routing.RouteResult b) {
    final d = a.distanceMeters.compareTo(b.distanceMeters);
    if (d != 0) {
      if ((a.distanceMeters - b.distanceMeters).abs() <= 1500) {
        final m = _majorShare(b).compareTo(_majorShare(a));
        if (m != 0) return m;
      }
      return d;
    }
    final m = _majorShare(b).compareTo(_majorShare(a));
    if (m != 0) return m;
    return a.durationSeconds.compareTo(b.durationSeconds);
  }

  int _compareTolls(TollEstimate a, TollEstimate b) {
    final ta = a.hasUnknown ? double.infinity : a.totalHkd;
    final tb = b.hasUnknown ? double.infinity : b.totalHkd;
    return ta.compareTo(tb);
  }

  int _compareAnnotatedByPriorities(
    _AnnotatedRoute a,
    _AnnotatedRoute b, {
    bool includePrice = true,
  }) {
    final priorities = includePrice
        ? _routePriorities
        : _routePriorities.where((k) => k != RouteSortKey.price);

    for (final key in priorities) {
      final cmp = switch (key) {
        RouteSortKey.time => _compareRoutesByTime(a.route, b.route),
        RouteSortKey.distance => _compareRoutesByDistance(a.route, b.route),
        RouteSortKey.price => _compareTolls(a.toll, b.toll),
      };
      if (cmp != 0) return cmp;
    }

    final m = _majorShare(b.route).compareTo(_majorShare(a.route));
    if (m != 0) return m;
    final t = a.route.durationSeconds.compareTo(b.route.durationSeconds);
    if (t != 0) return t;
    return a.route.distanceMeters.compareTo(b.route.distanceMeters);
  }

  void _selectRoute(int index) {
    if (index < 0 || index >= _routes.length) return;
    _safeSetState(() {
      _selectedRouteIndex = index;
      _routeResult = _routes[index];
    });
    _refreshTdasNow();
    if (_routeCardsController.hasClients && _routes.length > 1) {
      final current = _routeCardsController.page?.round();
      if (current != index) {
        _routeCardsController.animateToPage(
          index,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    }
    _fitCameraToRoute(_routes[index].points);
  }

  void _scheduleRouteCardsJump() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_routeCardsController.hasClients) return;
      if (_routes.isEmpty) return;
      final safeIndex = _selectedRouteIndex.clamp(0, _routes.length - 1);
      _routeCardsController.jumpToPage(safeIndex);
    });
  }

  void _fitCameraToRoute(List<LatLng> pts) {
    final points = <LatLng>[
      ...pts,
      if (_origin != null) _origin!,
      LatLng(widget.carpark.latitude, widget.carpark.longitude),
    ];

    if (points.isEmpty) {
      _mapController.move(
        LatLng(widget.carpark.latitude, widget.carpark.longitude),
        15,
      );
      return;
    }

    if (points.length == 1) {
      _mapController.move(points.first, 15);
      return;
    }

    final bounds = LatLngBounds.fromPoints(points);
    final media = MediaQuery.of(context);
    final availableHeight = media.size.height;
    final bottomSheetHeight =
        availableHeight * _NavigationScreenState._kRouteSheetInitialSize;
    final bottomPadding = (bottomSheetHeight + media.padding.bottom + 24)
        .clamp(
          _NavigationScreenState._kCameraFitEdgePadding,
          availableHeight - 24,
        )
        .toDouble();
    final fit = CameraFit.bounds(
      bounds: bounds,
      padding: EdgeInsets.fromLTRB(
        _NavigationScreenState._kCameraFitEdgePadding,
        _NavigationScreenState._kCameraFitEdgePadding,
        _NavigationScreenState._kCameraFitEdgePadding,
        bottomPadding,
      ),
    );
    _mapController.fitCamera(fit);
  }

  String _formatDuration(double seconds) {
    final l10n = AppLocalizations.of(context)!;
    final totalMinutes = (seconds / 60).round();
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours > 0) {
      return l10n.duration_hours_minutes(hours, minutes);
    }
    return l10n.duration_minutes(minutes);
  }

  int? _parseTdasEtaMinutes(String? etaHhMm) {
    if (etaHhMm == null) return null;
    final parts = etaHhMm.split(':');
    if (parts.length < 2 || parts.length > 3) return null;
    final hours = int.tryParse(parts[0]);
    final minutes = int.tryParse(parts[1]);
    if (hours == null || minutes == null) return null;
    var totalMinutes = (hours * 60) + minutes;
    if (parts.length == 3) {
      final seconds = int.tryParse(parts[2]);
      if (seconds == null) return null;
      if (seconds >= 30) totalMinutes += 1;
    }
    return totalMinutes;
  }

  String _formatDurationMinutes(int totalMinutes) =>
      _formatDuration(totalMinutes * 60.0);

  ({int minMinutes, int maxMinutes}) _etaMinuteRange(
    routing.RouteResult route,
  ) {
    final osrmMinutes = (route.durationSeconds / 60).round();
    final tdasMinutes = _parseTdasEtaMinutes(_tdasInsight?.etaHhMm);
    if (tdasMinutes == null) {
      return (minMinutes: osrmMinutes, maxMinutes: osrmMinutes);
    }
    final shorter = osrmMinutes <= tdasMinutes ? osrmMinutes : tdasMinutes;
    final longer = osrmMinutes <= tdasMinutes ? tdasMinutes : osrmMinutes;
    return (minMinutes: shorter, maxMinutes: longer);
  }

  String _etaDisplayValue(routing.RouteResult route) {
    final range = _etaMinuteRange(route);
    if (range.minMinutes == range.maxMinutes) {
      return _formatDurationMinutes(range.minMinutes);
    }
    return '${_formatDurationMinutes(range.minMinutes)}~${_formatDurationMinutes(range.maxMinutes)}';
  }

  String _routeEtaSummaryValue(int index) {
    if (index < 0 || index >= _routes.length) {
      return '--';
    }
    final route = _routes[index];
    if (index != _selectedRouteIndex) {
      return _formatDuration(route.durationSeconds);
    }
    return _etaDisplayValue(route);
  }

  String _formatDistance(double meters) {
    final l10n = AppLocalizations.of(context)!;
    if (meters >= 1000) {
      final km = (meters / 1000).toStringAsFixed(1);
      return l10n.distance_km(km);
    }
    final m = meters.toStringAsFixed(0);
    return l10n.distance_m(m);
  }

  String _formatLocalDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    final local = dt.toLocal();
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  String _formatLocalTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    final local = dt.toLocal();
    return '${two(local.hour)}:${two(local.minute)}';
  }

  bool _isSameCalendarDay(DateTime a, DateTime b) {
    final left = a.toLocal();
    final right = b.toLocal();
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  String _formatLocalDateTimeRange(DateTime start, DateTime end) {
    final startLocal = start.toLocal();
    final endLocal = end.toLocal();
    if (startLocal.year == endLocal.year &&
        startLocal.month == endLocal.month &&
        startLocal.day == endLocal.day &&
        startLocal.hour == endLocal.hour &&
        startLocal.minute == endLocal.minute) {
      return _formatLocalDateTime(startLocal);
    }
    if (_isSameCalendarDay(startLocal, endLocal)) {
      return '${_formatLocalDateTime(startLocal)}~${_formatLocalTime(endLocal)}';
    }
    return '${_formatLocalDateTime(startLocal)}~${_formatLocalDateTime(endLocal)}';
  }

  String _tripTimeLabelForIndex(int index) {
    final l10n = AppLocalizations.of(context)!;
    if (index < 0 || index >= _routes.length) {
      return l10n.arrive_unknown;
    }
    final route = _routes[index];
    final etaRange = _etaMinuteRange(route);
    final now = DateTime.now();

    late final DateTime departAt;
    late final DateTime earliestArriveAt;
    late final DateTime latestArriveAt;
    switch (_tollTimeMode) {
      case TollTimeMode.now:
        departAt = now;
        earliestArriveAt = departAt.add(Duration(minutes: etaRange.minMinutes));
        latestArriveAt = departAt.add(Duration(minutes: etaRange.maxMinutes));
        return l10n.arrive_at(
          _formatLocalDateTimeRange(earliestArriveAt, latestArriveAt),
        );
      case TollTimeMode.departAt:
        departAt = _tollDateTime ?? now;
        earliestArriveAt = departAt.add(Duration(minutes: etaRange.minMinutes));
        latestArriveAt = departAt.add(Duration(minutes: etaRange.maxMinutes));
        return l10n.depart_and_arrive(
          _formatLocalDateTime(departAt),
          _formatLocalDateTimeRange(earliestArriveAt, latestArriveAt),
        );
      case TollTimeMode.arriveBy:
        final arriveAt = _tollDateTime ?? now;
        final earliestDepartAt = arriveAt.subtract(
          Duration(minutes: etaRange.maxMinutes),
        );
        final latestDepartAt = arriveAt.subtract(
          Duration(minutes: etaRange.minMinutes),
        );
        return l10n.arrive_and_est_depart(
          _formatLocalDateTime(arriveAt),
          _formatLocalDateTimeRange(earliestDepartAt, latestDepartAt),
        );
    }
  }

  TollEstimate? _tollForIndex(int index) {
    if (index < 0 || index >= _tollEstimates.length) return null;
    return _tollEstimates[index];
  }

  String _formatHkd(double amount) {
    final rounded = amount.roundToDouble();
    final s = (amount == rounded)
        ? rounded.toStringAsFixed(0)
        : amount.toStringAsFixed(1);
    return 'HK\$$s';
  }

  String _tollLabelForIndex(int index) {
    final l10n = AppLocalizations.of(context)!;
    final toll = _tollForIndex(index);
    if (toll == null) {
      return l10n.toll_unknown;
    }
    if (toll.isTollFree) {
      return l10n.no_toll_fees;
    }
    final base = l10n.est_toll(_formatHkd(toll.totalHkd));
    return toll.hasUnknown ? '$base +' : base;
  }

  List<Widget> _tollBreakdownRows(BuildContext context, int index) {
    final toll = _tollForIndex(index);
    if (toll == null || toll.charges.isEmpty) return const [];
    return [
      const SizedBox(height: 4),
      ...toll.charges.map(
        (c) => Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  c.facilityName,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _tollChargeAmountText(c),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  String _tollChargeAmountText(TollCharge charge) {
    final amount = charge.amountHkd;
    if (amount == null) {
      return AppLocalizations.of(context)!.toll_amount_unknown;
    }
    return _formatHkd(amount);
  }

  String _tollChipTextForIndex(int index) {
    final l10n = AppLocalizations.of(context)!;
    final toll = _tollForIndex(index);
    if (toll == null) {
      return l10n.toll_chip_unknown;
    }
    if (toll.isTollFree) {
      return l10n.toll_chip_free;
    }
    final amount = _formatHkd(toll.totalHkd);
    final prefix = l10n.toll_short;
    return toll.hasUnknown ? '$prefix $amount+' : '$prefix $amount';
  }

  String _tollAmountTextForIndex(int index) {
    final toll = _tollForIndex(index);
    if (toll == null) {
      return AppLocalizations.of(context)!.toll_amount_unknown;
    }
    if (toll.isTollFree) return _formatHkd(0);
    final amount = _formatHkd(toll.totalHkd);
    return toll.hasUnknown ? '$amount+' : amount;
  }

  String _routeSortKeyLabel(RouteSortKey key) {
    final l10n = AppLocalizations.of(context)!;
    switch (key) {
      case RouteSortKey.time:
        return l10n.time;
      case RouteSortKey.distance:
        return l10n.distance;
      case RouteSortKey.price:
        return l10n.toll_cost;
    }
  }
}
