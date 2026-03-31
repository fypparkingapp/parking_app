part of 'navigation_screen.dart';

/// Standalone screen that focuses on turn-by-turn preparation for a single carpark.
///
/// Push this screen with a [parking.Carpark] selected on your map to give the
/// user a dedicated view where they can request directions, inspect ETA/distance,
/// and see the polyline overlaid on a `flutter_map` instance.
class NavigationScreen extends StatefulWidget {
  const NavigationScreen({
    super.key,
    required this.carpark,
    this.carparkDisplayName,
    this.carparkDisplayAddress,
    required this.osrmBaseUrl,
    this.profile = 'driving',
    this.tileUrlTemplate =
        'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
    this.tileSubdomains = const ['a', 'b', 'c', 'd'],
    this.accentColor = Colors.blue,
    this.backgroundColor = Colors.white,
    this.appBarColor = Colors.blue,
    this.appBarForeground = Colors.white,
    this.languageCode = 'en',
    this.initialManualOrigin,
    this.initialTollTimeMode = TollTimeMode.now,
    this.initialTollDateTime,
    this.initialVehicleType = HkVehicleType.privateCar,
    this.autoStartNavigation = false,
    this.showHkSpeedMap = true,
    this.hkSpeedMapSource = HkSpeedMapSource.standard,
    this.statusBarStyle,
    this.preferDarkSheetText = false,
  });

  final parking.Carpark carpark;
  final String osrmBaseUrl;
  final String profile;
  final String tileUrlTemplate;
  final List<String> tileSubdomains;
  final Color accentColor;
  final Color backgroundColor;
  final Color appBarColor;
  final Color appBarForeground;
  final String? carparkDisplayName;
  final String? carparkDisplayAddress;

  /// Matches the HomeScreen setting (`en` / `tc` / `sc`).
  final String languageCode;

  /// Optional start override selected on the Home screen.
  final LatLng? initialManualOrigin;

  /// Optional initial toll pricing time mode selected on the Home screen.
  final TollTimeMode initialTollTimeMode;

  /// Optional initial toll pricing date/time selected on the Home screen.
  final DateTime? initialTollDateTime;

  /// Optional initial vehicle type selected on the Home screen.
  final HkVehicleType initialVehicleType;

  /// Starts turn-by-turn as soon as the first route is ready.
  final bool autoStartNavigation;

  /// Mirrors the Home screen traffic overlay visibility preference.
  final bool showHkSpeedMap;

  /// Selects the traffic overlay source to compare coverage.
  final HkSpeedMapSource hkSpeedMapSource;

  /// Optional status bar style override.
  final SystemUiOverlayStyle? statusBarStyle;

  /// Force dark text/icons in the route sheet for light themes.
  final bool preferDarkSheetText;

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

enum _MapPickTarget { start, destination }

class _NavigationScreenState extends State<NavigationScreen> {
  static const double _kRouteSheetInitialSize = 0.30;
  static const double _kRouteSheetMinSize = 0.30;
  static const double _kRouteSheetMaxSize = 0.88;
  static const double _kCameraFitEdgePadding = 48;
  static const double _kNavigationZoom = 17.0;
  static const Duration _kTdasRetryInterval = Duration(seconds: 30);
  static const Duration _kRouteRefreshInterval = Duration(minutes: 1);
  static const String _savedPlacesPrefKey = 'savedPlaces';
  static const String _recentSearchPrefKey = 'recentCarparkSearches';
  static const String _favoriteCarparkPrefKey = 'favoriteCarparks';
  static const String _recentMeteredPrefKey = 'recentMeteredSearches';
  static const String _recentCombinedPrefKey = 'recentSearchCombined';
  static const String _recentStartSearchPrefKey = 'recentStartSearches';
  static const int _maxSearchResults = 50;
  static const int _maxRecentStartSearches = 10;
  static const int _maxSavedPlaces = 8;

  final MapController _mapController = MapController();
  final PageController _routeCardsController = PageController(
    viewportFraction: 0.9,
  );
  late final routing.OsrmRouteApi _api;
  List<routing.RouteResult> _routes = const [];
  int _selectedRouteIndex = 0;
  routing.RouteResult? _routeResult;
  List<TollEstimate> _tollEstimates = const [];
  LatLng? _origin;
  bool _loading = false;
  String? _error;
  late final NavigationService _nav;
  DateTime? _lastRerouteAt;
  List<RouteSortKey> _routePriorities = [RouteSortKey.time];
  bool _avoidTolls = false;
  String? _tollFilterNote;
  LatLng? _manualOrigin;
  bool _pickingStart = false;
  bool _pickingDestination = false;
  late LatLng _destination;
  late String _destinationName;
  late String _destinationAddress;
  parking.Carpark? _destinationCarpark;
  TollTimeMode _tollTimeMode = TollTimeMode.now;
  DateTime? _tollDateTime;
  HkVehicleType _vehicleType = HkVehicleType.privateCar;
  bool _pendingAutoStart = false;
  TdasRouteInsight? _tdasInsight;
  bool _tdasLoading = false;
  int _tdasRequestToken = 0;
  final TdasService _tdas = const TdasService();
  final TollService _tollService = TollService();
  final Map<String, TdasRouteInsight> _tdasCache = {};
  Timer? _tdasRetryTimer;
  Timer? _routeRefreshTimer;
  StreamSubscription<LocationMarkerHeading?>? _sensorHeadingSub;
  double? _deviceCompassHeading;
  final StreamController<LocationMarkerPosition?> _navPositionStreamController =
      StreamController<LocationMarkerPosition?>.broadcast();
  final StreamController<LocationMarkerHeading?> _navHeadingStreamController =
      StreamController<LocationMarkerHeading?>.broadcast();
  late final GeocodingService _startGeocodingService;
  final MeteredParkingService _startMeteredService = MeteredParkingService();
  List<SavedPlace> _savedPlaces = const [];
  List<SavedPlace> _recentStartSearches = const [];
  List<String> _recentSearchCarparkIds = const [];
  List<String> _favoriteCarparkIds = const [];
  List<String> _recentMeteredKeys = const [];
  List<String> _recentCombinedKeys = const [];
  List<parking.Carpark> _startSearchCarparks = const [];
  List<MeteredStreetGroup> _startSearchMeteredGroups = const [];
  bool _startSearchDataLoaded = false;
  LatLng? _lastVehiclePosition;
  double? _fallbackVehicleHeading;
  double? _lastFusedHeadingDeg;

  @override
  void initState() {
    super.initState();
    final cp = widget.carpark;
    _manualOrigin = widget.initialManualOrigin;
    _origin = widget.initialManualOrigin;
    _destination = LatLng(cp.latitude, cp.longitude);
    _destinationName = (widget.carparkDisplayName?.isNotEmpty ?? false)
        ? widget.carparkDisplayName!
        : (cp.nameEn.isNotEmpty ? cp.nameEn : cp.nameTc);
    _destinationAddress = (widget.carparkDisplayAddress?.isNotEmpty ?? false)
        ? widget.carparkDisplayAddress!
        : cp.fullAddress;
    _destinationCarpark = cp;
    _tollTimeMode = widget.initialTollTimeMode;
    _tollDateTime = widget.initialTollTimeMode == TollTimeMode.now
        ? null
        : widget.initialTollDateTime;
    _vehicleType = widget.initialVehicleType;
    _pendingAutoStart = widget.autoStartNavigation;
    _api = routing.OsrmRouteApi(
      baseUrl: widget.osrmBaseUrl,
      profile: widget.profile,
    );
    _startGeocodingService = GeocodingService(
      userAgent: 'wilson-parking/1.0 (contact@example.com)',
    );
    _nav = NavigationService(languageCode: widget.languageCode);
    _nav.vehiclePosition.addListener(() {
      final pos = _nav.vehiclePosition.value;
      if (pos != null && _nav.navigating.value) {
        final previous = _lastVehiclePosition;
        if (previous != null && _distanceMeters(previous, pos) >= 0.8) {
          _fallbackVehicleHeading = _bearingDegrees(previous, pos);
        }
        _lastVehiclePosition = pos;
        _navPositionStreamController.add(
          LocationMarkerPosition(
            latitude: pos.latitude,
            longitude: pos.longitude,
            accuracy: 5,
          ),
        );
        _pushLocationMarkerHeading(pos);
      }
    });
    _nav.vehicleHeading.addListener(() {
      final pos = _nav.vehiclePosition.value;
      if (pos != null && _nav.navigating.value) {
        _pushLocationMarkerHeading(pos);
      }
    });
    _nav.instructionText.addListener(() => setState(() {}));
    _nav.navigating.addListener(() {
      if (!_nav.navigating.value) {
        _lastVehiclePosition = null;
        _fallbackVehicleHeading = null;
        _deviceCompassHeading = null;
        _lastFusedHeadingDeg = null;
        _navPositionStreamController.add(null);
        _navHeadingStreamController.add(null);
        try {
          _mapController.rotate(0);
        } catch (_) {}
      } else {
        final pos = _nav.vehiclePosition.value;
        if (pos != null) {
          _navPositionStreamController.add(
            LocationMarkerPosition(
              latitude: pos.latitude,
              longitude: pos.longitude,
              accuracy: 5,
            ),
          );
          _pushLocationMarkerHeading(pos);
        }
      }
      setState(() {});
    });
    _sensorHeadingSub = const LocationMarkerDataStreamFactory()
        .fromRotationSensorHeadingStream()
        .listen((heading) {
          if (heading == null) return;
          _deviceCompassHeading =
              ((heading.heading * 180.0 / math.pi) + 360.0) % 360.0;
          final pos = _nav.vehiclePosition.value;
          if (pos != null && _nav.navigating.value) {
            _pushLocationMarkerHeading(pos);
          }
        }, onError: (_) {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchRoute());
    _tdasRetryTimer = Timer.periodic(
      _kTdasRetryInterval,
      (_) => _refreshTdasIfNeeded(),
    );
    _routeRefreshTimer = Timer.periodic(
      _kRouteRefreshInterval,
      (_) => _refreshRouteIfNeeded(),
    );
    unawaited(_restoreStartSearchData());
    unawaited(_ensureStartSearchDatasets());
  }

  @override
  void dispose() {
    _nav.dispose();
    _sensorHeadingSub?.cancel();
    _navPositionStreamController.close();
    _navHeadingStreamController.close();
    _startGeocodingService.dispose();
    _tollService.dispose();
    _routeCardsController.dispose();
    _tdasRetryTimer?.cancel();
    _routeRefreshTimer?.cancel();
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  bool get _isPickingOnMap => _pickingStart || _pickingDestination;

  _MapPickTarget get _activeMapPickTarget =>
      _pickingDestination ? _MapPickTarget.destination : _MapPickTarget.start;

  LatLng _currentMapCenterForMapPicker() {
    try {
      return _mapController.camera.center;
    } catch (_) {
      return _manualOrigin ?? _origin ?? _destination;
    }
  }

  void _setDestination({
    required LatLng point,
    required String name,
    required String address,
    required parking.Carpark? carpark,
  }) {
    if (_nav.navigating.value) {
      _nav.stop();
    }
    _safeSetState(() {
      _destination = point;
      _destinationName = name;
      _destinationAddress = address;
      _destinationCarpark = carpark;
      _pickingStart = false;
      _pickingDestination = false;
    });
    _fetchRoute();
  }

  void _confirmPickFromMapCenter() {
    final center = _currentMapCenterForMapPicker();
    if (_activeMapPickTarget == _MapPickTarget.destination) {
      _setDestination(
        point: center,
        name: _formatLatLng(center),
        address: '',
        carpark: null,
      );
      return;
    }
    _safeSetState(() {
      _manualOrigin = center;
      _origin = center;
      _pickingStart = false;
      _pickingDestination = false;
    });
    _fetchRoute();
  }

  void _cancelPickOnMap() {
    _safeSetState(() {
      _pickingStart = false;
      _pickingDestination = false;
    });
  }

  double _distanceMeters(LatLng a, LatLng b) {
    return const Distance().as(LengthUnit.Meter, a, b);
  }

  double _bearingDegrees(LatLng a, LatLng b) {
    final lat1 = a.latitude * math.pi / 180.0;
    final lat2 = b.latitude * math.pi / 180.0;
    final dLon = (b.longitude - a.longitude) * math.pi / 180.0;
    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final brng = math.atan2(y, x) * 180.0 / math.pi;
    return (brng + 360.0) % 360.0;
  }

  double _normalizeHeading(double deg) => (deg % 360.0 + 360.0) % 360.0;

  double _angleDelta(double fromDeg, double toDeg) {
    var delta = (toDeg - fromDeg) % 360.0;
    if (delta > 180.0) delta -= 360.0;
    if (delta < -180.0) delta += 360.0;
    return delta;
  }

  double _blendHeadingDegrees(double fromDeg, double toDeg, double weightTo) {
    final t = weightTo.clamp(0.0, 1.0).toDouble();
    final blended = fromDeg + (_angleDelta(fromDeg, toDeg) * t);
    return _normalizeHeading(blended);
  }

  double _sensorWeightForSpeed(double speedMps) {
    if (speedMps <= 1.0) return 0.88;
    if (speedMps <= 4.0) return 0.72;
    if (speedMps <= 8.0) return 0.52;
    return 0.36;
  }

  double _headingAccuracyForSpeed(double speedMps) {
    if (speedMps <= 1.0) return 0.5;
    if (speedMps <= 4.0) return 0.35;
    return 0.2;
  }

  double? _routeForwardHeading(LatLng currentPosition) {
    final points = _routeResult?.points;
    if (points == null || points.length < 2) return null;
    var nearestIndex = 0;
    var nearestDistance = double.infinity;
    for (var i = 0; i < points.length; i++) {
      final d = _distanceMeters(currentPosition, points[i]);
      if (d < nearestDistance) {
        nearestDistance = d;
        nearestIndex = i;
      }
    }
    if (nearestIndex >= points.length - 1) {
      return _bearingDegrees(points[points.length - 2], points.last);
    }
    return _bearingDegrees(points[nearestIndex], points[nearestIndex + 1]);
  }

  double? _resolvedNavigationHeading(LatLng currentPosition) {
    final speedMps = (_nav.vehicleSpeedMps.value ?? 0.0)
        .clamp(0.0, 100.0)
        .toDouble();
    final sensorHeading =
        (_deviceCompassHeading != null && _deviceCompassHeading!.isFinite)
        ? _normalizeHeading(_deviceCompassHeading!)
        : null;
    final serviceHeading =
        (_nav.vehicleHeading.value != null &&
            _nav.vehicleHeading.value!.isFinite)
        ? _normalizeHeading(_nav.vehicleHeading.value!)
        : null;
    final fallbackHeading =
        (_fallbackVehicleHeading != null && _fallbackVehicleHeading!.isFinite)
        ? _normalizeHeading(_fallbackVehicleHeading!)
        : null;
    final routeHeading = _routeForwardHeading(currentPosition);
    final routeHeadingNorm = (routeHeading != null && routeHeading.isFinite)
        ? _normalizeHeading(routeHeading)
        : null;

    double? baseHeading = serviceHeading ?? fallbackHeading ?? routeHeadingNorm;
    if (baseHeading == null) {
      baseHeading = sensorHeading;
    } else if (sensorHeading != null) {
      baseHeading = _blendHeadingDegrees(
        baseHeading,
        sensorHeading,
        _sensorWeightForSpeed(speedMps),
      );
    }

    if (baseHeading == null) return null;

    final previous = _lastFusedHeadingDeg;
    if (previous != null && previous.isFinite) {
      final smoothingAlpha = speedMps > 8.0
          ? 0.92
          : speedMps > 4.0
          ? 0.82
          : 0.72;
      baseHeading = _blendHeadingDegrees(previous, baseHeading, smoothingAlpha);
    }
    return baseHeading;
  }

  void _pushLocationMarkerHeading(LatLng currentPosition) {
    final heading = _resolvedNavigationHeading(currentPosition);
    if (heading == null || !heading.isFinite) return;
    final previous = _lastFusedHeadingDeg;
    if (previous != null && _angleDelta(previous, heading).abs() < 0.5) {
      return;
    }
    _lastFusedHeadingDeg = heading;
    final speedMps = (_nav.vehicleSpeedMps.value ?? 0.0)
        .clamp(0.0, 100.0)
        .toDouble();
    _navHeadingStreamController.add(
      LocationMarkerHeading(
        heading: heading * math.pi / 180.0,
        accuracy: _headingAccuracyForSpeed(speedMps),
      ),
    );
  }

  void _moveCameraToNavigationPosition(
    LatLng pos, {
    bool forceZoom = false,
    double? headingDegrees,
  }) {
    double currentZoom;
    double currentRotation;
    try {
      currentZoom = _mapController.camera.zoom;
      currentRotation = _mapController.camera.rotation;
    } catch (_) {
      currentZoom = _NavigationScreenState._kNavigationZoom;
      currentRotation = 0;
    }
    final targetZoom = forceZoom
        ? _NavigationScreenState._kNavigationZoom
        : math.max(currentZoom, _NavigationScreenState._kNavigationZoom);
    final targetCameraRotation = headingDegrees == null
        ? currentRotation
        : (((-headingDegrees) % 360) + 360) % 360;
    try {
      _mapController.moveAndRotate(pos, targetZoom, targetCameraRotation);
    } catch (_) {
      _mapController.move(pos, targetZoom);
      try {
        _mapController.rotate(targetCameraRotation);
      } catch (_) {}
    }
  }

  void _refreshRouteIfNeeded() {
    if (!mounted || _loading) return;
    _fetchRoute(preserveCamera: _nav.navigating.value);
  }

  @override
  Widget build(BuildContext context) {
    final useDarkStatusText =
        ThemeData.estimateBrightnessForColor(widget.appBarColor) ==
        Brightness.light;
    final overlayStyle = useDarkStatusText
        ? SystemUiOverlayStyle.dark
        : SystemUiOverlayStyle.light;
    final resolvedStyle = widget.statusBarStyle ?? overlayStyle;
    final scaffold = Scaffold(
      backgroundColor: widget.backgroundColor,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _destination,
              initialZoom: 15,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: widget.tileUrlTemplate,
                subdomains: widget.tileSubdomains,
              ),
              if (widget.showHkSpeedMap)
                HkSpeedMapTileLayer(
                  source: widget.hkSpeedMapSource,
                  opacity: 0.6,
                ),
              CurrentLocationLayer(
                positionStream: _navPositionStreamController.stream,
                headingStream: _navHeadingStreamController.stream,
                alignPositionOnUpdate: _nav.navigating.value
                    ? AlignOnUpdate.always
                    : AlignOnUpdate.never,
                alignDirectionOnUpdate: _nav.navigating.value
                    ? AlignOnUpdate.always
                    : AlignOnUpdate.never,
                alignPositionAnimationDuration: const Duration(
                  milliseconds: 120,
                ),
                alignDirectionAnimationDuration: const Duration(
                  milliseconds: 100,
                ),
                moveAnimationDuration: const Duration(milliseconds: 120),
                rotateAnimationDuration: const Duration(milliseconds: 100),
                style: const LocationMarkerStyle(
                  marker: Icon(Icons.navigation, color: Colors.red, size: 36),
                  markerSize: Size(40, 40),
                  markerDirection: MarkerDirection.heading,
                  showHeadingSector: false,
                  showAccuracyCircle: false,
                ),
              ),
              if (_routes.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    for (int i = 0; i < _routes.length; i++)
                      Polyline(
                        points: _routes[i].points,
                        strokeWidth: i == _selectedRouteIndex ? 5 : 3,
                        color: i == _selectedRouteIndex
                            ? widget.accentColor
                            : widget.accentColor.withAlpha(
                                (0.35 * 255).round(),
                              ),
                      ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _destination,
                    width: 40,
                    height: 40,
                    child: Icon(
                      Icons.local_parking,
                      color: widget.accentColor,
                      size: 36,
                    ),
                  ),
                  if (_origin != null)
                    Marker(
                      point: _origin!,
                      width: 38,
                      height: 38,
                      child: Icon(
                        _manualOrigin != null ? Icons.flag : Icons.my_location,
                        color: widget.accentColor,
                        size: 32,
                      ),
                    ),
                ],
              ),
            ],
          ),
          _buildRouteHeaderOverlay(),
          _buildTopOverlay(),
          if (_isPickingOnMap)
            _buildMapPickerOverlay()
          else
            _buildRouteSheet(
              destinationName: _destinationName,
              destinationAddress: _destinationAddress,
            ),
        ],
      ),
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: resolvedStyle,
      child: scaffold,
    );
  }
}
