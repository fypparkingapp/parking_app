part of 'appmain.dart';

extension _HomeScreenSearch on _HomeScreenState {
  Future<void> _openCarparkSearch(MapThemeConfig themeConfig) async {
    _clearPendingMapSelection();
    final l10n = AppLocalizations.of(context)!;
    final selection = await showSearch<CarparkSearchSelection?>(
      context: context,
      delegate: CarparkSearchDelegate(
        allCarparks: _allCarparks,
        meteredGroups: _meteredGroups,
        recentMeteredGroups: _recentMeteredGroups(),
        onClearMeteredRecents: () => _clearRecentMeteredSearches(),
        savedPlaces: _savedPlaces,
        recentCarparks: _recentSearchCarparks,
        recentCombinedKeys: _recentCombinedSearchEntries,
        searchCarparks: (query) => _findMatchingCarparks(
          _allCarparks,
          query,
          limit: _HomeScreenState._maxSearchResults,
        ),
        searchMetered: (query) => _findMatchingMeteredGroups(
          _meteredGroups,
          query,
          limit: _HomeScreenState._maxSearchResults,
        ),
        titleBuilder: (carpark) => _carparkDisplayName(carpark),
        subtitleBuilder: (carpark) =>
            _alternateCarparkName(carpark) ?? _displayAddress(carpark),
        meteredTitleBuilder: (group) => _meteredStreetLabel(group),
        meteredSubtitleBuilder: (group) => _meteredDistrictLabel(group),
        statusColorBuilder: (status) =>
            _resolveOpeningStatusColor(status, themeConfig.accentColor),
        searchFieldLabelText: l10n.search_parking,
        appBarColor: themeConfig.appBarColor,
        appBarForeground: themeConfig.appBarForeground,
        accentColor: themeConfig.accentColor,
        backgroundColor: themeConfig.backgroundColor,
        forceLightSearch: _selectedTheme == 'Standard',
        appLanguage: _language,
        onClearRecents: () => _clearRecentSearches(),
        onClearFavorites: () => _clearFavoriteCarparks(),
        onToggleFavorite: (carpark) => _toggleFavoriteCarpark(carpark),
        onAddSavedPlace: (place) => _addSavedPlace(place),
        onRemoveSavedPlace: (place) => _removeSavedPlace(place),
        initialQuery: _searchController.text,
        geocodingService: _geocodingService,
      ),
    );
    if (!mounted || selection == null) return;
    final location = selection.location;
    if (location != null) {
      await _handleLocationSelection(location);
      return;
    }
    final meteredGroup = selection.meteredGroup;
    if (meteredGroup != null) {
      unawaited(_rememberRecentMeteredSearch(meteredGroup));
      if (_showMap) {
        final zoom = math.max(_currentZoom, 15.0);
        _mapController.move(meteredGroup.center, zoom);
        _safeSetState(() => _currentZoom = zoom);
      }
      _showMeteredGroupSheet(meteredGroup);
      return;
    }
    final carpark = selection.carpark;
    if (carpark != null) {
      _handleSuggestionSelection(
        carpark,
        showDetails: selection.showDetails,
        setAsDestination: selection.setAsDestination,
      );
    }
  }

  List<Carpark> _findMatchingCarparks(
    List<Carpark> source,
    String query, {
    int limit = _HomeScreenState._maxSearchResults,
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

    final filtered = <Carpark>[];
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
        if (filtered.length >= limit) {
          break;
        }
      }
    }
    return filtered;
  }

  List<MeteredStreetGroup> _findMatchingMeteredGroups(
    List<MeteredStreetGroup> source,
    String query, {
    int limit = _HomeScreenState._maxSearchResults,
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
        if (filtered.length >= limit) {
          break;
        }
      }
    }
    return filtered;
  }

  List<MeteredStreetGroup> _recentMeteredGroups() {
    if (_recentMeteredKeys.isEmpty || _meteredGroups.isEmpty) return const [];
    final map = <String, MeteredStreetGroup>{
      for (final group in _meteredGroups) group.key: group,
    };
    final out = <MeteredStreetGroup>[];
    for (final key in _recentMeteredKeys) {
      final group = map[key];
      if (group != null) out.add(group);
    }
    return out;
  }

  void _clearSearchSelection() {
    _searchController.clear();
    _safeSetState(() {
      _routeDestination = null;
      _searchLocationMarker = null;
      _carparks = List<Carpark>.from(_allCarparks);
    });
  }

  void _handleSuggestionSelection(
    Carpark carpark, {
    bool showDetails = false,
    bool setAsDestination = true,
  }) {
    final displayName = _carparkDisplayName(carpark);
    _searchController.value = TextEditingValue(
      text: displayName,
      selection: TextSelection.collapsed(offset: displayName.length),
    );
    _safeSetState(() {
      _routeDestination = setAsDestination ? carpark : null;
      _searchLocationMarker = null;
      _carparks = List<Carpark>.from(_allCarparks);
    });
    unawaited(_rememberRecentSearch(carpark));
    _centerMapOnCarpark(carpark);
    if (showDetails) {
      _showCarparkDetails(carpark);
    }
  }

  Future<void> _handleLocationSelection(GeocodingResult location) async {
    final displayName = switch (_language) {
      AppLanguage.english => location.nameEn ?? location.displayName,
      AppLanguage.traditionalChinese => location.nameZh ?? location.displayName,
      AppLanguage.simplifiedChinese => location.nameZh ?? location.displayName,
    };
    _searchController.value = TextEditingValue(
      text: displayName,
      selection: TextSelection.collapsed(offset: displayName.length),
    );
    _safeSetState(() {
      _routeDestination = null;
      _searchLocationMarker = LatLng(location.latitude, location.longitude);
      _carparks = List<Carpark>.from(_allCarparks);
    });
    await _animateCamera(_searchLocationMarker!, zoom: 15.0);
    await _resetMapRotation();
    _prefetchNearbyCarparkImages(force: true);
  }

  List<Carpark> get _recentSearchCarparks {
    if (_recentSearchCarparkIds.isEmpty || _allCarparks.isEmpty) {
      return const [];
    }
    final index = <String, Carpark>{for (final c in _allCarparks) c.id: c};
    final out = <Carpark>[];
    for (final id in _recentSearchCarparkIds) {
      final c = index[id];
      if (c != null) out.add(c);
    }
    return out;
  }

  List<String> get _recentCombinedSearchEntries {
    if (_recentCombinedKeys.isNotEmpty) return _recentCombinedKeys;
    return <String>[
      ..._recentSearchCarparkIds.map((id) => 'p:$id'),
      ..._recentMeteredKeys.map((key) => 'm:$key'),
    ];
  }

  String _carparkDisplayName(Carpark carpark) {
    switch (_language) {
      case AppLanguage.english:
        return carpark.nameEn.isNotEmpty ? carpark.nameEn : carpark.id;
      case AppLanguage.traditionalChinese:
        if (carpark.nameTc.isNotEmpty) return carpark.nameTc;
        break;
      case AppLanguage.simplifiedChinese:
        if (carpark.nameSc.isNotEmpty) return carpark.nameSc;
        break;
    }
    if (carpark.nameEn.isNotEmpty) return carpark.nameEn;
    if (carpark.nameTc.isNotEmpty) return carpark.nameTc;
    if (carpark.nameSc.isNotEmpty) return carpark.nameSc;
    return carpark.id;
  }

  String? _alternateCarparkName(Carpark carpark) {
    if (_language == AppLanguage.english) {
      return null;
    }
    final primary = _carparkDisplayName(carpark);
    final candidates = <String>[
      if (_language != AppLanguage.english) carpark.nameEn,
      if (_language != AppLanguage.traditionalChinese) carpark.nameTc,
      if (_language != AppLanguage.simplifiedChinese) carpark.nameSc,
    ];
    for (final candidate in candidates) {
      if (candidate.isEmpty || candidate == primary) continue;
      return candidate;
    }
    return null;
  }

  String _displayAddress(Carpark carpark) {
    String primary;
    String secondary;
    switch (_language) {
      case AppLanguage.english:
        primary = carpark.addressEn;
        secondary = '';
        break;
      case AppLanguage.traditionalChinese:
        primary = carpark.addressTc.isNotEmpty
            ? carpark.addressTc
            : carpark.addressSc;
        secondary = carpark.addressEn;
        break;
      case AppLanguage.simplifiedChinese:
        primary = carpark.addressSc.isNotEmpty
            ? carpark.addressSc
            : carpark.addressTc;
        secondary = carpark.addressEn;
        break;
    }
    if (primary.isNotEmpty && secondary.isNotEmpty && primary != secondary) {
      return '$primary / $secondary';
    }
    if (primary.isNotEmpty) return primary;
    if (secondary.isNotEmpty) return secondary;
    return '';
  }

  Widget _buildBottomSearchBar(MapThemeConfig themeConfig) {
    final theme = Theme.of(context);
    final controllerText = _searchController.text.trim();
    final resolvedText = controllerText.isNotEmpty
        ? controllerText
        : (_routeDestination != null
              ? _carparkDisplayName(_routeDestination!)
              : '');
    final hasSelection = resolvedText.isNotEmpty;
    final label = hasSelection
        ? resolvedText
        : AppLocalizations.of(context)!.search_parking;
    final iconColor = const Color(0xFF00008B);
    final textColor = Colors.black87;
    final priceColor = textColor.withValues(alpha: 0.85);
    final priceLabel = _routeDestination != null
        ? _formatHourlyPriceShort(_routeDestination!)
        : null;

    final smartEnabled =
        _resolveSmartNavigationDestination() != null &&
        !_smartNavigationRunning;
    final smartLabel = _smartNavigationButtonLabel();
    final accent = themeConfig.accentColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Material(
                color: Colors.white,
                elevation: 6,
                borderRadius: BorderRadius.circular(23),
                child: SizedBox(
                  height: 48,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(23),
                            onTap: () =>
                                unawaited(_openCarparkSearch(themeConfig)),
                            child: Row(
                              children: [
                                Icon(Icons.search, color: iconColor),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: hasSelection
                                          ? textColor
                                          : textColor.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ),
                                if (hasSelection && priceLabel != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    priceLabel,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: priceColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (hasSelection)
                          IconButton(
                            tooltip: AppLocalizations.of(context)!.clear,
                            constraints: const BoxConstraints.tightFor(
                              width: 40,
                              height: 40,
                            ),
                            padding: EdgeInsets.zero,
                            iconSize: 20,
                            icon: Icon(Icons.close, color: iconColor),
                            onPressed: () => _clearSearchSelection(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Tooltip(
              message: _smartNavigationTooltip(),
              child: SizedBox(
                height: 48,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: accent.withValues(alpha: 0.35),
                    disabledForegroundColor: Colors.white.withValues(
                      alpha: 0.9,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: smartEnabled
                      ? () => unawaited(_startSmartNavigation())
                      : null,
                  icon: _smartNavigationRunning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.assistant_navigation, size: 18),
                  label: Text(
                    smartLabel,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: accent.withValues(alpha: 0.18)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Text(
                      _smartNavigationPreferenceLabel(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    for (final preference
                        in SmartNavigationPreference.values) ...[
                      ChoiceChip(
                        label: Text(_smartNavigationPreferenceText(preference)),
                        selected: preference == _smartNavigationPreference,
                        showCheckmark: false,
                        selectedColor: accent.withValues(alpha: 0.14),
                        backgroundColor: Colors.grey.shade100,
                        side: BorderSide(
                          color: preference == _smartNavigationPreference
                              ? accent.withValues(alpha: 0.6)
                              : Colors.black12,
                        ),
                        labelStyle: theme.textTheme.labelMedium?.copyWith(
                          color: preference == _smartNavigationPreference
                              ? accent
                              : Colors.black87,
                          fontWeight: FontWeight.w700,
                        ),
                        onSelected: (_) {
                          if (preference == _smartNavigationPreference) return;
                          _safeSetState(() {
                            _smartNavigationPreference = preference;
                          });
                          unawaited(_saveSmartNavigationPreference(preference));
                        },
                      ),
                      if (preference != SmartNavigationPreference.values.last)
                        const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHomeFunctionRows(
    MapThemeConfig themeConfig, {
    required String nearbyLabel,
    required VoidCallback onNearbyTap,
    required String parkingLabel,
    required VoidCallback onParkingTap,
    required String meteredLabel,
    required VoidCallback onMeteredTap,
  }) {
    final useDarkTheme = _selectedTheme == 'Dark';
    final background = useDarkTheme ? const Color(0xFF1B1F24) : Colors.white;
    final shadowColor = Colors.black.withValues(alpha: 0.18);
    final textColor = useDarkTheme ? Colors.white : Colors.black87;
    final accent = themeConfig.accentColor;

    return Material(
      color: background,
      elevation: 6,
      shadowColor: shadowColor,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: _buildHomeFunctionRow(
          totalSlots: /*5*/ 4,
          children: [
            _buildHomeFunctionIcon(
              icon: Icons.near_me,
              label: nearbyLabel,
              accent: accent,
              textColor: textColor,
              onTap: onNearbyTap,
            ),
            _buildHomeFunctionIcon(
              icon: Icons.local_parking,
              label: parkingLabel,
              accent: accent,
              textColor: textColor,
              onTap: onParkingTap,
            ),
            _buildHomeFunctionIcon(
              icon: Icons.local_parking_outlined,
              label: meteredLabel,
              accent: accent,
              textColor: textColor,
              onTap: onMeteredTap,
            ),/*
            _buildHomeFunctionIcon(
              icon: Icons.route,
              label: _routePriceLabel(),
              accent: accent,
              textColor: textColor,
              onTap: () => _handleTripPriceTap(themeConfig),
            ),*/
            _buildHomeFunctionIcon(
              icon: Icons.toll,
              label: _tollTimeLabel(),
              accent: accent,
              textColor: textColor,
              onTap: () => _handleTollWithTimeTap(themeConfig),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeFunctionRow({
    required List<Widget> children,
    required int totalSlots,
  }) {
    final slots = List<Widget>.from(children);
    while (slots.length < totalSlots) {
      slots.add(const SizedBox.shrink());
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final slot in slots) Expanded(child: slot)],
    );
  }

  Widget _buildHomeFunctionIcon({
    required IconData icon,
    required String label,
    required Color accent,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _routePriceLabel() {
    if (_language == AppLanguage.english) return 'Trip price';
    return '行程價錢';
  }

  String _tollTimeLabel() {
    if (_language == AppLanguage.english) return 'Toll fees';
    return '過路費';
  }

  Future<Carpark?> _ensureRouteDestination(MapThemeConfig themeConfig) async {
    if (_routeDestination != null) return _routeDestination;
    await _openCarparkSearch(themeConfig);
    return _routeDestination;
  }

  Future<void> _handleTripPriceTap(MapThemeConfig themeConfig) async {
    final carpark = await _ensureRouteDestination(themeConfig);
    if (carpark == null) return;
    _openNavigation(carpark);
  }

  Future<void> _handleTollWithTimeTap(MapThemeConfig themeConfig) async {
    if (!mounted) return;
    final themeConfig = _mapThemes[_selectedTheme]!;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TollFeePage(
          themeConfig: themeConfig,
          useDarkTheme: _selectedTheme == 'Dark',
        ),
      ),
    );
  }

  // Calculate distance between two points in degrees (approximation)
}
