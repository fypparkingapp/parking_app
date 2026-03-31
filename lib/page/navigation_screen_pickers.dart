part of 'navigation_screen.dart';

extension _NavigationScreenPickers on _NavigationScreenState {
  Future<void> _showRoutePrioritiesPicker() async {
    if (!mounted) return;
    final initial = [..._routePriorities];
    final result = await showModalBottomSheet<List<RouteSortKey>>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        var local = [...initial];
        bool selected(RouteSortKey k) => local.contains(k);
        int? order(RouteSortKey k) =>
            selected(k) ? (local.indexOf(k) + 1) : null;

        void toggle(RouteSortKey k, bool next) {
          if (next) {
            if (!selected(k)) local = [...local, k];
          } else {
            if (!selected(k)) return;
            if (local.length <= 1) return;
            local = [...local]..remove(k);
          }
        }

        void makePrimary(RouteSortKey k) {
          if (!selected(k)) return;
          local = [k, ...local.where((x) => x != k)];
        }

        return SafeArea(
          child: StatefulBuilder(
            builder: (ctx, setModalState) {
              final keys = const [
                RouteSortKey.time,
                RouteSortKey.distance,
                RouteSortKey.price,
              ];

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(
                      l10n.route_priorities,
                    ),
                    subtitle: Text(
                      l10n.route_priorities_subtitle,
                    ),
                  ),
                  for (final k in keys)
                    ListTile(
                      leading: Checkbox(
                        value: selected(k),
                        onChanged: (v) {
                          if (v == null) return;
                          toggle(k, v);
                          setModalState(() {});
                        },
                      ),
                      title: Text(_routeSortKeyLabel(k)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (selected(k))
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Text('#${order(k)}'),
                            ),
                          IconButton(
                            tooltip: l10n.set_primary,
                            icon: Icon(
                              order(k) == 1 ? Icons.star : Icons.star_border,
                            ),
                            onPressed: () {
                              if (!selected(k)) {
                                toggle(k, true);
                              }
                              makePrimary(k);
                              setModalState(() {});
                            },
                          ),
                        ],
                      ),
                      onTap: () {
                        toggle(k, !selected(k));
                        setModalState(() {});
                      },
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: Text(l10n.cancel),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(local),
                          child: Text(l10n.apply),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    if (!mounted || result == null) return;
    if (result.isEmpty) return;
    _safeSetState(() => _routePriorities = result);
    _fetchRoute();
  }

  String _startHeaderLabel() {
    final l10n = AppLocalizations.of(context)!;
    if (_manualOrigin == null) {
      return l10n.from_current_location;
    }
    return l10n.from_selected_start;
  }

  Future<void> _showStartPicker() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  l10n.choose_start_point,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.my_location),
                title: Text(
                  l10n.use_current_location,
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _safeSetState(() {
                    _manualOrigin = null;
                    _pickingStart = false;
                  });
                  _fetchRoute();
                },
              ),
              ListTile(
                leading: const Icon(Icons.map),
                title: Text(l10n.pick_on_map),
                subtitle: Text(
                  l10n.tap_map_to_place_start_marker,
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _safeSetState(() => _pickingStart = true);
                },
              ),
              if (_manualOrigin != null)
                ListTile(
                  leading: const Icon(Icons.clear),
                  title: Text(
                    l10n.clear_selected_start,
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _safeSetState(() {
                      _manualOrigin = null;
                      _pickingStart = false;
                    });
                    _fetchRoute();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  String _tollTimeModeLabel() {
    final l10n = AppLocalizations.of(context)!;
    switch (_tollTimeMode) {
      case TollTimeMode.now:
        return l10n.toll_time_mode_now;
      case TollTimeMode.departAt:
        return l10n.toll_time_mode_depart_at;
      case TollTimeMode.arriveBy:
        return l10n.toll_time_mode_arrive_by;
    }
  }

  String _tollTimeSummaryText() {
    final dt = _tollDateTime;
    final mode = _tollTimeModeLabel();
    if (_tollTimeMode == TollTimeMode.now || dt == null) return mode;

    String two(int n) => n.toString().padLeft(2, '0');
    final l = dt.toLocal();
    final stamp =
        '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
    return '$mode $stamp';
  }

  String _tollTimeChipLabel() {
    final l10n = AppLocalizations.of(context)!;
    return '${l10n.toll_time}: ${_tollTimeSummaryText()}';
  }

  Future<void> _showTollTimePicker() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (ctx, setModalState) {
              final l10n = AppLocalizations.of(ctx)!;
              Future<void> pickDateTime() async {
                final initial = _tollDateTime ?? DateTime.now();
                final date = await showDatePicker(
                  context: ctx,
                  initialDate: initial,
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (date == null) return;
                final time = await showTimePicker(
                  context: ctx,
                  initialTime: TimeOfDay.fromDateTime(initial),
                );
                if (time == null) return;
                final next = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  time.hour,
                  time.minute,
                );
                _safeSetState(() => _tollDateTime = next);
                setModalState(() {});
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(
                      l10n.toll_pricing_time,
                    ),
                  ),
                  RadioListTile<TollTimeMode>(
                    value: TollTimeMode.now,
                    groupValue: _tollTimeMode,
                    title: Text(
                      l10n.use_current_time,
                    ),
                    onChanged: (v) {
                      if (v == null) return;
                      _safeSetState(() {
                        _tollTimeMode = v;
                        _tollDateTime = null;
                      });
                      setModalState(() {});
                    },
                  ),
                  RadioListTile<TollTimeMode>(
                    value: TollTimeMode.departAt,
                    groupValue: _tollTimeMode,
                    title: Text(
                      l10n.set_departure_time,
                    ),
                    subtitle:
                        _tollDateTime != null &&
                            _tollTimeMode == TollTimeMode.departAt
                        ? Text(_tollTimeSummaryText())
                        : null,
                    onChanged: (v) {
                      if (v == null) return;
                      _safeSetState(() => _tollTimeMode = v);
                      setModalState(() {});
                    },
                  ),
                  RadioListTile<TollTimeMode>(
                    value: TollTimeMode.arriveBy,
                    groupValue: _tollTimeMode,
                    title: Text(
                      l10n.set_arrival_time_estimated,
                    ),
                    subtitle:
                        _tollDateTime != null &&
                            _tollTimeMode == TollTimeMode.arriveBy
                        ? Text(_tollTimeSummaryText())
                        : null,
                    onChanged: (v) {
                      if (v == null) return;
                      _safeSetState(() => _tollTimeMode = v);
                      setModalState(() {});
                    },
                  ),
                  if (_tollTimeMode != TollTimeMode.now)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: pickDateTime,
                              icon: const Icon(Icons.edit_calendar),
                              label: Text(
                                _tollDateTime == null
                                    ? l10n.pick_date_time
                                    : l10n.change_date_time,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _fetchRoute();
                        },
                        child: Text(l10n.apply),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  String _dateTimeParamForRoute({
    required routing.RouteResult route,
    required String? hkNowParam,
  }) {
    switch (_tollTimeMode) {
      case TollTimeMode.now:
        return hkNowParam ?? TollService.formatDateTimeParam(DateTime.now());
      case TollTimeMode.departAt:
        final dt = _tollDateTime ?? DateTime.now();
        return TollService.formatDateTimeParam(dt);
      case TollTimeMode.arriveBy:
        final arrive = _tollDateTime ?? DateTime.now();
        final depart = arrive.subtract(
          Duration(seconds: route.durationSeconds.round()),
        );
        return TollService.formatDateTimeParam(depart);
    }
  }
}
