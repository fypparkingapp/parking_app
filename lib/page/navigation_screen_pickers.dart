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
                    title: Text(l10n.route_priorities),
                    subtitle: Text(l10n.route_priorities_subtitle),
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
    return l10n.from_start_point_coords(_formatLatLng(_manualOrigin!));
  }

  String _formatLatLng(LatLng latLng) {
    return '${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}';
  }

  bool get _prefersChineseStartSearch {
    final code = widget.languageCode.toLowerCase();
    return code == 'tc' || code == 'sc' || code.startsWith('zh');
  }

  AppLanguage get _startSearchAppLanguage {
    final code = widget.languageCode.toLowerCase();
    if (code == 'tc' || code == 'zh' || code == 'zh_hk' || code == 'zh_tw') {
      return AppLanguage.traditionalChinese;
    }
    if (code == 'sc' || code == 'zh_cn') {
      return AppLanguage.simplifiedChinese;
    }
    return AppLanguage.english;
  }

  List<SavedPlace> _decodeSavedPlaces(List<String> encoded) {
    final places = <SavedPlace>[];
    for (final raw in encoded) {
      try {
        final json = jsonDecode(raw);
        if (json is Map<String, dynamic>) {
          places.add(SavedPlace.fromJson(json));
        }
      } catch (_) {
        continue;
      }
    }
    return places;
  }

  Future<void> _restoreStartSearchData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedRaw =
          prefs.getStringList(_NavigationScreenState._savedPlacesPrefKey) ??
          const [];
      final recentRaw =
          prefs.getStringList(
            _NavigationScreenState._recentStartSearchPrefKey,
          ) ??
          const [];
      final recentCarparks =
          prefs.getStringList(_NavigationScreenState._recentSearchPrefKey) ??
          const [];
      final favoriteCarparks =
          prefs.getStringList(_NavigationScreenState._favoriteCarparkPrefKey) ??
          const [];
      final recentMetered =
          prefs.getStringList(_NavigationScreenState._recentMeteredPrefKey) ??
          const [];
      final recentCombined =
          prefs.getStringList(_NavigationScreenState._recentCombinedPrefKey) ??
          const [];
      final saved = _decodeSavedPlaces(savedRaw);
      final recent = _decodeSavedPlaces(recentRaw);
      _safeSetState(() {
        _savedPlaces = saved;
        _recentStartSearches = recent;
        _recentSearchCarparkIds = recentCarparks;
        _favoriteCarparkIds = favoriteCarparks;
        _recentMeteredKeys = recentMetered;
        _recentCombinedKeys = recentCombined;
      });
    } catch (_) {}
  }

  Future<void> _saveRecentStartSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = _recentStartSearches
          .map((place) => jsonEncode(place.toJson()))
          .toList(growable: false);
      await prefs.setStringList(
        _NavigationScreenState._recentStartSearchPrefKey,
        encoded,
      );
    } catch (_) {}
  }

  Future<void> _persistStartSearchRecents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _NavigationScreenState._recentSearchPrefKey,
        _recentSearchCarparkIds,
      );
      await prefs.setStringList(
        _NavigationScreenState._recentMeteredPrefKey,
        _recentMeteredKeys,
      );
      await prefs.setStringList(
        _NavigationScreenState._recentCombinedPrefKey,
        _recentCombinedKeys,
      );
    } catch (_) {}
  }

  Future<void> _saveSavedPlaces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = _savedPlaces
          .map((place) => jsonEncode(place.toJson()))
          .toList(growable: false);
      await prefs.setStringList(
        _NavigationScreenState._savedPlacesPrefKey,
        encoded,
      );
    } catch (_) {}
  }

  String _savedPlaceKey(SavedPlace place) {
    return '${place.latitude.toStringAsFixed(6)},${place.longitude.toStringAsFixed(6)}|${place.label.trim()}|${place.displayName.trim()}';
  }

  Future<void> _addSavedPlaceFromSearch(SavedPlace place) async {
    final key = _savedPlaceKey(place);
    final deduped = <SavedPlace>[
      place,
      ..._savedPlaces.where((item) => _savedPlaceKey(item) != key),
    ];
    final limited = deduped
        .take(_NavigationScreenState._maxSavedPlaces)
        .toList(growable: false);
    _safeSetState(() => _savedPlaces = limited);
    await _saveSavedPlaces();
  }

  Future<void> _removeSavedPlaceFromSearch(SavedPlace place) async {
    final key = _savedPlaceKey(place);
    final next = _savedPlaces
        .where((item) => _savedPlaceKey(item) != key)
        .toList(growable: false);
    _safeSetState(() => _savedPlaces = next);
    await _saveSavedPlaces();
  }

  void _recordRecentStartLocation(GeocodingResult location) {
    final title = _prefersChineseStartSearch
        ? (location.nameZh ?? location.displayName)
        : (location.nameEn ?? location.displayName);
    final entry = SavedPlace(
      label: '',
      displayName: title.isNotEmpty ? title : location.displayName,
      latitude: location.latitude,
      longitude: location.longitude,
    );
    final key = _savedPlaceKey(entry);
    final deduped = <SavedPlace>[
      entry,
      ..._recentStartSearches.where((item) => _savedPlaceKey(item) != key),
    ];
    final limited = deduped
        .take(_NavigationScreenState._maxRecentStartSearches)
        .toList();
    _safeSetState(() => _recentStartSearches = limited);
    unawaited(_saveRecentStartSearches());
  }

  void _rememberStartSearchCarpark(parking.Carpark carpark) {
    final id = carpark.id;
    final nextCarparks = <String>[
      id,
      ..._recentSearchCarparkIds.where((entry) => entry != id),
    ];
    final max = _NavigationScreenState._maxRecentStartSearches;
    final limitedCarparks = nextCarparks.take(max).toList(growable: false);
    final token = 'p:$id';
    final nextCombined = <String>[
      token,
      ..._recentCombinedKeys.where((entry) => entry != token),
    ];
    final limitedCombined = nextCombined.take(max * 2).toList(growable: false);
    _safeSetState(() {
      _recentSearchCarparkIds = limitedCarparks;
      _recentCombinedKeys = limitedCombined;
    });
    unawaited(_persistStartSearchRecents());
  }

  void _rememberStartSearchMetered(MeteredStreetGroup group) {
    final key = group.key;
    final nextMetered = <String>[
      key,
      ..._recentMeteredKeys.where((entry) => entry != key),
    ];
    final max = _NavigationScreenState._maxRecentStartSearches;
    final limitedMetered = nextMetered.take(max).toList(growable: false);
    final token = 'm:$key';
    final nextCombined = <String>[
      token,
      ..._recentCombinedKeys.where((entry) => entry != token),
    ];
    final limitedCombined = nextCombined.take(max * 2).toList(growable: false);
    _safeSetState(() {
      _recentMeteredKeys = limitedMetered;
      _recentCombinedKeys = limitedCombined;
    });
    unawaited(_persistStartSearchRecents());
  }

  Future<void> _ensureStartSearchDatasets() async {
    if (_startSearchDataLoaded) return;
    try {
      final results = await Future.wait([
        parking.ParkingApi.fetchCarparks(),
        _startMeteredService.fetchStreetGroups(vehicleTypes: const {'A'}),
      ]);
      if (!mounted) return;
      _safeSetState(() {
        _startSearchCarparks = results[0].cast<parking.Carpark>();
        _startSearchMeteredGroups = results[1].cast<MeteredStreetGroup>();
        _startSearchDataLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      _safeSetState(() {
        _startSearchDataLoaded = true;
      });
    }
  }

  List<parking.Carpark> _recentSearchCarparksForStartSearch() {
    if (_recentSearchCarparkIds.isEmpty || _startSearchCarparks.isEmpty) {
      return const [];
    }
    final index = <String, parking.Carpark>{
      for (final carpark in _startSearchCarparks) carpark.id: carpark,
    };
    final out = <parking.Carpark>[];
    for (final id in _recentSearchCarparkIds) {
      final item = index[id];
      if (item != null) out.add(item);
    }
    return out;
  }

  List<MeteredStreetGroup> _recentMeteredGroupsForStartSearch() {
    if (_recentMeteredKeys.isEmpty || _startSearchMeteredGroups.isEmpty) {
      return const [];
    }
    final index = <String, MeteredStreetGroup>{
      for (final group in _startSearchMeteredGroups) group.key: group,
    };
    final out = <MeteredStreetGroup>[];
    for (final key in _recentMeteredKeys) {
      final item = index[key];
      if (item != null) out.add(item);
    }
    return out;
  }

  List<String> get _recentCombinedSearchEntriesForStartSearch {
    if (_recentCombinedKeys.isNotEmpty) return _recentCombinedKeys;
    return <String>[
      ..._recentSearchCarparkIds.map((id) => 'p:$id'),
      ..._recentMeteredKeys.map((key) => 'm:$key'),
    ];
  }

  List<parking.Carpark> _findMatchingStartCarparks(
    List<parking.Carpark> source,
    String query, {
    int limit = _NavigationScreenState._maxSearchResults,
  }) {
    final trimmed = query.trim();
    if (trimmed.isEmpty || limit <= 0) return const [];
    final normalized = trimmed.toLowerCase();

    bool matchesText(String? value) {
      if (value == null || value.isEmpty) return false;
      return value.toLowerCase().contains(normalized);
    }

    bool matchesOriginal(String? value) {
      if (value == null || value.isEmpty) return false;
      return value.contains(trimmed);
    }

    final filtered = <parking.Carpark>[];
    final seen = <String>{};
    for (final carpark in source) {
      if (!seen.add(carpark.id)) continue;
      final isMatch =
          matchesText(carpark.nameEn) ||
          matchesOriginal(carpark.nameTc) ||
          matchesOriginal(carpark.nameSc) ||
          matchesText(carpark.addressEn) ||
          matchesOriginal(carpark.addressTc) ||
          matchesOriginal(carpark.addressSc) ||
          matchesText(carpark.id) ||
          carpark.privateCarRates.any((rate) => matchesText(rate.remark));
      if (isMatch) {
        filtered.add(carpark);
        if (filtered.length >= limit) break;
      }
    }
    return filtered;
  }

  List<MeteredStreetGroup> _findMatchingStartMeteredGroups(
    List<MeteredStreetGroup> source,
    String query, {
    int limit = _NavigationScreenState._maxSearchResults,
  }) {
    final trimmed = query.trim();
    if (trimmed.isEmpty || limit <= 0) return const [];
    final normalized = trimmed.toLowerCase();

    bool matchesText(String? value) {
      if (value == null || value.isEmpty) return false;
      return value.toLowerCase().contains(normalized);
    }

    bool matchesOriginal(String? value) {
      if (value == null || value.isEmpty) return false;
      return value.contains(trimmed);
    }

    final filtered = <MeteredStreetGroup>[];
    final seen = <String>{};
    for (final group in source) {
      if (!seen.add(group.key)) continue;
      final isMatch =
          matchesText(group.streetEn) ||
          matchesOriginal(group.streetTc) ||
          matchesOriginal(group.streetSc) ||
          matchesText(group.sectionEn) ||
          matchesOriginal(group.sectionTc) ||
          matchesOriginal(group.sectionSc) ||
          matchesText(group.districtEn) ||
          matchesOriginal(group.districtTc) ||
          matchesOriginal(group.districtSc);
      if (isMatch) {
        filtered.add(group);
        if (filtered.length >= limit) break;
      }
    }
    return filtered;
  }

  String _startSearchCarparkDisplayName(parking.Carpark carpark) {
    switch (_startSearchAppLanguage) {
      case AppLanguage.english:
        return carpark.nameEn.isNotEmpty ? carpark.nameEn : carpark.id;
      case AppLanguage.traditionalChinese:
        if (carpark.nameTc.isNotEmpty) return carpark.nameTc;
      case AppLanguage.simplifiedChinese:
        if (carpark.nameSc.isNotEmpty) return carpark.nameSc;
    }
    if (carpark.nameEn.isNotEmpty) return carpark.nameEn;
    if (carpark.nameTc.isNotEmpty) return carpark.nameTc;
    if (carpark.nameSc.isNotEmpty) return carpark.nameSc;
    return carpark.id;
  }

  String? _startSearchAlternateCarparkName(parking.Carpark carpark) {
    if (_startSearchAppLanguage == AppLanguage.english) return null;
    final primary = _startSearchCarparkDisplayName(carpark);
    final candidates = <String>[
      if (_startSearchAppLanguage != AppLanguage.english) carpark.nameEn,
      if (_startSearchAppLanguage != AppLanguage.traditionalChinese)
        carpark.nameTc,
      if (_startSearchAppLanguage != AppLanguage.simplifiedChinese)
        carpark.nameSc,
    ];
    for (final value in candidates) {
      if (value.isEmpty || value == primary) continue;
      return value;
    }
    return null;
  }

  String _startSearchDisplayAddress(parking.Carpark carpark) {
    String primary;
    String secondary;
    switch (_startSearchAppLanguage) {
      case AppLanguage.english:
        primary = carpark.addressEn;
        secondary = '';
      case AppLanguage.traditionalChinese:
        primary = carpark.addressTc.isNotEmpty
            ? carpark.addressTc
            : carpark.addressSc;
        secondary = carpark.addressEn;
      case AppLanguage.simplifiedChinese:
        primary = carpark.addressSc.isNotEmpty
            ? carpark.addressSc
            : carpark.addressTc;
        secondary = carpark.addressEn;
    }
    if (primary.isNotEmpty && secondary.isNotEmpty && primary != secondary) {
      return '$primary / $secondary';
    }
    if (primary.isNotEmpty) return primary;
    if (secondary.isNotEmpty) return secondary;
    return '';
  }

  String _startSearchMeteredTitle(MeteredStreetGroup group) {
    switch (_startSearchAppLanguage) {
      case AppLanguage.english:
        return group.streetEn;
      case AppLanguage.traditionalChinese:
        return group.streetTc.isNotEmpty ? group.streetTc : group.streetSc;
      case AppLanguage.simplifiedChinese:
        return group.streetSc.isNotEmpty ? group.streetSc : group.streetTc;
    }
  }

  String _startSearchMeteredSubtitle(MeteredStreetGroup group) {
    switch (_startSearchAppLanguage) {
      case AppLanguage.english:
        return group.districtEn;
      case AppLanguage.traditionalChinese:
        return group.districtTc.isNotEmpty
            ? group.districtTc
            : group.districtSc;
      case AppLanguage.simplifiedChinese:
        return group.districtSc.isNotEmpty
            ? group.districtSc
            : group.districtTc;
    }
  }

  Color _startSearchStatusColor(String? openingStatus) {
    final normalized = openingStatus?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return widget.accentColor;
    if (normalized.contains('closed') || normalized.contains('full')) {
      return Colors.red.shade600;
    }
    if (normalized.contains('open')) return Colors.green.shade600;
    return widget.accentColor;
  }

  Future<void> _clearStartSearchRecents() async {
    _safeSetState(() {
      _recentSearchCarparkIds = const [];
      _recentCombinedKeys = _recentCombinedKeys
          .where((entry) => !entry.startsWith('p:'))
          .toList(growable: false);
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _NavigationScreenState._recentSearchPrefKey,
        const [],
      );
      await prefs.setStringList(
        _NavigationScreenState._recentCombinedPrefKey,
        _recentCombinedKeys,
      );
    } catch (_) {}
  }

  Future<void> _clearStartSearchMeteredRecents() async {
    _safeSetState(() {
      _recentMeteredKeys = const [];
      _recentCombinedKeys = _recentCombinedKeys
          .where((entry) => !entry.startsWith('m:'))
          .toList(growable: false);
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _NavigationScreenState._recentMeteredPrefKey,
        const [],
      );
      await prefs.setStringList(
        _NavigationScreenState._recentCombinedPrefKey,
        _recentCombinedKeys,
      );
    } catch (_) {}
  }

  Future<void> _clearStartSearchFavorites() async {
    _safeSetState(() => _favoriteCarparkIds = const []);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _NavigationScreenState._favoriteCarparkPrefKey,
        const [],
      );
    } catch (_) {}
  }

  Future<void> _toggleStartSearchFavorite(parking.Carpark carpark) async {
    final id = carpark.id;
    final exists = _favoriteCarparkIds.contains(id);
    final next = exists
        ? _favoriteCarparkIds
              .where((entry) => entry != id)
              .toList(growable: false)
        : [..._favoriteCarparkIds, id];
    _safeSetState(() => _favoriteCarparkIds = next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _NavigationScreenState._favoriteCarparkPrefKey,
        next,
      );
    } catch (_) {}
  }

  String _displayNameForSearchLocation(GeocodingResult location) {
    final title = _prefersChineseStartSearch
        ? (location.nameZh ?? location.displayName)
        : (location.nameEn ?? location.displayName);
    return title.isNotEmpty ? title : location.displayName;
  }

  LatLng? _pointFromSearchSelection(CarparkSearchSelection selection) {
    final location = selection.location;
    if (location != null) {
      return LatLng(location.latitude, location.longitude);
    }
    final carpark = selection.carpark;
    if (carpark != null) {
      return LatLng(carpark.latitude, carpark.longitude);
    }
    final meteredGroup = selection.meteredGroup;
    if (meteredGroup != null) {
      return meteredGroup.center;
    }
    return null;
  }

  void _rememberSearchSelection(CarparkSearchSelection selection) {
    final location = selection.location;
    if (location != null) {
      _recordRecentStartLocation(location);
      return;
    }
    final carpark = selection.carpark;
    if (carpark != null) {
      _rememberStartSearchCarpark(carpark);
      return;
    }
    final meteredGroup = selection.meteredGroup;
    if (meteredGroup != null) {
      _rememberStartSearchMetered(meteredGroup);
    }
  }

  String _destinationNameFromSelection(CarparkSearchSelection selection) {
    final location = selection.location;
    if (location != null) {
      return _displayNameForSearchLocation(location);
    }
    final carpark = selection.carpark;
    if (carpark != null) {
      return _startSearchCarparkDisplayName(carpark);
    }
    final meteredGroup = selection.meteredGroup;
    if (meteredGroup != null) {
      return _startSearchMeteredTitle(meteredGroup);
    }
    return _formatLatLng(_destination);
  }

  String _destinationAddressFromSelection(CarparkSearchSelection selection) {
    final location = selection.location;
    if (location != null) {
      return location.displayName;
    }
    final carpark = selection.carpark;
    if (carpark != null) {
      return _startSearchDisplayAddress(carpark);
    }
    final meteredGroup = selection.meteredGroup;
    if (meteredGroup != null) {
      return _startSearchMeteredSubtitle(meteredGroup);
    }
    return '';
  }

  Future<CarparkSearchSelection?> _showNavigationLocationSearch({
    required String searchFieldLabelText,
    required List<CarparkSearchQuickAction> quickActions,
  }) {
    return showSearch<CarparkSearchSelection?>(
      context: context,
      delegate: CarparkSearchDelegate(
        allCarparks: _startSearchCarparks,
        meteredGroups: _startSearchMeteredGroups,
        recentMeteredGroups: _recentMeteredGroupsForStartSearch(),
        recentCombinedKeys: _recentCombinedSearchEntriesForStartSearch,
        savedPlaces: _savedPlaces,
        recentCarparks: _recentSearchCarparksForStartSearch(),
        searchCarparks: (query) =>
            _findMatchingStartCarparks(_startSearchCarparks, query),
        searchMetered: (query) =>
            _findMatchingStartMeteredGroups(_startSearchMeteredGroups, query),
        titleBuilder: _startSearchCarparkDisplayName,
        subtitleBuilder: (carpark) =>
            _startSearchAlternateCarparkName(carpark) ??
            _startSearchDisplayAddress(carpark),
        meteredTitleBuilder: _startSearchMeteredTitle,
        meteredSubtitleBuilder: _startSearchMeteredSubtitle,
        statusColorBuilder: _startSearchStatusColor,
        searchFieldLabelText: searchFieldLabelText,
        appBarColor: widget.appBarColor,
        appBarForeground: widget.appBarForeground,
        accentColor: widget.accentColor,
        backgroundColor: widget.backgroundColor,
        geocodingService: _startGeocodingService,
        appLanguage: _startSearchAppLanguage,
        forceLightSearch: true,
        onToggleFavorite: _toggleStartSearchFavorite,
        onClearRecents: _clearStartSearchRecents,
        onClearMeteredRecents: _clearStartSearchMeteredRecents,
        onClearFavorites: _clearStartSearchFavorites,
        onAddSavedPlace: _addSavedPlaceFromSearch,
        onRemoveSavedPlace: _removeSavedPlaceFromSearch,
        quickActions: quickActions,
      ),
    );
  }

  Future<void> _showStartPicker() async {
    if (!mounted) return;
    await _restoreStartSearchData();
    await _ensureStartSearchDatasets();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final result = await _showNavigationLocationSearch(
      searchFieldLabelText: l10n.choose_start_point,
      quickActions: [
        CarparkSearchQuickAction(
          icon: Icons.my_location,
          title: l10n.use_current_location,
          selection: const CarparkSearchSelection.useCurrentLocation(),
        ),
        CarparkSearchQuickAction(
          icon: Icons.map,
          title: l10n.pick_on_map,
          subtitle: l10n.move_and_zoom_map_under_pin,
          selection: const CarparkSearchSelection.pickOnMap(),
        ),
      ],
    );
    if (!mounted || result == null) return;

    switch (result.action) {
      case CarparkSearchAction.useCurrentLocation:
        _safeSetState(() {
          _manualOrigin = null;
          _pickingStart = false;
          _pickingDestination = false;
        });
        _fetchRoute();
        break;
      case CarparkSearchAction.pickOnMap:
        _safeSetState(() {
          _pickingStart = true;
          _pickingDestination = false;
        });
        break;
      case CarparkSearchAction.select:
        final point = _pointFromSearchSelection(result);
        if (point == null) return;
        _safeSetState(() {
          _manualOrigin = point;
          _origin = point;
          _pickingStart = false;
          _pickingDestination = false;
        });
        _rememberSearchSelection(result);
        _fetchRoute();
        break;
    }
  }

  Future<void> _showDestinationPicker() async {
    if (!mounted) return;
    await _restoreStartSearchData();
    await _ensureStartSearchDatasets();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final useCurrentLocationTitle = l10n.use_current_location;
    final result = await _showNavigationLocationSearch(
      searchFieldLabelText: l10n.choose_destination,
      quickActions: [
        CarparkSearchQuickAction(
          icon: Icons.my_location,
          title: l10n.use_current_location,
          selection: const CarparkSearchSelection.useCurrentLocation(),
        ),
        CarparkSearchQuickAction(
          icon: Icons.map,
          title: l10n.pick_on_map,
          subtitle: l10n.tap_map_to_set_destination_point,
          selection: const CarparkSearchSelection.pickOnMap(),
        ),
      ],
    );
    if (!mounted || result == null) return;

    switch (result.action) {
      case CarparkSearchAction.useCurrentLocation:
        try {
          final current = await routing.getCurrentLatLng();
          if (!mounted) return;
          _setDestination(
            point: current,
            name: useCurrentLocationTitle,
            address: _formatLatLng(current),
            carpark: null,
          );
        } catch (_) {}
        break;
      case CarparkSearchAction.pickOnMap:
        _safeSetState(() {
          _pickingStart = false;
          _pickingDestination = true;
        });
        break;
      case CarparkSearchAction.select:
        final point = _pointFromSearchSelection(result);
        if (point == null) return;
        _rememberSearchSelection(result);
        _setDestination(
          point: point,
          name: _destinationNameFromSelection(result),
          address: _destinationAddressFromSelection(result),
          carpark: result.carpark,
        );
        break;
    }
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
                  ListTile(title: Text(l10n.toll_pricing_time)),
                  RadioListTile<TollTimeMode>(
                    value: TollTimeMode.now,
                    groupValue: _tollTimeMode,
                    title: Text(l10n.use_current_time),
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
                    title: Text(l10n.set_departure_time),
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
                    title: Text(l10n.set_arrival_time_estimated),
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
