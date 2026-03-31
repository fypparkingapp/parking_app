part of 'navigation_screen.dart';

extension _NavigationScreenUi on _NavigationScreenState {
  String _vacancyProbabilityLabel() {
    switch (widget.languageCode.toLowerCase()) {
      case 'tc':
        return '空位機率';
      case 'sc':
        return '空位机率';
      case 'en':
      default:
        return 'Vacancy chance';
    }
  }

  String _parkingEstimateLabel() {
    switch (widget.languageCode.toLowerCase()) {
      case 'tc':
        return '停車費預估';
      case 'sc':
        return '停车费预估';
      case 'en':
      default:
        return 'Est. parking';
    }
  }

  ({String label, Color color}) _vacancyProbabilityBadge(double probability) {
    if (probability >= 0.7) {
      return (
        label: switch (widget.languageCode.toLowerCase()) {
          'tc' => '高機率',
          'sc' => '高机率',
          _ => 'High chance',
        },
        color: const Color(0xFF1B8F4D),
      );
    }
    if (probability >= 0.4) {
      return (
        label: switch (widget.languageCode.toLowerCase()) {
          'tc' => '中機率',
          'sc' => '中机率',
          _ => 'Medium chance',
        },
        color: const Color(0xFFC58A00),
      );
    }
    return (
      label: switch (widget.languageCode.toLowerCase()) {
        'tc' => '低機率',
        'sc' => '低机率',
        _ => 'Low chance',
      },
      color: const Color(0xFFC44242),
    );
  }

  int _travelMinutesForProbability(routing.RouteResult route) {
    final osrmMinutes = (route.durationSeconds / 60).round();
    final tdasMinutes =
        _selectedRouteIndex >= 0 &&
            _selectedRouteIndex < _routes.length &&
            identical(route, _routes[_selectedRouteIndex])
        ? _parseTdasEtaMinutes(_tdasInsight?.etaHhMm)
        : null;
    if (tdasMinutes == null) return osrmMinutes;
    return osrmMinutes >= tdasMinutes ? osrmMinutes : tdasMinutes;
  }

  double? _vacancyProbabilityForIndex(int index) {
    if (index < 0 || index >= _routes.length) return null;
    return VacancyProbabilityEstimator.estimate(
      carpark: widget.carpark,
      travelMinutes: _travelMinutesForProbability(_routes[index]),
    );
  }

  String _vacancyProbabilityText(int index) {
    final probability = _vacancyProbabilityForIndex(index);
    if (probability == null) return '--';
    return _vacancyProbabilityBadge(probability).label;
  }

  Color _vacancyProbabilityColor(int index) {
    final probability = _vacancyProbabilityForIndex(index);
    if (probability == null) return widget.accentColor;
    return _vacancyProbabilityBadge(probability).color;
  }

  ParkingCostEstimate? _parkingEstimateForIndex(int index) {
    if (index < 0 || index >= _routes.length) return null;
    final arrivalDateTime = DateTime.now().add(
      Duration(minutes: _travelMinutesForProbability(_routes[index])),
    );
    return ParkingCostEstimator.estimateDetailed(
      widget.carpark,
      arrivalDateTime: arrivalDateTime,
      stayDuration: const Duration(hours: 3),
      languageCode: widget.languageCode,
    );
  }

  String _parkingEstimateText(int index) {
    final estimate = _parkingEstimateForIndex(index);
    if (estimate == null) return 'HK\$--';
    return _formatHkd(estimate.amountHkd);
  }

  String _vehicleTypeLabel(AppLocalizations l10n, HkVehicleType type) {
    switch (type) {
      case HkVehicleType.privateCar:
        return l10n.vehicle_type_private_car;
      case HkVehicleType.motorcycle:
        return l10n.vehicle_type_motorcycle;
      case HkVehicleType.taxi:
        return l10n.vehicle_type_taxi;
    }
  }

  Widget _buildVehicleTypeChip(AppLocalizations l10n) {
    return PopupMenuButton<HkVehicleType>(
      tooltip: l10n.vehicle_type,
      onSelected: (value) {
        if (value == _vehicleType) return;
        _safeSetState(() => _vehicleType = value);
        _fetchRoute();
      },
      itemBuilder: (context) => HkVehicleType.values
          .map(
            (type) => PopupMenuItem(
              value: type,
              child: Text(_vehicleTypeLabel(l10n, type)),
            ),
          )
          .toList(),
      child: Chip(
        label: Text(
          '${l10n.vehicle_type}: ${_vehicleTypeLabel(l10n, _vehicleType)}',
        ),
        avatar: const Icon(Icons.directions_car, size: 18),
      ),
    );
  }

  Widget _buildTopOverlay() {
    final l10n = AppLocalizations.of(context)!;
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_pickingStart)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Text(l10n.tap_map_to_set_start_point),
                  ),
                ),
              if (_nav.navigating.value &&
                  _nav.instructionText.value.isNotEmpty)
                Card(
                  color: Colors.black87,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      _nav.instructionText.value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if (_loading)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Text(l10n.requesting_route),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteSheet({
    required String destinationName,
    required String destinationAddress,
  }) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: DraggableScrollableSheet(
        initialChildSize: _NavigationScreenState._kRouteSheetInitialSize,
        minChildSize: _NavigationScreenState._kRouteSheetMinSize,
        maxChildSize: _NavigationScreenState._kRouteSheetMaxSize,
        builder: (sheetContext, scrollController) {
          final baseTheme = Theme.of(sheetContext);
          final theme = widget.preferDarkSheetText
              ? baseTheme.copyWith(
                  textTheme: baseTheme.textTheme.apply(
                    bodyColor: Colors.black,
                    displayColor: Colors.black,
                  ),
                  iconTheme: baseTheme.iconTheme.copyWith(
                    color: Colors.black87,
                  ),
                  colorScheme: baseTheme.colorScheme.copyWith(
                    onSurface: Colors.black,
                    onSurfaceVariant: Colors.black54,
                  ),
                )
              : baseTheme;
          final l10n = AppLocalizations.of(sheetContext)!;
          final canShowRoute = _routeResult != null && !_loading;
          final stepNames =
              (_selectedRouteIndex >= 0 && _selectedRouteIndex < _routes.length)
              ? _routes[_selectedRouteIndex].stepNames
              : const <String>[];
          final canSelectRoute = !_nav.navigating.value && !_loading;

          return Material(
            elevation: 12,
            color: theme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: theme.dividerColor.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_routes.isNotEmpty) ...[
                        SizedBox(
                          height: 120,
                          child: PageView.builder(
                            controller: _routeCardsController,
                            onPageChanged: (index) {
                              if (!canSelectRoute) return;
                              _selectRoute(index);
                            },
                            itemCount: _routes.length,
                            itemBuilder: (context, index) {
                              final r = _routes[index];
                              final selected = index == _selectedRouteIndex;
                              final title = l10n.route_number(index + 1);
                              final subtitle =
                                  '${_routeEtaSummaryValue(index)} · ${_formatDistance(r.distanceMeters)}';
                              final toll = _tollAmountTextForIndex(index);
                              final vacancyProbability =
                                  _vacancyProbabilityText(index);
                              final vacancyColor = _vacancyProbabilityColor(
                                index,
                              );
                              final parkingEstimate = _parkingEstimateText(
                                index,
                              );
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: _RouteSummaryCard(
                                  title: title,
                                  subtitle: subtitle,
                                  tollText: toll,
                                  vacancyProbabilityText: vacancyProbability,
                                  vacancyProbabilityColor: vacancyColor,
                                  vacancyProbabilityLabel:
                                      _vacancyProbabilityLabel(),
                                  parkingEstimateLabel: _parkingEstimateLabel(),
                                  parkingEstimateText: parkingEstimate,
                                  selected: selected,
                                  accentColor: widget.accentColor,
                                  onTap: canSelectRoute
                                      ? () => _selectRoute(index)
                                      : null,
                                ),
                              );
                            },
                          ),
                        ),
                        if (_routes.length > 1) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(_routes.length, (i) {
                              final selected = i == _selectedRouteIndex;
                              final color = selected
                                  ? widget.accentColor
                                  : theme.dividerColor.withValues(alpha: 0.8);
                              return InkWell(
                                onTap: canSelectRoute
                                    ? () => _selectRoute(i)
                                    : null,
                                borderRadius: BorderRadius.circular(999),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  width: selected ? 18 : 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                        const SizedBox(height: 12),
                      ],
                      if (destinationAddress.isNotEmpty)
                        Text(
                          destinationAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      if (destinationAddress.isNotEmpty)
                        const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                ActionChip(
                                  label: Text(_tollTimeChipLabel()),
                                  avatar: const Icon(Icons.schedule, size: 18),
                                  onPressed: _showTollTimePicker,
                                ),
                                const SizedBox(width: 8),
                                FilterChip(
                                  label: Text(l10n.avoid_toll_fees),
                                  selected: _avoidTolls,
                                  onSelected: (value) {
                                    _safeSetState(() => _avoidTolls = value);
                                    _fetchRoute();
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildVehicleTypeChip(l10n),
                        ],
                      ),
                      if (_error != null && !_loading) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                l10n.routing_failed,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _error!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    _fetchRoute(preserveCamera: true),
                                icon: const Icon(Icons.refresh),
                                label: Text(l10n.retry),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (!canShowRoute && !_loading && _error == null) ...[
                        const SizedBox(height: 12),
                        Text(
                          l10n.no_route_data_yet,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                      if (canShowRoute) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _InfoChip(
                              label: l10n.eta,
                              value: _etaDisplayValue(_routeResult!),
                              color: widget.accentColor,
                            ),
                            const SizedBox(width: 12),
                            _InfoChip(
                              label: l10n.distance,
                              value: _formatDistance(
                                _routeResult!.distanceMeters,
                              ),
                              color: widget.accentColor,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _InfoChip(
                              label: _vacancyProbabilityLabel(),
                              value: _vacancyProbabilityText(
                                _selectedRouteIndex,
                              ),
                              color: _vacancyProbabilityColor(
                                _selectedRouteIndex,
                              ),
                            ),
                            const SizedBox(width: 12),
                            _InfoChip(
                              label: _parkingEstimateLabel(),
                              value: _parkingEstimateText(_selectedRouteIndex),
                              color: widget.accentColor,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Expanded(
                              child: Text(
                                l10n.tdas_eta(
                                  _tdasInsight?.etaHhMm ?? '--',
                                  _tdasInsight?.journeySpeed ?? '--',
                                ),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: l10n.refresh,
                              icon: _tdasLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.refresh, size: 18),
                              onPressed: _origin == null || _tdasLoading
                                  ? null
                                  : _refreshTdasNow,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 18,
                              color: widget.accentColor,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _tripTimeLabelForIndex(_selectedRouteIndex),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              Icons.toll,
                              size: 18,
                              color: widget.accentColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _tollLabelForIndex(_selectedRouteIndex),
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: widget.accentColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              Icons.local_parking,
                              size: 18,
                              color: widget.accentColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${_parkingEstimateLabel()}: ${_parkingEstimateText(_selectedRouteIndex)}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: widget.accentColor,
                              ),
                            ),
                          ],
                        ),
                        ..._tollBreakdownRows(
                          sheetContext,
                          _selectedRouteIndex,
                        ),
                        if (_tollFilterNote != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _tollFilterNote!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.orange[800],
                            ),
                          ),
                        ],
                      ],
                      if (_routes.length > 1) ...[
                        const SizedBox(height: 10),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: const EdgeInsets.only(bottom: 4),
                          title: Text(
                            l10n.compare_routes,
                            style: theme.textTheme.titleSmall,
                          ),
                          children: [
                            for (int i = 0; i < _routes.length; i++) ...[
                              if (i > 0)
                                const Divider(
                                  height: 1,
                                  thickness: 1,
                                  indent: 8,
                                  endIndent: 8,
                                ),
                              _RouteOptionTile(
                                title: l10n.route_number(i + 1),
                                subtitle:
                                    '${_routeEtaSummaryValue(i)} · ${_formatDistance(_routes[i].distanceMeters)} · ${_tollChipTextForIndex(i)}',
                                selected: i == _selectedRouteIndex,
                                accentColor: widget.accentColor,
                                onTap: canSelectRoute
                                    ? () => _selectRoute(i)
                                    : null,
                              ),
                            ],
                          ],
                        ),
                      ],
                      if (stepNames.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: const EdgeInsets.only(bottom: 4),
                          title: Text(
                            l10n.roads,
                            style: theme.textTheme.titleSmall,
                          ),
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final name in stepNames.take(40))
                                  Chip(
                                    label: Text(
                                      name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                            if (stepNames.length > 40) ...[
                              const SizedBox(height: 8),
                              Text(
                                l10n.more_roads_omitted,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        destinationName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _routeResult == null
                                ? null
                                : (_nav.navigating.value
                                      ? _stopNavigation
                                      : _startNavigation),
                            icon: Icon(
                              _nav.navigating.value
                                  ? Icons.stop
                                  : Icons.play_arrow,
                            ),
                            label: Text(
                              _nav.navigating.value
                                  ? l10n.stop
                                  : l10n.start_navigation,
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: _nav.navigating.value
                                  ? Colors.red
                                  : widget.accentColor,
                              foregroundColor: widget.appBarForeground,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () => _fetchRoute(preserveCamera: true),
                          icon: const Icon(Icons.directions),
                          label: Text(l10n.refresh),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _startNavigation() {
    if (_routeResult == null) return;
    final routePts = _routes[_selectedRouteIndex].points;
    final dest = LatLng(widget.carpark.latitude, widget.carpark.longitude);
    final initialPos = _nav.vehiclePosition.value ?? _origin;
    if (initialPos != null) {
      unawaited(
        _animateCameraToNavigationPosition(initialPos, forceZoom: true),
      );
    }
    _nav.startNavigation(
      route: routePts,
      initialPosition: _origin,
      destination: dest,
      onRerouteRequested: (origin, destination) async {
        final now = DateTime.now();
        if (_lastRerouteAt != null &&
            now.difference(_lastRerouteAt!).inSeconds < 10) {
          return;
        }
        _lastRerouteAt = now;
        try {
          _startTdasFetch(origin, destination);
          var results = await _api.routeGeoJsonAlternatives(
            origin: origin,
            destination: destination,
            alternatives:
                (_avoidTolls || _routePriorities.contains(RouteSortKey.price))
                ? 3
                : 0,
            steps: true,
          );
          if (_avoidTolls) {
            final noTolls = await _api.routeGeoJsonAlternatives(
              origin: origin,
              destination: destination,
              alternatives: 3,
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
              final seen = <String>{
                for (final r in results) _routeSignature(r),
              };
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
          if (!mounted || results.isEmpty) return;
          final prepared = await _prepareRoutesWithTolls(
            candidates: results,
            origin: origin,
            destination: destination,
          );
          if (!mounted) return;
          _safeSetState(() {
            _routes = prepared.routes;
            _selectedRouteIndex = 0;
            _routeResult = prepared.routes.isNotEmpty
                ? prepared.routes[0]
                : null;
            _origin = origin;
            _tollEstimates = prepared.tolls;
            _tollFilterNote = prepared.note;
          });
          _scheduleRouteCardsJump();
          // restart navigation with new route
          _startNavigation();
        } catch (_) {}
      },
    );
  }
}
