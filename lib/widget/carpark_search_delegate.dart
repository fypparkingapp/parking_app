import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parking_app/manager/language_manager.dart';
import 'package:parking_app/network/metered_parking_service.dart';
import 'package:parking_app/network/geocoding_service.dart';
import 'package:parking_app/network/parking_api.dart';
import 'package:parking_app/l10n/app_localizations.dart';
import 'package:parking_app/model/saved_place.dart';

part 'carpark_search_sections.dart';

typedef CarparkTextBuilder = String Function(Carpark carpark);
typedef CarparkSearchFn = List<Carpark> Function(String query);
typedef MeteredTextBuilder = String Function(MeteredStreetGroup group);
typedef MeteredSearchFn = List<MeteredStreetGroup> Function(String query);

enum SearchFilter { all, parking, metered }

enum CarparkSearchAction { select, useCurrentLocation, pickOnMap }

@immutable
class CarparkSearchSelection {
  const CarparkSearchSelection({
    this.carpark,
    this.location,
    this.meteredGroup,
    required this.showDetails,
    this.setAsDestination = true,
    this.action = CarparkSearchAction.select,
  }) : assert(
         action != CarparkSearchAction.select ||
             carpark != null ||
             location != null ||
             meteredGroup != null,
       );

  const CarparkSearchSelection.carpark({
    required Carpark carpark,
    required bool showDetails,
    bool setAsDestination = true,
  }) : this(
         carpark: carpark,
         location: null,
         showDetails: showDetails,
         setAsDestination: setAsDestination,
       );

  const CarparkSearchSelection.location({required this.location})
    : carpark = null,
      meteredGroup = null,
      showDetails = false,
      setAsDestination = false,
      action = CarparkSearchAction.select;

  const CarparkSearchSelection.metered({
    required MeteredStreetGroup this.meteredGroup,
  }) : carpark = null,
       location = null,
       showDetails = false,
       setAsDestination = false,
       action = CarparkSearchAction.select;

  const CarparkSearchSelection.useCurrentLocation()
    : carpark = null,
      location = null,
      meteredGroup = null,
      showDetails = false,
      setAsDestination = false,
      action = CarparkSearchAction.useCurrentLocation;

  const CarparkSearchSelection.pickOnMap()
    : carpark = null,
      location = null,
      meteredGroup = null,
      showDetails = false,
      setAsDestination = false,
      action = CarparkSearchAction.pickOnMap;

  final Carpark? carpark;
  final GeocodingResult? location;
  final MeteredStreetGroup? meteredGroup;
  final bool showDetails;
  final bool setAsDestination;
  final CarparkSearchAction action;
}

@immutable
class CarparkSearchQuickAction {
  const CarparkSearchQuickAction({
    required this.icon,
    required this.title,
    required this.selection,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final CarparkSearchSelection selection;
}

class CarparkSearchDelegate extends SearchDelegate<CarparkSearchSelection?> {
  CarparkSearchDelegate({
    required this.allCarparks,
    required this.meteredGroups,
    required this.recentMeteredGroups,
    required List<String> recentCombinedKeys,
    required List<SavedPlace> savedPlaces,
    required List<Carpark> recentCarparks,
    required this.searchCarparks,
    required this.searchMetered,
    required this.titleBuilder,
    required this.subtitleBuilder,
    required this.meteredTitleBuilder,
    required this.meteredSubtitleBuilder,
    required this.statusColorBuilder,
    required this.searchFieldLabelText,
    required this.appBarColor,
    required this.appBarForeground,
    required this.accentColor,
    required this.backgroundColor,
    required this.geocodingService,
    required this.appLanguage,
    this.forceLightSearch = false,
    required this.onToggleFavorite,
    required this.onAddSavedPlace,
    required this.onRemoveSavedPlace,
    this.onClearRecents,
    this.onClearFavorites,
    this.onClearMeteredRecents,
    this.quickActions = const [],
    String? initialQuery,
  }) : _recentCarparks = List<Carpark>.from(recentCarparks),
       _savedPlaces = List<SavedPlace>.from(savedPlaces),
       _recentCombinedKeys = List<String>.from(recentCombinedKeys),
       _recentMeteredGroups = List<MeteredStreetGroup>.from(
         recentMeteredGroups,
       ) {
    query = initialQuery?.trim() ?? '';
  }

  final List<Carpark> allCarparks;
  final List<MeteredStreetGroup> meteredGroups;
  final List<MeteredStreetGroup> recentMeteredGroups;
  final CarparkSearchFn searchCarparks;
  final MeteredSearchFn searchMetered;
  final CarparkTextBuilder titleBuilder;
  final CarparkTextBuilder subtitleBuilder;
  final MeteredTextBuilder meteredTitleBuilder;
  final MeteredTextBuilder meteredSubtitleBuilder;
  final Color Function(String? openingStatus) statusColorBuilder;
  final String searchFieldLabelText;
  final Color appBarColor;
  final Color appBarForeground;
  final Color accentColor;
  final Color backgroundColor;
  final GeocodingService geocodingService;
  final AppLanguage appLanguage;
  final bool forceLightSearch;
  final void Function(Carpark carpark) onToggleFavorite;
  final Future<void> Function(SavedPlace place) onAddSavedPlace;
  final Future<void> Function(SavedPlace place) onRemoveSavedPlace;
  final Future<void> Function()? onClearRecents;
  final Future<void> Function()? onClearFavorites;
  final Future<void> Function()? onClearMeteredRecents;
  final List<CarparkSearchQuickAction> quickActions;
  final ValueNotifier<int> _refreshSignal = ValueNotifier<int>(0);
  static const int _maxNearbyResults = 20;

  List<Carpark> _recentCarparks;
  List<SavedPlace> _savedPlaces;
  List<String> _recentCombinedKeys;
  List<MeteredStreetGroup> _recentMeteredGroups;
  String _lastGeocodeQuery = '';
  Future<List<GeocodingResult>>? _geocodeResultsFuture;
  Timer? _debounceTimer;
  String _debouncedQuery = '';
  String _lastRawQuery = '';
  static const Duration _searchDebounce = Duration(milliseconds: 400);
  SearchFilter _filter = SearchFilter.all;
  late final bool _useDarkSearch =
      !forceLightSearch &&
      ThemeData.estimateBrightnessForColor(appBarColor) == Brightness.dark;
  late final bool _useDarkSurface =
      ThemeData.estimateBrightnessForColor(backgroundColor) == Brightness.dark;
  late final String _geocodingFallbackLabel = appLanguage.prefersChinese
      ? '香港'
      : 'Hong Kong';

  @override
  String get searchFieldLabel => searchFieldLabelText;

  @override
  ThemeData appBarTheme(BuildContext context) {
    final base = Theme.of(context);
    final barColor = _useDarkSearch ? appBarColor : backgroundColor;
    final fieldFill = _useDarkSearch
        ? Colors.white.withValues(alpha: 0.16)
        : base.colorScheme.surface.withValues(alpha: 0.98);
    final outlineColor = _useDarkSearch
        ? Colors.white.withValues(alpha: 0.22)
        : base.colorScheme.outline.withValues(alpha: 0.2);

    return base.copyWith(
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: barColor,
        foregroundColor: _useDarkSearch
            ? appBarForeground
            : base.colorScheme.onSurface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: _useDarkSearch
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: fieldFill,
        hintStyle: TextStyle(color: _useDarkSearch ? Colors.white70 : null),
        prefixIconColor: _useDarkSearch ? Colors.white70 : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: outlineColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: outlineColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: accentColor, width: 1.2),
        ),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: _useDarkSurface ? Colors.white : null,
        displayColor: _useDarkSurface ? Colors.white : null,
      ),
      listTileTheme: base.listTileTheme.copyWith(
        textColor: _useDarkSurface ? Colors.white : null,
        iconColor: _useDarkSurface ? Colors.white70 : null,
        subtitleTextStyle: base.textTheme.bodySmall?.copyWith(
          color: _useDarkSurface ? Colors.white70 : null,
        ),
      ),
      textSelectionTheme: base.textSelectionTheme.copyWith(
        cursorColor: accentColor,
        selectionColor: accentColor.withValues(alpha: 0.25),
        selectionHandleColor: accentColor,
      ),
    );
  }

  @override
  TextStyle? get searchFieldStyle =>
      _useDarkSearch ? const TextStyle(color: Colors.white) : null;

  @override
  List<Widget>? buildActions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasQuery = query.trim().isNotEmpty;
    return [
      if (hasQuery)
        IconButton(
          tooltip: l10n.clear,
          icon: const Icon(Icons.close),
          onPressed: () {
            FocusManager.instance.primaryFocus?.unfocus();
            query = '';
            _refreshSignal.value++;
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _refreshSignal,
      builder: (context, _, child) => _buildBody(context),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _refreshSignal,
      builder: (context, _, child) => _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rawTrimmed = query.trim();
    _scheduleDebouncedSearch(context, rawTrimmed);
    final trimmed = _debouncedQuery;
    final isQueryMode = trimmed.isNotEmpty;
    final showParking = _filter != SearchFilter.metered;
    final showMetered = _filter != SearchFilter.parking;
    final savedSection = showParking ? _buildSavedPlacesSection(context) : null;
    final filterRow = _buildFilterRow(context);
    final quickActionSection = isQueryMode
        ? const <Widget>[]
        : _buildQuickActionSection(context);

    if (isQueryMode) {
      final meteredItems = showMetered ? searchMetered(trimmed) : const [];
      if (!showParking) {
        if (meteredItems.isEmpty) {
          return _buildResultList(
            context,
            filterRow: filterRow,
            rows: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.no_matching_car_parks,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          );
        }
        return _buildResultList(
          context,
          filterRow: filterRow,
          rows: meteredItems
              .map((group) => _buildMeteredTile(context, group))
              .toList(),
        );
      }

      final items = searchCarparks(trimmed);
      return FutureBuilder<List<GeocodingResult>>(
        future: _getGeocodeResults(trimmed),
        builder: (context, snapshot) {
          final locations = snapshot.data ?? const [];
          final filteredLocations = locations;
          final hasLocations = locations.isNotEmpty;
          final hasFilteredLocations = filteredLocations.isNotEmpty;
          final hasMetered = meteredItems.isNotEmpty;

          if (items.isEmpty && !hasFilteredLocations && !hasMetered) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildResultList(
                context,
                savedSection: savedSection,
                filterRow: filterRow,
                rows: const [
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              );
            }
            if (kDebugMode && !hasLocations) {
              debugPrint('Geocode miss for "$trimmed".');
            }
            return _buildResultList(
              context,
              savedSection: savedSection,
              filterRow: filterRow,
              rows: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _emptySearchResultsLabel(l10n),
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            );
          }

          if (items.isEmpty && hasFilteredLocations && !hasMetered) {
            final primaryLocation = filteredLocations.first;
            final nearby = _nearestCarparks(primaryLocation);
            if (kDebugMode) {
              debugPrint(
                'Nearby from "${primaryLocation.displayName}": ${nearby.length} results.',
              );
            }
            if (nearby.isEmpty) {
              final rows = _buildLocationSections(context, filteredLocations);
              return _buildResultList(
                context,
                savedSection: savedSection,
                filterRow: filterRow,
                rows: rows,
              );
            }

            final rows = <Widget>[
              ..._buildLocationSections(context, filteredLocations),
              _buildLocationHeader(context, primaryLocation),
              ...nearby.map(
                (carpark) => _buildCarparkTile(
                  context,
                  carpark,
                  leadingIcon: Icons.local_parking,
                  showDetails: false,
                ),
              ),
            ];
            return _buildResultList(
              context,
              savedSection: savedSection,
              filterRow: filterRow,
              rows: rows,
            );
          }

          final rows = <Widget>[
            ..._buildLocationSections(context, filteredLocations),
            if (items.isNotEmpty)
              _buildSectionHeader(context, title: l10n.carpark, onClear: null),
            ...items.map(
              (carpark) => _buildCarparkTile(
                context,
                carpark,
                leadingIcon: Icons.local_parking,
                showDetails: false,
              ),
            ),
            if (hasMetered)
              _buildSectionHeader(
                context,
                title: l10n.metered_parking,
                onClear: null,
              ),
            if (hasMetered)
              ...meteredItems.map((group) => _buildMeteredTile(context, group)),
          ];
          return _buildResultList(
            context,
            savedSection: savedSection,
            filterRow: filterRow,
            rows: rows,
          );
        },
      );
    }

    final sections = <_SearchSection>[
      if (_recentCarparks.isNotEmpty)
        _SearchSection(
          title: l10n.recent,
          items: _recentCarparks,
          leadingIcon: Icons.history,
          onClear:
              _recentCarparks.isEmpty &&
                  (!showMetered || _recentMeteredGroups.isEmpty)
              ? null
              : () {
                  _recentCarparks = const [];
                  _recentCombinedKeys = _recentCombinedKeys
                      .where((entry) => !entry.startsWith('p:'))
                      .toList(growable: false);
                  onClearRecents?.call();
                  if (showMetered && _recentMeteredGroups.isNotEmpty) {
                    _recentMeteredGroups = const [];
                    _recentCombinedKeys = _recentCombinedKeys
                        .where((entry) => !entry.startsWith('m:'))
                        .toList(growable: false);
                    onClearMeteredRecents?.call();
                  }
                  _refreshSignal.value++;
                  showSuggestions(context);
                },
        ),
    ];

    if (!showParking) {
      if (_recentMeteredGroups.isEmpty) {
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            ...quickActionSection,
            filterRow,
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.no_recent_searches,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        );
      }
      final rows = <Widget>[
        _buildSectionHeader(
          context,
          title: l10n.recent,
          onClear: _recentMeteredGroups.isEmpty
              ? null
              : () {
                  _recentMeteredGroups = const [];
                  _recentCombinedKeys = _recentCombinedKeys
                      .where((entry) => !entry.startsWith('m:'))
                      .toList(growable: false);
                  onClearMeteredRecents?.call();
                  _refreshSignal.value++;
                  showSuggestions(context);
                },
        ),
        ..._recentMeteredGroups.map(
          (group) => _buildMeteredTile(
            context,
            group,
            leadingIcon: Icons.history,
            showSaveButton: true,
          ),
        ),
      ];
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ...quickActionSection,
          filterRow,
          const Divider(height: 1),
          ..._withDividers(rows),
        ],
      );
    }

    final hasCarparkRecents = sections.isNotEmpty;
    final hasMeteredRecents = showMetered && _recentMeteredGroups.isNotEmpty;
    if (!hasCarparkRecents && !hasMeteredRecents) {
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (savedSection != null) savedSection,
          const Divider(height: 1),
          ...quickActionSection,
          filterRow,
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.no_recent_searches,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    final rows = <Widget>[
      _buildSectionHeader(
        context,
        title: l10n.recent,
        onClear: () {
          if (hasCarparkRecents) {
            _recentCarparks = const [];
            _recentCombinedKeys = _recentCombinedKeys
                .where((entry) => !entry.startsWith('p:'))
                .toList(growable: false);
            onClearRecents?.call();
          }
          if (hasMeteredRecents) {
            _recentMeteredGroups = const [];
            _recentCombinedKeys = _recentCombinedKeys
                .where((entry) => !entry.startsWith('m:'))
                .toList(growable: false);
            onClearMeteredRecents?.call();
          }
          _refreshSignal.value++;
          showSuggestions(context);
        },
      ),
    ];
    final recentCarparkById = <String, Carpark>{
      for (final carpark in _recentCarparks) carpark.id: carpark,
    };
    final recentMeteredByKey = <String, MeteredStreetGroup>{
      for (final group in _recentMeteredGroups) group.key: group,
    };
    final seenCarparkIds = <String>{};
    final seenMeteredKeys = <String>{};

    void addCarparkRow(Carpark carpark) {
      if (!seenCarparkIds.add(carpark.id)) return;
      rows.add(
        _buildCarparkTile(
          context,
          carpark,
          leadingIcon: Icons.history,
          showDetails: true,
        ),
      );
    }

    void addMeteredRow(MeteredStreetGroup group) {
      if (!seenMeteredKeys.add(group.key)) return;
      rows.add(
        _buildMeteredTile(
          context,
          group,
          leadingIcon: Icons.history,
          showSaveButton: true,
        ),
      );
    }

    for (final token in _recentCombinedKeys) {
      if (token.startsWith('p:')) {
        final id = token.substring(2);
        final carpark = recentCarparkById[id];
        if (carpark != null) addCarparkRow(carpark);
        continue;
      }
      if (token.startsWith('m:')) {
        final key = token.substring(2);
        final group = recentMeteredByKey[key];
        if (group != null) addMeteredRow(group);
      }
    }

    for (final carpark in _recentCarparks) {
      addCarparkRow(carpark);
    }
    for (final group in _recentMeteredGroups) {
      addMeteredRow(group);
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (savedSection != null) savedSection,
        const Divider(height: 1),
        ...quickActionSection,
        filterRow,
        const Divider(height: 1),
        ..._withDividers(rows),
      ],
    );
  }

  List<Widget> _buildQuickActionSection(BuildContext context) {
    if (quickActions.isEmpty) return const [];
    final rows = <Widget>[
      for (final action in quickActions)
        ListTile(
          leading: Icon(action.icon),
          title: Text(action.title),
          subtitle: action.subtitle == null ? null : Text(action.subtitle!),
          onTap: () => close(context, action.selection),
        ),
    ];
    return [..._withDividers(rows), const Divider(height: 1)];
  }

  void _scheduleDebouncedSearch(BuildContext context, String rawTrimmed) {
    if (rawTrimmed == _lastRawQuery) return;
    _lastRawQuery = rawTrimmed;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_searchDebounce, () {
      _debouncedQuery = rawTrimmed;
      _refreshSignal.value++;
    });
  }

  Future<List<GeocodingResult>> _getGeocodeResults(String trimmed) {
    if (_lastGeocodeQuery != trimmed) {
      _lastGeocodeQuery = trimmed;
      _geocodeResultsFuture = geocodingService.geocodeMany(
        trimmed,
        limit: 5,
        fallbackLabel: _geocodingFallbackLabel,
      );
    }
    return _geocodeResultsFuture ??
        Future<List<GeocodingResult>>.value(const []);
  }

  List<Carpark> _nearestCarparks(GeocodingResult location) {
    if (allCarparks.isEmpty) return const [];
    final entries =
        allCarparks
            .map(
              (carpark) => MapEntry(
                carpark,
                _distanceKm(
                  location.latitude,
                  location.longitude,
                  carpark.latitude,
                  carpark.longitude,
                ),
              ),
            )
            .toList()
          ..sort((a, b) => a.value.compareTo(b.value));
    return entries.take(_maxNearbyResults).map((entry) => entry.key).toList();
  }

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final rad = math.pi / 180.0;
    final dLat = (lat2 - lat1) * rad;
    final dLon = (lon2 - lon1) * rad;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * rad) *
            math.cos(lat2 * rad) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _refreshSignal.dispose();
    super.dispose();
  }
}

class _SearchSection {
  const _SearchSection({
    required this.title,
    required this.items,
    required this.leadingIcon,
    required this.onClear,
  });

  final String title;
  final List<Carpark> items;
  final IconData leadingIcon;
  final VoidCallback? onClear;
}

class _AddPlaceInput {
  const _AddPlaceInput({
    required this.label,
    required this.query,
    this.location,
  });

  final String label;
  final String query;
  final GeocodingResult? location;
}
