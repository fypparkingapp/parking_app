part of 'appmain.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.hideParkingMarkers = false,
    this.showBackButton = true,
    this.showBottomFunctionBar = true,
  });

  final bool hideParkingMarkers;
  final bool showBackButton;
  final bool showBottomFunctionBar;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late MapController _mapController;
  LatLng? _currentLocation;
  String _selectedTheme = 'Standard';
  AppLanguage _language = AppLanguage.traditionalChinese;
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Carpark? _routeDestination;
  LatLng? _routeStartOverride;
  LatLng? _pendingMapTapPoint;
  bool _pickingRouteStart = false;
  bool _pickingRouteDestination = false;
  bool _skipNextMapTapSelection = false;
  final TollTimeMode _routeTollTimeMode = TollTimeMode.now;
  DateTime? _routeTollDateTime;
  LatLng? _searchLocationMarker;
  double _searchRadiusMeters = 1000;
  static const double _minSearchRadiusMeters = 200;
  static const double _maxSearchRadiusMeters = 5000;
  static const double _searchRadiusStepMeters = 200;
  List<Carpark> _allCarparks = []; // Complete dataset from API
  List<Carpark> _carparks = []; // Carparks currently shown on the map
  final MeteredParkingService _meteredService = MeteredParkingService();
  List<MeteredStreetGroup> _meteredGroups = const [];
  static const Set<String> _meteredVehicleTypes = {'A'};
  List<String> _recentMeteredKeys = const [];
  List<String> _recentCombinedKeys = const [];
  static const int _maxSearchResults = 50;
  double _currentZoom = 11.0;
  bool _useClustering = true;
  bool _showHkSpeedMap = true;
  HkSpeedMapSource _hkSpeedMapSource = HkSpeedMapSource.standard;
  bool _hkSpeedWideBuffer = false;
  Timer? _hkSpeedWideBufferTimer;
  final Set<String> _prefetchedCarparkIds = {};
  LatLng? _lastPrefetchCenter;
  bool _mapIsReady = false;
  bool _isLoadingCarparks = true;
  late final AnimationController _cameraAnimationController;
  static const String _themePrefKey = 'selectedTheme';
  static const String _languagePrefKey = 'selectedLanguage';
  static const String _recentSearchPrefKey = 'recentCarparkSearches';
  static const String _favoriteCarparkPrefKey = 'favoriteCarparks';
  static const String _savedPlacesPrefKey = 'savedPlaces';
  static const String _vehicleTypePrefKey = 'selectedVehicleType';
  static const String _hkSpeedMapSourcePrefKey = 'hkSpeedMapSource';
  static const String _smartNavigationPrefKey = 'smartNavigationPreference';
  static const String _recentMeteredPrefKey = 'recentMeteredSearches';
  static const String _recentCombinedPrefKey = 'recentSearchCombined';
  static const int _maxRecentMetered = 10;
  static const int _maxRecentSearches = 10;
  static const int _maxCombinedRecentSearches = 20;
  static const int _maxFavoriteCarparks = 20;
  static const int _maxSavedPlaces = 8;
  List<String> _recentSearchCarparkIds = const [];
  List<String> _favoriteCarparkIds = const [];
  List<SavedPlace> _savedPlaces = const [];
  User? _signedInUser;
  StreamSubscription<User?>? _authStateSub;
  HkVehicleType _vehicleType = HkVehicleType.privateCar;
  SmartNavigationPreference _smartNavigationPreference =
      SmartNavigationPreference.cheapest;
  final bool _showMap = true;
  static const String _geocodingUserAgent =
      'wilson-parking/1.0 (contact@example.com)';
  late final GeocodingService _geocodingService = GeocodingService(
    userAgent: _geocodingUserAgent,
  );
  late final SmartNavigationService _smartNavigationService =
      SmartNavigationService(
        osrmBaseUrl: _osrmBaseUrl,
        languageCode: _language.storageValue,
      );
  static final LatLng _defaultCenter = LatLng(22.3193, 114.1694);
  static const String _osrmBaseUrl = 'https://osrm.ryanpumpkin.com';
  bool _smartNavigationRunning = false;

  void _armSkipNextMapTapSelection() {
    _skipNextMapTapSelection = true;
    // Clear after this frame in case no map onTap arrives for the same gesture.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _skipNextMapTapSelection = false;
    });
  }

  // Map themes with their respective tile URLs
  final Map<String, MapThemeConfig> _mapThemes = {
    'Standard': const MapThemeConfig(
      label: 'Default',
      urlTemplate:
          'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
      subdomains: ['a', 'b', 'c', 'd'],
      appBarColor: Color(0xFF1565C0),
      appBarForeground: Colors.white,
      accentColor: Color(0xFF1976D2),
      backgroundColor: Color.fromARGB(255, 255, 255, 255),
    ),
    'Dark': const MapThemeConfig(
      label: 'Night Drive',
      urlTemplate:
          'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
      subdomains: ['a', 'b', 'c', 'd'],
      appBarColor: Color(0xFF101820),
      appBarForeground: Colors.white,
      accentColor: Color.fromARGB(255, 173, 175, 175),
      backgroundColor: Color(0xFF0F1117),
    ),
    'Light': const MapThemeConfig(
      label: 'Clean Atlas',
      urlTemplate:
          'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
      subdomains: ['a', 'b', 'c', 'd'],
      appBarColor: Color(0xFFF6F6F6),
      appBarForeground: Color(0xFF1B1F24),
      accentColor: Color(0xFFF9A825),
      backgroundColor: Color(0xFFFDFBF7),
    ),
  };

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _cameraAnimationController = AnimationController(vsync: this);
    _checkAndRequestLocationPermission();
    _restoreThemePreference();
    _restoreLanguagePreference();
    _restoreRecentSearches();
    _restoreFavoriteCarparks();
    _restoreSavedPlaces();
    _restoreVehicleTypePreference();
    _restoreHkSpeedMapSourcePreference();
    _restoreSmartNavigationPreference();
    _restoreRecentMeteredSearches();
    _restoreRecentCombinedSearches();
    _authStateSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      _safeSetState(() => _signedInUser = user);
      if (user != null) {
        unawaited(_pullCloudPreferences(user.uid));
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapIsReady = true;
      _loadCarparks();
      unawaited(_loadMeteredGroups());
    });
  }

  @override
  void dispose() {
    _authStateSub?.cancel();
    _cloudPrefsSyncDebounce?.cancel();
    _geocodingService.dispose();
    _smartNavigationService.dispose();
    _hkSpeedWideBufferTimer?.cancel();
    _cameraAnimationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  HkVehicleType _vehicleTypeFromStorage(String? value) {
    switch (value) {
      case 'motorcycle':
        return HkVehicleType.motorcycle;
      case 'taxi':
        return HkVehicleType.taxi;
      case 'privateCar':
      default:
        return HkVehicleType.privateCar;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final themeConfig = _mapThemes[_selectedTheme]!;
    final useDarkFade = _selectedTheme == 'Dark';
    final fadeColor = useDarkFade ? Colors.black : Colors.white;
    final mapControlsBottom = widget.showBottomFunctionBar ? 310.0 : 120.0;
    final hkSpeedOpacity = _currentZoom <= 11
        ? 0.4
        : _currentZoom < 13
        ? 0.5
        : _currentZoom < 15
        ? 0.6
        : 0.7;

    final content = Stack(
      children: [
        Scaffold(
          key: _scaffoldKey,
          backgroundColor: themeConfig.backgroundColor,
          drawer: SettingsDrawer(
            themeConfig: themeConfig,
            mapThemes: _mapThemes,
            selectedThemeKey: _selectedTheme,
            onSelectTheme: (value) {
              setState(() {
                _selectedTheme = value;
              });
              _saveThemePreference(value);
            },
            language: _language,
            onSelectLanguage: (value) {
              setState(() {
                _language = value;
              });
              appLanguageNotifier.value = value;
              _saveLanguagePreference(value);
            },
            useClustering: _useClustering,
            onUseClusteringChanged: (value) {
              setState(() {
                _useClustering = value;
              });
            },
            showHkSpeedMap: _showHkSpeedMap,
            onShowHkSpeedMapChanged: (value) {
              setState(() {
                _showHkSpeedMap = value;
                _hkSpeedWideBuffer = false;
              });
            },
            hkSpeedMapSource: _hkSpeedMapSource,
            onSelectHkSpeedMapSource: (value) {
              setState(() {
                _hkSpeedMapSource = value;
                _hkSpeedWideBuffer = false;
              });
              _saveHkSpeedMapSourcePreference(value);
            },
            onZoomIn: () => _adjustZoom(1.0),
            onZoomOut: () => _adjustZoom(-1.0),
            onGoToCurrentLocation: () => _getCurrentLocation(),
            onResetView: () {
              _mapController.move(
                _currentLocation ?? _defaultCenter,
                _currentLocation != null ? 15.0 : 11.0,
              );
            },
            onClearCache: () => _clearCarparkCacheAndReload(),
            vehicleType: _vehicleType,
            onSelectVehicleType: (value) {
              setState(() {
                _vehicleType = value;
              });
              _saveVehicleTypePreference(value);
            },
            signedInEmail: _signedInUser?.email,
            onEmailSignIn: _signInWithEmail,
            onEmailRegister: _registerWithEmail,
            onGoogleSignIn: _signInWithGoogle,
            onGoogleSignOut: _signOutGoogle,
            onReloadCloudPreferences: _reloadCloudPreferences,
          ),
          body: Stack(
            children: [
              if (_showMap)
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentLocation ?? _defaultCenter,
                    initialZoom: _currentLocation != null ? 15.0 : 11.0,
                    minZoom: 0,
                    maxZoom: 18,
                    onTap: (tapPosition, latLng) {
                      if (_skipNextMapTapSelection) {
                        _skipNextMapTapSelection = false;
                        return;
                      }
                      if (_pickingRouteStart) {
                        _selectMapRouteStart(latLng);
                        return;
                      }
                      if (_pickingRouteDestination) {
                        _selectMapRouteDestination(latLng);
                        return;
                      }
                      if (!widget.showBottomFunctionBar) return;
                      _safeSetState(() {
                        _pendingMapTapPoint = latLng;
                      });
                    },
                    onLongPress: (tapPosition, latLng) {
                      if (!widget.showBottomFunctionBar) {
                        return;
                      }
                      if (_pickingRouteStart) {
                        _selectMapRouteStart(latLng);
                        return;
                      }
                      if (_pickingRouteDestination) {
                        _selectMapRouteDestination(latLng);
                        return;
                      }
                      _safeSetState(() {
                        _pendingMapTapPoint = null;
                        _searchLocationMarker = latLng;
                      });
                      _showNearbyCarparksOnMap(latLng);
                    },
                    onMapEvent: (event) => _handleMapEvent(event),
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: themeConfig.urlTemplate,
                      subdomains: themeConfig.subdomains,
                    ),
                    if (_showHkSpeedMap)
                      HkSpeedMapTileLayer(
                        source: _hkSpeedMapSource,
                        opacity: hkSpeedOpacity,
                        keepBuffer: _hkSpeedWideBuffer ? 6 : 0,
                        panBuffer: _hkSpeedWideBuffer ? 2 : 0,
                      ),
                    CurrentLocationLayer(
                      style: LocationMarkerStyle(
                        markerSize: const Size(20, 20),
                        markerDirection: MarkerDirection.heading,
                        headingSectorColor: themeConfig.accentColor.withValues(
                          alpha: 0.5,
                        ),
                        headingSectorRadius: 60,
                      ),
                    ),
                    if (_searchLocationMarker != null)
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: _searchLocationMarker!,
                            radius: _searchRadiusMeters,
                            useRadiusInMeter: true,
                            color: themeConfig.accentColor.withValues(
                              alpha: 0.08,
                            ),
                            borderColor: themeConfig.accentColor.withValues(
                              alpha: 0.45,
                            ),
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),
                    if (!widget.hideParkingMarkers ||
                        _searchLocationMarker != null)
                      MarkerLayer(markers: _generateMarkersOrClusters()),
                    if (_meteredGroups.isNotEmpty)
                      MarkerLayer(markers: _buildMeteredMarkers()),
                    if (_searchLocationMarker != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _searchLocationMarker!,
                            width: 44,
                            height: 44,
                            child: GestureDetector(
                              onTap: () {
                                _armSkipNextMapTapSelection();
                                _clearPendingMapSelection();
                                _clearSearchMarker();
                              },
                              child: const Icon(
                                Icons.place,
                                color: Colors.red,
                                size: 36,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (_routeStartOverride != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _routeStartOverride!,
                            width: 44,
                            height: 44,
                            child: GestureDetector(
                              onTap: () {
                                _armSkipNextMapTapSelection();
                                _safeSetState(() {
                                  _pendingMapTapPoint = null;
                                  _routeStartOverride = null;
                                });
                              },
                              child: const Icon(
                                Icons.trip_origin,
                                color: Colors.blue,
                                size: 36,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (_routeDestination != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(
                              _routeDestination!.latitude,
                              _routeDestination!.longitude,
                            ),
                            width: 44,
                            height: 44,
                            child: GestureDetector(
                              onTap: () {
                                _armSkipNextMapTapSelection();
                                _safeSetState(() {
                                  _pendingMapTapPoint = null;
                                  _routeDestination = null;
                                  _searchController.clear();
                                });
                              },
                              child: const Icon(
                                Icons.trip_origin,
                                color: Colors.red,
                                size: 36,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (_pendingMapTapPoint != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _pendingMapTapPoint!,
                            width: 44,
                            height: 44,
                            child: const Icon(
                              Icons.place,
                              color: Color(0xFFFF8F00),
                              size: 36,
                            ),
                          ),
                        ],
                      ),
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: TextSourceAttribution(
                          "OpenStreetMap contributors",
                          textStyle: TextStyle(
                            color: useDarkFade ? Colors.white : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Container(color: themeConfig.backgroundColor),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: SizedBox(
                  height: 120 + MediaQuery.of(context).padding.top,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        height: 120 + MediaQuery.of(context).padding.top,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(0.5, 0.0),
                            end: Alignment(0.5, 1.0),
                            colors: [
                              fadeColor.withAlpha(204),
                              fadeColor.withAlpha(0),
                            ],
                          ),
                        ),
                      ),
                      if (widget.showBackButton)
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 70,
                          left: 12,
                          child: Material(
                            color: Colors.transparent,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () {
                                final navigator = Navigator.of(context);
                                if (navigator.canPop()) {
                                  navigator.pop();
                                  return;
                                }
                                final rootNavigator = Navigator.of(
                                  context,
                                  rootNavigator: true,
                                );
                                if (rootNavigator.canPop()) {
                                  rootNavigator.pop();
                                }
                              },
                              child: Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0x324A1400),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.arrow_back,
                                  color: Color(0xFF00008B),
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 36,
                        left: 0,
                        right: 0,
                        child: Text(
                          l10n.carpark,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: useDarkFade ? Colors.white : Colors.black,
                            fontSize: 20,
                            fontFamily: 'PingFang TC',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 70,
                        right: 16,
                        child: Material(
                          color: Colors.transparent,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () =>
                                _scaffoldKey.currentState?.openDrawer(),
                            child: Container(
                              width: 46,
                              height: 46,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x324A1400),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.settings,
                                color: Color(0xFF00008B),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 16,
                bottom: mapControlsBottom,
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_searchLocationMarker != null) ...[
                        _buildMapControlButton(
                          heroTag: 'radiusIncreaseButton',
                          icon: Icons.add_circle_outline,
                          onPressed: () =>
                              _adjustSearchRadius(_searchRadiusStepMeters),
                        ),
                        const SizedBox(height: 8),
                        _buildMapControlButton(
                          heroTag: 'radiusDecreaseButton',
                          icon: Icons.remove_circle_outline,
                          onPressed: () =>
                              _adjustSearchRadius(-_searchRadiusStepMeters),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _buildMapControlButton(
                        heroTag: 'zoomInButton',
                        icon: Icons.add,
                        onPressed: () => _adjustZoom(1.0),
                      ),
                      const SizedBox(height: 8),
                      _buildMapControlButton(
                        heroTag: 'zoomOutButton',
                        icon: Icons.remove,
                        onPressed: () => _adjustZoom(-1.0),
                      ),
                      const SizedBox(height: 8),
                      _buildMapControlButton(
                        heroTag: 'recenterButton',
                        icon: Icons.my_location,
                        onPressed: () => _toggleLocationTracking(),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.showBottomFunctionBar &&
                          _pendingMapTapPoint != null) ...[
                        _buildPendingMapActionBar(),
                        const SizedBox(height: 10),
                      ],
                      Row(
                        children: [
                          Expanded(child: _buildBottomSearchBar(themeConfig)),
                        ],
                      ),
                      if (widget.showBottomFunctionBar) ...[
                        const SizedBox(height: 10),
                        _buildHomeFunctionRows(
                          themeConfig,
                          nearbyLabel: l10n.nearby,
                          onNearbyTap: _openNearbyCarparkList,
                          parkingLabel: l10n.parking_map_title,
                          onParkingTap: _openParkingMainScreen,
                          meteredLabel: l10n.metered_parking,
                          onMeteredTap: _openMeteredParkingScreen,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: _isLoadingCarparks
                ? OpenScreen(
                    key: const ValueKey('loading-screen'),
                    message: l10n.loading_carparks,
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
    switch (_selectedTheme) {
      case 'Dark':
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: content,
        );
      case 'Light':
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark,
          child: content,
        );
      case 'Standard':
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark,
          child: content,
        );
      default:
        return content;
    }
  }

  Widget _buildMapControlButton({
    required String heroTag,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 40,
      height: 40,
      child: FloatingActionButton(
        heroTag: heroTag,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF00008B),
        elevation: 4,
        onPressed: onPressed,
        child: Icon(icon, size: 20),
      ),
    );
  }

  void _adjustSearchRadius(double deltaMeters) {
    final marker = _searchLocationMarker;
    if (marker == null) return;
    final next = (_searchRadiusMeters + deltaMeters).clamp(
      _minSearchRadiusMeters,
      _maxSearchRadiusMeters,
    );
    if (next == _searchRadiusMeters) return;
    _safeSetState(() {
      _searchRadiusMeters = next;
    });
    _showNearbyCarparksOnMap(marker);
  }

  Future<void> _showMarkerRouteChoiceSheet(Carpark carpark) async {
    final l10n = AppLocalizations.of(context)!;
    final carparkPoint = LatLng(carpark.latitude, carpark.longitude);
    final isCurrentStart =
        _routeStartOverride != null &&
        _samePoint(_routeStartOverride!, carparkPoint);
    final isCurrentDestination = _routeDestination?.id == carpark.id;
    final action = await showModalBottomSheet<_MarkerRouteChoiceAction>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(_markerDestinationLabel(isCurrentDestination)),
                subtitle: Text(_carparkDisplayName(carpark)),
                onTap: () => Navigator.of(sheetContext).pop(
                  isCurrentDestination
                      ? _MarkerRouteChoiceAction.clearDestination
                      : _MarkerRouteChoiceAction.destination,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(
                  isCurrentStart
                      ? l10n.clear_selected_start
                      : l10n.choose_start_point,
                ),
                subtitle: Text(_carparkDisplayName(carpark)),
                onTap: () => Navigator.of(sheetContext).pop(
                  isCurrentStart
                      ? _MarkerRouteChoiceAction.clearStart
                      : _MarkerRouteChoiceAction.start,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) return;
    if (action == _MarkerRouteChoiceAction.clearStart) {
      _safeSetState(() {
        _pendingMapTapPoint = null;
        _routeStartOverride = null;
        _pickingRouteStart = false;
      });
      return;
    }
    if (action == _MarkerRouteChoiceAction.clearDestination) {
      _safeSetState(() {
        _pendingMapTapPoint = null;
        _routeDestination = null;
        _pickingRouteDestination = false;
        _searchController.clear();
      });
      return;
    }
    if (action == _MarkerRouteChoiceAction.start) {
      _selectMapRouteStart(LatLng(carpark.latitude, carpark.longitude));
      return;
    }
    _selectRouteDestinationCarpark(carpark);
  }

  void _selectMapRouteStart(LatLng latLng) {
    _safeSetState(() {
      _pendingMapTapPoint = null;
      _routeStartOverride = latLng;
      _pickingRouteStart = false;
      _pickingRouteDestination = false;
    });
    _openNavigationIfRouteReady();
  }

  void _selectMapRouteDestination(LatLng latLng) {
    final destination = _manualPointAsRouteDestination(latLng);
    _safeSetState(() {
      _pendingMapTapPoint = null;
      _routeDestination = destination;
      _pickingRouteDestination = false;
      _pickingRouteStart = false;
      final displayName = _carparkDisplayName(destination);
      _searchController.value = TextEditingValue(
        text: displayName,
        selection: TextSelection.collapsed(offset: displayName.length),
      );
    });
    _openNavigationIfRouteReady();
  }

  void _selectRouteDestinationCarpark(Carpark carpark) {
    _safeSetState(() {
      _pendingMapTapPoint = null;
      _routeDestination = carpark;
      _pickingRouteDestination = false;
      _pickingRouteStart = false;
      final displayName = _carparkDisplayName(carpark);
      _searchController.value = TextEditingValue(
        text: displayName,
        selection: TextSelection.collapsed(offset: displayName.length),
      );
    });
    _openNavigationIfRouteReady();
  }

  void _selectRouteDestinationMeteredGroup(MeteredStreetGroup group) {
    _safeSetState(() {
      _pendingMapTapPoint = null;
      _routeDestination = _meteredGroupAsRouteDestination(group);
      _pickingRouteStart = false;
      _pickingRouteDestination = false;
      final displayName = _meteredStreetLabel(group);
      _searchController.value = TextEditingValue(
        text: displayName,
        selection: TextSelection.collapsed(offset: displayName.length),
      );
    });
    _openNavigationIfRouteReady();
  }

  Widget _buildPendingMapActionBar() {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final point = _pendingMapTapPoint!;
    final coords =
        '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
    return Material(
      color: theme.cardColor,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF8F00).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.place_outlined,
                    color: Color(0xFFFF8F00),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.coordinates,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.black54,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        coords,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l10n.close,
                  onPressed: _clearPendingMapSelection,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1565C0),
                      side: BorderSide(
                        color: const Color(0xFF1565C0).withValues(alpha: 0.45),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => _selectMapRouteStart(point),
                    icon: const Icon(Icons.flag_outlined, size: 18),
                    label: Text(l10n.choose_start_point),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD84315),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => _selectMapRouteDestination(point),
                    icon: const Icon(Icons.place_outlined, size: 18),
                    label: Text(l10n.choose_destination),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _clearPendingMapSelection() {
    if (_pendingMapTapPoint == null) return;
    _safeSetState(() {
      _pendingMapTapPoint = null;
    });
  }

  Future<void> _showMeteredMarkerRouteChoiceSheet(
    MeteredStreetGroup group,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final isCurrentStart =
        _routeStartOverride != null &&
        _samePoint(_routeStartOverride!, group.center);
    final destinationId = 'metered:${group.key}';
    final isCurrentDestination = _routeDestination?.id == destinationId;
    final action = await showModalBottomSheet<_MarkerRouteChoiceAction>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(_markerDestinationLabel(isCurrentDestination)),
                subtitle: Text(_meteredStreetLabel(group)),
                onTap: () => Navigator.of(sheetContext).pop(
                  isCurrentDestination
                      ? _MarkerRouteChoiceAction.clearDestination
                      : _MarkerRouteChoiceAction.destination,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(
                  isCurrentStart
                      ? l10n.clear_selected_start
                      : l10n.choose_start_point,
                ),
                subtitle: Text(_meteredStreetLabel(group)),
                onTap: () => Navigator.of(sheetContext).pop(
                  isCurrentStart
                      ? _MarkerRouteChoiceAction.clearStart
                      : _MarkerRouteChoiceAction.start,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) return;
    if (action == _MarkerRouteChoiceAction.clearStart) {
      _safeSetState(() {
        _pendingMapTapPoint = null;
        _routeStartOverride = null;
        _pickingRouteStart = false;
      });
      return;
    }
    if (action == _MarkerRouteChoiceAction.clearDestination) {
      _safeSetState(() {
        _pendingMapTapPoint = null;
        _routeDestination = null;
        _pickingRouteDestination = false;
        _searchController.clear();
      });
      return;
    }
    if (action == _MarkerRouteChoiceAction.start) {
      _selectMapRouteStart(group.center);
      return;
    }
    _selectRouteDestinationMeteredGroup(group);
  }

  String _markerDestinationLabel(bool isCurrentDestination) {
    if (isCurrentDestination) {
      switch (_language) {
        case AppLanguage.english:
          return 'Clear destination';
        case AppLanguage.traditionalChinese:
          return '清除目的地';
        case AppLanguage.simplifiedChinese:
          return '清除目的地';
      }
    }
    switch (_language) {
      case AppLanguage.english:
        return 'Set as destination';
      case AppLanguage.traditionalChinese:
        return '設為目的地';
      case AppLanguage.simplifiedChinese:
        return '设为目的地';
    }
  }

  void _openNavigationIfRouteReady() {
    final destination = _routeDestination;
    if (destination == null || _routeStartOverride == null) return;
    _openNavigation(destination);
  }

  bool _samePoint(LatLng a, LatLng b) {
    return (a.latitude - b.latitude).abs() < 0.000001 &&
        (a.longitude - b.longitude).abs() < 0.000001;
  }

  Carpark _meteredGroupAsRouteDestination(MeteredStreetGroup group) {
    return Carpark(
      id: 'metered:${group.key}',
      nameEn: _meteredStreetLabelFor(group, AppLanguage.english),
      nameTc: _meteredStreetLabelFor(group, AppLanguage.traditionalChinese),
      nameSc: _meteredStreetLabelFor(group, AppLanguage.simplifiedChinese),
      addressEn: group.districtEn,
      addressTc: group.districtTc,
      addressSc: group.districtSc,
      latitude: group.center.latitude,
      longitude: group.center.longitude,
      operatorName: 'Metered',
    );
  }

  Carpark _manualPointAsRouteDestination(LatLng latLng) {
    final coords =
        '${latLng.latitude.toStringAsFixed(5)}, '
        '${latLng.longitude.toStringAsFixed(5)}';
    return Carpark(
      id: 'manual:${latLng.latitude},${latLng.longitude}',
      nameEn: 'Dropped pin',
      nameTc: '已選地點',
      nameSc: '已选地点',
      addressEn: coords,
      addressTc: coords,
      addressSc: coords,
      latitude: latLng.latitude,
      longitude: latLng.longitude,
      operatorName: 'Manual',
    );
  }

  void _showMarkerChoiceSheet(List<_MarkerChoiceItem> items) {
    if (items.isEmpty) return;
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const SizedBox(height: 8),
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
              const SizedBox(height: 8),
              for (final item in items)
                ListTile(
                  leading: item.type == _MarkerItemType.metered
                      ? Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          child: Text(
                            'M',
                            style: TextStyle(
                              color:
                                  _mapThemes[_selectedTheme]?.accentColor ??
                                  Colors.blue,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.local_parking,
                          color:
                              _mapThemes[_selectedTheme]?.accentColor ??
                              Colors.blue,
                        ),
                  title: Text(item.title),
                  subtitle: item.subtitle.isNotEmpty
                      ? Text(item.subtitle)
                      : null,
                  trailing: item.trailing ?? const SizedBox.shrink(),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _clearPendingMapSelection();
                    if (item.type == _MarkerItemType.carpark &&
                        item.carpark != null) {
                      _showCarparkDetails(item.carpark!);
                      return;
                    }
                    if (item.type == _MarkerItemType.metered &&
                        item.meteredGroup != null) {
                      _showMeteredGroupSheet(item.meteredGroup!);
                    }
                  },
                  onLongPress: () {
                    Navigator.of(sheetContext).pop();
                    _clearPendingMapSelection();
                    if (item.type == _MarkerItemType.carpark &&
                        item.carpark != null) {
                      final carpark = item.carpark!;
                      if (_pickingRouteStart) {
                        _safeSetState(() {
                          _routeStartOverride = LatLng(
                            carpark.latitude,
                            carpark.longitude,
                          );
                          _pickingRouteStart = false;
                          _pickingRouteDestination = false;
                        });
                        _openNavigationIfRouteReady();
                        return;
                      }
                      if (_pickingRouteDestination) {
                        _safeSetState(() {
                          _routeDestination = carpark;
                          _pickingRouteStart = false;
                          _pickingRouteDestination = false;
                          final displayName = _carparkDisplayName(carpark);
                          _searchController.value = TextEditingValue(
                            text: displayName,
                            selection: TextSelection.collapsed(
                              offset: displayName.length,
                            ),
                          );
                        });
                        _openNavigationIfRouteReady();
                        return;
                      }
                      unawaited(_showMarkerRouteChoiceSheet(carpark));
                      return;
                    }
                    if (item.type == _MarkerItemType.metered &&
                        item.meteredGroup != null) {
                      final group = item.meteredGroup!;
                      if (_pickingRouteStart) {
                        _safeSetState(() {
                          _routeStartOverride = group.center;
                          _pickingRouteStart = false;
                          _pickingRouteDestination = false;
                        });
                        _openNavigationIfRouteReady();
                        return;
                      }
                      if (_pickingRouteDestination) {
                        _safeSetState(() {
                          _routeDestination = _meteredGroupAsRouteDestination(
                            group,
                          );
                          _pickingRouteStart = false;
                          _pickingRouteDestination = false;
                          final displayName = _meteredStreetLabel(group);
                          _searchController.value = TextEditingValue(
                            text: displayName,
                            selection: TextSelection.collapsed(
                              offset: displayName.length,
                            ),
                          );
                        });
                        _openNavigationIfRouteReady();
                        return;
                      }
                      unawaited(_showMeteredMarkerRouteChoiceSheet(group));
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  String _meteredVehicleLabel(String code, AppLocalizations l10n) {
    switch (code) {
      case 'A':
        return l10n.vacancy_type_private_car;
      case 'B':
        return l10n.metered_vehicle_light_goods;
      case 'C':
        return l10n.metered_vehicle_heavy_goods;
      case 'D':
        return l10n.metered_vehicle_coach;
      case 'E':
        return l10n.vacancy_type_motorcycle;
      case 'F':
        return l10n.metered_vehicle_special;
      case 'G':
        return l10n.vacancy_type_taxi;
    }
    return code;
  }

  void _showMeteredGroupSheet(MeteredStreetGroup group) {
    unawaited(_rememberRecentMeteredSearch(group));
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final predictionFuture = VacancyPredictionService().forecastMeter(group);
    final unknownCount = group.spaces
        .where((s) => s.occupancy == MeteredOccupancy.unknown)
        .length;
    final occupiedCount = group.total - group.vacant - unknownCount;
    final operatingStatus = resolveOperatingStatus(
      group.operatingPeriod,
      DateTime.now(),
    );
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _mapThemes[_selectedTheme]?.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color:
                            _mapThemes[_selectedTheme]?.accentColor.withValues(
                              alpha: 0.12,
                            ) ??
                            Colors.blue.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.local_parking,
                        color:
                            _mapThemes[_selectedTheme]?.accentColor ??
                            Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _meteredStreetLabel(group),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _meteredDistrictLabel(group),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color
                                  ?.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.close,
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (_mapThemes[_selectedTheme]?.accentColor ?? Colors.blue)
                            .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Text(
                        l10n.metered_vacant,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color:
                              _mapThemes[_selectedTheme]?.accentColor ??
                              Colors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${group.vacant}/${group.total}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color:
                              _mapThemes[_selectedTheme]?.accentColor ??
                              Colors.blue,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _meteredVehicleLabel(group.vehicleType, l10n),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color:
                              _mapThemes[_selectedTheme]?.accentColor ??
                              Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FutureBuilder<MeterVacancyForecast?>(
                  future: predictionFuture,
                  builder: (sheetContext, snap) {
                    final accentColor =
                        _mapThemes[_selectedTheme]?.accentColor ?? Colors.blue;
                    if (snap.connectionState == ConnectionState.waiting) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.access_time, color: accentColor),
                            const SizedBox(width: 10),
                            Text(
                              l10n.predictedVacancy,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: accentColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ],
                        ),
                      );
                    }

                    final forecast = snap.data;
                    if (forecast == null) return const SizedBox.shrink();

                    final delta = forecast.delta;
                    final deltaLabel = delta > 0 ? '+$delta' : delta.toString();
                    final deltaColor = delta > 0
                        ? Colors.green
                        : delta < 0
                        ? Colors.red
                        : theme.colorScheme.onSurface;

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time, color: accentColor),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.predictedVacancy,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: accentColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      '${forecast.predictedVacancy}/${forecast.totalSpaces}',
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            color: accentColor,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '($deltaLabel)',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: deltaColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    if (!forecast.isReliable) ...[
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.warning_amber,
                                        size: 14,
                                        color: Colors.orange,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '+${forecast.horizonMinutes}min',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color
                                  ?.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMeteredStatusPill(
                      label: _operatingStatusLabel(l10n, operatingStatus),
                    ),
                    _buildMeteredInfoChip(
                      label: l10n.metered_occupied,
                      value: occupiedCount.toString(),
                    ),
                    _buildMeteredInfoChip(
                      label: l10n.metered_unknown,
                      value: unknownCount.toString(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _openMeteredNavigation(group);
                    },
                    icon: const Icon(Icons.navigation),
                    label: Text(l10n.navigate),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _meteredStreetLabel(MeteredStreetGroup group) {
    return _meteredStreetLabelFor(group, _language);
  }

  String _meteredStreetLabelFor(
    MeteredStreetGroup group,
    AppLanguage language,
  ) {
    String street;
    String section;
    switch (language) {
      case AppLanguage.traditionalChinese:
        street = group.streetTc.isNotEmpty ? group.streetTc : group.streetEn;
        section = group.sectionTc.isNotEmpty
            ? group.sectionTc
            : group.sectionEn;
        break;
      case AppLanguage.simplifiedChinese:
        street = group.streetSc.isNotEmpty ? group.streetSc : group.streetEn;
        section = group.sectionSc.isNotEmpty
            ? group.sectionSc
            : group.sectionEn;
        break;
      case AppLanguage.english:
        street = group.streetEn;
        section = group.sectionEn;
        break;
    }
    if (section.isNotEmpty) return '$street · $section';
    return street;
  }

  String _meteredDistrictLabel(MeteredStreetGroup group) {
    switch (_language) {
      case AppLanguage.traditionalChinese:
        return group.districtTc.isNotEmpty
            ? group.districtTc
            : group.districtEn;
      case AppLanguage.simplifiedChinese:
        return group.districtSc.isNotEmpty
            ? group.districtSc
            : group.districtEn;
      case AppLanguage.english:
        return group.districtEn;
    }
  }

  Widget _buildMeteredInfoChip({required String label, required String value}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(width: 6),
          Text(
            value,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  _MarkerChoiceItem _carparkChoiceItem(Carpark carpark) {
    final title = _carparkDisplayName(carpark);
    final subtitle = _displayAddress(carpark);
    final priceLabel = _formatHourlyPriceShort(carpark);
    return _MarkerChoiceItem.carpark(
      carpark: carpark,
      title: title,
      subtitle: subtitle,
      trailing: priceLabel == null
          ? null
          : Text(
              priceLabel,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
    );
  }

  _MarkerChoiceItem _meteredChoiceItem(MeteredStreetGroup group) {
    return _MarkerChoiceItem.metered(
      meteredGroup: group,
      title: _meteredStreetLabel(group),
      subtitle: _meteredDistrictLabel(group),
      trailing: Text(
        '${group.vacant}/${group.total}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  String _operatingStatusLabel(
    AppLocalizations l10n,
    MeteredOperatingStatus status,
  ) {
    switch (status) {
      case MeteredOperatingStatus.free:
        return l10n.metered_status_free_now;
      case MeteredOperatingStatus.metering:
        return l10n.metered_status_metering_now;
      case MeteredOperatingStatus.noParking:
        return l10n.metered_status_no_parking_now;
      case MeteredOperatingStatus.unknown:
        return l10n.metered_status_unknown;
    }
  }

  Widget _buildMeteredStatusPill({required String label}) {
    final theme = Theme.of(context);
    final accent = _mapThemes[_selectedTheme]?.accentColor ?? Colors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: accent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  List<Carpark> _nearbyCarparks({
    LatLng? origin,
    int limit = 12,
    List<Carpark>? sourceOverride,
  }) {
    final source =
        sourceOverride ?? (_carparks.isNotEmpty ? _carparks : _allCarparks);
    if (source.isEmpty) return const [];
    LatLng resolvedOrigin;
    if (origin != null) {
      resolvedOrigin = origin;
    } else if (_currentLocation != null) {
      resolvedOrigin = _currentLocation!;
    } else if (_showMap) {
      try {
        resolvedOrigin = _mapController.camera.center;
      } catch (_) {
        resolvedOrigin = _defaultCenter;
      }
    } else {
      resolvedOrigin = _defaultCenter;
    }

    final withDistance =
        source
            .map(
              (carpark) => MapEntry(
                carpark,
                _calculateDistance(
                  resolvedOrigin,
                  LatLng(carpark.latitude, carpark.longitude),
                ),
              ),
            )
            .toList()
          ..sort((a, b) => a.value.compareTo(b.value));

    return withDistance.take(limit).map((entry) => entry.key).toList();
  }

  void _showNearbyCarparksOnMap(LatLng origin) {
    if (_allCarparks.isEmpty) return;
    final radiusMeters = _searchRadiusMeters;
    final dist = const Distance();
    final items = _allCarparks
        .where((carpark) {
          final d = dist(origin, LatLng(carpark.latitude, carpark.longitude));
          return d <= radiusMeters;
        })
        .toList(growable: false);
    _safeSetState(() {
      _carparks = items;
    });
  }

  void _clearSearchMarker() {
    _safeSetState(() {
      _searchLocationMarker = null;
      _carparks = List<Carpark>.from(_allCarparks);
    });
  }

  void _openNearbyCarparkList({LatLng? origin}) {
    final l10n = AppLocalizations.of(context)!;
    final themeConfig = _mapThemes[_selectedTheme]!;
    final theme = Theme.of(context);
    final useDarkTheme = _selectedTheme == 'Dark';
    final items = _nearbyCarparks(origin: origin);
    if (items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.no_matching_car_parks)));
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: themeConfig.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      l10n.nearby,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: useDarkTheme ? Colors.white : null,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: l10n.close,
                      icon: Icon(
                        Icons.close,
                        color: useDarkTheme ? Colors.white70 : null,
                      ),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (ctx, index) {
                    final carpark = items[index];
                    final title = _carparkDisplayName(carpark);
                    final subtitle = _displayAddress(carpark);
                    final price = _formatHourlyPriceShort(carpark);
                    return ListTile(
                      title: Text(
                        title,
                        style: useDarkTheme
                            ? const TextStyle(color: Colors.white)
                            : null,
                      ),
                      subtitle: subtitle.isNotEmpty
                          ? Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: useDarkTheme
                                  ? const TextStyle(color: Colors.white70)
                                  : null,
                            )
                          : null,
                      trailing: price != null
                          ? Text(
                              price,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: useDarkTheme ? Colors.white : null,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _handleSuggestionSelection(carpark, showDetails: true);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

enum _MarkerItemType { carpark, metered }

enum _MarkerRouteChoiceAction {
  start,
  destination,
  clearStart,
  clearDestination,
}

class _MarkerChoiceItem {
  const _MarkerChoiceItem({
    required this.type,
    required this.title,
    required this.subtitle,
    this.carpark,
    this.meteredGroup,
    this.trailing,
  });

  factory _MarkerChoiceItem.carpark({
    required Carpark carpark,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return _MarkerChoiceItem(
      type: _MarkerItemType.carpark,
      carpark: carpark,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
    );
  }

  factory _MarkerChoiceItem.metered({
    required MeteredStreetGroup meteredGroup,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return _MarkerChoiceItem(
      type: _MarkerItemType.metered,
      meteredGroup: meteredGroup,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
    );
  }

  final _MarkerItemType type;
  final String title;
  final String subtitle;
  final Carpark? carpark;
  final MeteredStreetGroup? meteredGroup;
  final Widget? trailing;
}
