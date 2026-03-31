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

class _NavigationScreenState extends State<NavigationScreen>
    with SingleTickerProviderStateMixin {
  static const double _kRouteSheetInitialSize = 0.32;
  static const double _kRouteSheetMinSize = 0.18;
  static const double _kRouteSheetMaxSize = 0.88;
  static const double _kCameraFitEdgePadding = 48;
  static const double _kNavigationZoom = 17.0;
  static const Duration _kTdasRetryInterval = Duration(seconds: 30);
  static const Duration _kRouteRefreshInterval = Duration(minutes: 1);

  final MapController _mapController = MapController();
  final PageController _routeCardsController = PageController(
    viewportFraction: 0.9,
  );
  late final AnimationController _cameraAnimationController;
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

  @override
  void initState() {
    super.initState();
    _manualOrigin = widget.initialManualOrigin;
    _origin = widget.initialManualOrigin;
    _tollTimeMode = widget.initialTollTimeMode;
    _tollDateTime = widget.initialTollTimeMode == TollTimeMode.now
        ? null
        : widget.initialTollDateTime;
    _vehicleType = widget.initialVehicleType;
    _pendingAutoStart = widget.autoStartNavigation;
    _cameraAnimationController = AnimationController(vsync: this);
    _api = routing.OsrmRouteApi(
      baseUrl: widget.osrmBaseUrl,
      profile: widget.profile,
    );
    _nav = NavigationService(languageCode: widget.languageCode);
    _nav.vehiclePosition.addListener(() {
      final pos = _nav.vehiclePosition.value;
      if (pos != null && _nav.navigating.value) {
        _moveCameraToNavigationPosition(pos);
      }
      setState(() {});
    });
    _nav.instructionText.addListener(() => setState(() {}));
    _nav.navigating.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchRoute());
    _tdasRetryTimer = Timer.periodic(
      _kTdasRetryInterval,
      (_) => _refreshTdasIfNeeded(),
    );
    _routeRefreshTimer = Timer.periodic(
      _kRouteRefreshInterval,
      (_) => _refreshRouteIfNeeded(),
    );
  }

  @override
  void dispose() {
    _nav.dispose();
    _tollService.dispose();
    _routeCardsController.dispose();
    _cameraAnimationController.dispose();
    _tdasRetryTimer?.cancel();
    _routeRefreshTimer?.cancel();
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  void _moveCameraToNavigationPosition(LatLng pos, {bool forceZoom = false}) {
    double currentZoom;
    try {
      currentZoom = _mapController.camera.zoom;
    } catch (_) {
      currentZoom = _NavigationScreenState._kNavigationZoom;
    }
    final targetZoom = forceZoom
        ? _NavigationScreenState._kNavigationZoom
        : math.max(currentZoom, _NavigationScreenState._kNavigationZoom);
    _mapController.move(pos, targetZoom);
  }

  Future<void> _animateCameraToNavigationPosition(
    LatLng pos, {
    bool forceZoom = false,
    Duration duration = const Duration(milliseconds: 850),
    Curve curve = Curves.easeOutCubic,
  }) async {
    late final MapCamera camera;
    try {
      camera = _mapController.camera;
    } catch (_) {
      _moveCameraToNavigationPosition(pos, forceZoom: forceZoom);
      return;
    }

    final startCenter = camera.center;
    final startZoom = camera.zoom;
    final targetZoom = forceZoom
        ? _NavigationScreenState._kNavigationZoom
        : math.max(startZoom, _NavigationScreenState._kNavigationZoom);

    final samePoint =
        (startCenter.latitude - pos.latitude).abs() < 0.000001 &&
        (startCenter.longitude - pos.longitude).abs() < 0.000001;
    if (samePoint && (startZoom - targetZoom).abs() < 0.001) {
      _moveCameraToNavigationPosition(pos, forceZoom: forceZoom);
      return;
    }

    final controller = _cameraAnimationController;
    controller.stop();
    controller.duration = duration;

    final curved = CurvedAnimation(parent: controller, curve: curve);
    final latTween = Tween<double>(
      begin: startCenter.latitude,
      end: pos.latitude,
    );
    final lngTween = Tween<double>(
      begin: startCenter.longitude,
      end: pos.longitude,
    );
    final zoomTween = Tween<double>(begin: startZoom, end: targetZoom);

    void listener() {
      if (!mounted) return;
      final lat = latTween.evaluate(curved);
      final lng = lngTween.evaluate(curved);
      final zoom = zoomTween.evaluate(curved);
      try {
        _mapController.move(LatLng(lat, lng), zoom);
      } catch (_) {}
    }

    curved.addListener(listener);
    try {
      controller.reset();
      await controller.forward();
    } on TickerCanceled {
      // Expected if a new camera animation interrupts the current one.
    } finally {
      curved.removeListener(listener);
    }
  }

  void _refreshRouteIfNeeded() {
    if (!mounted || _loading) return;
    _fetchRoute(preserveCamera: _nav.navigating.value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cp = widget.carpark;
    final useDarkStatusText =
        ThemeData.estimateBrightnessForColor(widget.appBarColor) ==
        Brightness.light;
    final overlayStyle = useDarkStatusText
        ? SystemUiOverlayStyle.dark
        : SystemUiOverlayStyle.light;
    final resolvedStyle = widget.statusBarStyle ?? overlayStyle;
    final displayName = (widget.carparkDisplayName?.isNotEmpty ?? false)
        ? widget.carparkDisplayName!
        : (cp.nameEn.isNotEmpty ? cp.nameEn : cp.nameTc);
    final displayAddress = (widget.carparkDisplayAddress?.isNotEmpty ?? false)
        ? widget.carparkDisplayAddress!
        : cp.fullAddress;
    final scaffold = Scaffold(
      backgroundColor: widget.backgroundColor,
      appBar: AppBar(
        toolbarHeight: 80,
        backgroundColor: widget.appBarColor,
        foregroundColor: widget.appBarForeground,
        systemOverlayStyle: resolvedStyle,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            InkWell(
              onTap: _showStartPicker,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(Icons.trip_origin, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _startHeaderLabel(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.place, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l10n.route_priorities,
            icon: const Icon(Icons.tune),
            onPressed: _showRoutePrioritiesPicker,
          ),
          IconButton(
            tooltip: l10n.route_again,
            icon: const Icon(Icons.alt_route),
            onPressed: _fetchRoute,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(cp.latitude, cp.longitude),
              initialZoom: 15,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onTap: (tapPos, latLng) {
                if (!_pickingStart) return;
                setState(() {
                  _manualOrigin = latLng;
                  _origin = latLng;
                  _pickingStart = false;
                });
                _fetchRoute();
              },
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
                    point: LatLng(cp.latitude, cp.longitude),
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
                  if (_nav.vehiclePosition.value != null &&
                      _nav.navigating.value)
                    Marker(
                      point: _nav.vehiclePosition.value!,
                      width: 44,
                      height: 44,
                      child: const Icon(
                        Icons.navigation,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                ],
              ),
            ],
          ),
          _buildTopOverlay(),
          _buildRouteSheet(
            destinationName: displayName,
            destinationAddress: displayAddress,
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
