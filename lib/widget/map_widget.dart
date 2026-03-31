part of '../page/appmain.dart';

extension _HomeScreenMap on _HomeScreenState {
  Future<void> _checkAndRequestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.location_permission_denied,
            ),
          ),
        );
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            )!.location_permission_permanently_denied,
          ),
        ),
      );
      return;
    }
    _getCurrentLocation();
  }

  Future<void> _moveCamera(LatLng target, {double? zoom}) async {
    if (!_showMap) return;
    if (!_mapIsReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _moveCamera(target, zoom: zoom);
      });
      return;
    }
    if (!mounted) return;
    double targetZoom;
    try {
      targetZoom = zoom ?? _mapController.camera.zoom;
    } catch (_) {
      targetZoom = zoom ?? 15.0;
    }
    try {
      _mapController.move(target, targetZoom);
    } catch (_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _moveCamera(target, zoom: targetZoom);
      });
    }
  }

  Future<void> _animateCamera(
    LatLng target, {
    double? zoom,
    Duration duration = const Duration(milliseconds: 350),
    Curve curve = Curves.easeInOut,
  }) async {
    if (!_showMap) return;
    if (!_mapIsReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _animateCamera(target, zoom: zoom, duration: duration, curve: curve);
      });
      return;
    }

    late final MapCamera camera;
    try {
      camera = _mapController.camera;
    } catch (_) {
      await _moveCamera(target, zoom: zoom);
      return;
    }

    final startCenter = camera.center;
    final startZoom = camera.zoom;
    final targetZoom = zoom ?? startZoom;

    final distance = math.sqrt(
      math.pow(startCenter.latitude - target.latitude, 2) +
          math.pow(startCenter.longitude - target.longitude, 2),
    );
    if (distance < 0.000001 && (startZoom - targetZoom).abs() < 0.001) {
      await _moveCamera(target, zoom: targetZoom);
      return;
    }

    final controller = _cameraAnimationController;
    controller.stop();
    controller.duration = duration;

    final curved = CurvedAnimation(parent: controller, curve: curve);

    final latTween = Tween<double>(
      begin: startCenter.latitude,
      end: target.latitude,
    );
    final lngTween = Tween<double>(
      begin: startCenter.longitude,
      end: target.longitude,
    );
    final zoomTween = Tween<double>(begin: startZoom, end: targetZoom);

    void listener() {
      if (!mounted) return;
      final lat = latTween.evaluate(curved);
      final lng = lngTween.evaluate(curved);
      final z = zoomTween.evaluate(curved);
      try {
        _mapController.move(LatLng(lat, lng), z);
      } catch (_) {
        // If move fails (e.g. map disposed), stop animation gracefully.
      }
    }

    curved.addListener(listener);

    try {
      controller.reset();
      await controller.forward();
    } on TickerCanceled {
      // Expected when a new animation starts before the previous one finishes.
    } finally {
      curved.removeListener(listener);
    }
  }

  Future<void> _resetMapRotation() async {
    if (!_showMap) return;
    if (!_mapIsReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _resetMapRotation();
      });
      return;
    }
    try {
      _mapController.rotate(0);
    } catch (_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _resetMapRotation();
      });
    }
  }

  // Get current location

  Future<void> _getCurrentLocation({bool recenter = true}) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final newLocation = LatLng(position.latitude, position.longitude);
      _safeSetState(() {
        _currentLocation = newLocation;
        _allCarparks = _sortCarparksForReference(_allCarparks, newLocation);
      });
      if (_searchLocationMarker != null) {
        _showNearbyCarparksOnMap(_searchLocationMarker!);
      } else {
        _safeSetState(() {
          _carparks = List<Carpark>.from(_allCarparks);
        });
      }
      if (recenter && _showMap) {
        await _moveCamera(newLocation, zoom: 15.0);
      }
      _prefetchNearbyCarparkImages(force: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.error_getting_location(e.toString()),
          ),
        ),
      );
    }
  }

  Future<void> _toggleLocationTracking() async {
    if (!_showMap) {
      unawaited(_getCurrentLocation(recenter: false));
      return;
    }
    final target = _currentLocation ?? _HomeScreenState._defaultCenter;
    final zoom = _currentLocation != null ? 15.0 : 11.0;

    await _animateCamera(target, zoom: zoom);
    await _resetMapRotation();
    unawaited(_getCurrentLocation());
  }

  // Load parking data from API

  Future<void> _loadCarparks({bool forceRefresh = false}) async {
    if (mounted) {
      _safeSetState(() {
        _isLoadingCarparks = true;
      });
    }

    try {
      final fetched = await ParkingApi.fetchCarparks(
        forceRefresh: forceRefresh,
      );
      if (kDebugMode) {
        debugPrint('HomeScreen: loaded ${fetched.length} carparks');
      }
      final pivot = _currentLocation ?? _HomeScreenState._defaultCenter;
      final sorted = _sortCarparksForReference(fetched, pivot);
      _safeSetState(() {
        _allCarparks = sorted;
        _carparks = List<Carpark>.from(sorted);
        _isLoadingCarparks = false;
      });
      _prefetchNearbyCarparkImages(force: true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('HomeScreen: _loadCarparks error -> $e');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.error_loading_carparks(e.toString()),
          ),
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: AppLocalizations.of(context)!.dismiss,
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        ),
      );
      _safeSetState(() {
        _isLoadingCarparks = false;
      });
    }
  }

  Future<void> _clearCarparkCacheAndReload() async {
    if (mounted) {
      _safeSetState(() {
        _isLoadingCarparks = true;
        _allCarparks = [];
        _carparks = [];
        _prefetchedCarparkIds.clear();
      });
    }
    await ParkingApi.clearCache();
    await _loadCarparks(forceRefresh: true);
  }

  void _centerMapOnCarpark(Carpark carpark) {
    _prefetchCarparkImage(carpark);
    if (!_showMap) return;
    final target = LatLng(carpark.latitude, carpark.longitude);
    final zoom = math.max(_currentZoom, 16.0);
    _mapController.move(target, zoom);
    _safeSetState(() {
      _currentZoom = zoom;
    });
    _prefetchCarparkImage(carpark);
    if (zoom >= 13) {
      _prefetchNearbyCarparkImages(force: true);
    }
  }

  double _calculateDistance(LatLng p1, LatLng p2) {
    final dx = p1.latitude - p2.latitude;
    final dy = p1.longitude - p2.longitude;
    return math.sqrt(dx * dx + dy * dy);
  }

  // Generate clusters or markers based on zoom level

  List<Marker> _generateMarkersOrClusters() {
    final accentColor = _mapThemes[_selectedTheme]?.accentColor ?? Colors.blue;
    final clusteringEnabled = _useClustering && !widget.hideParkingMarkers;
    // Zoom threshold: show individual markers when zoom >= 14
    if (_currentZoom >= 14 || !clusteringEnabled) {
      Marker buildMarker(Carpark carpark, LatLng point) {
        final markerColor = _resolveOpeningStatusColor(
          carpark.openingStatus,
          accentColor,
        );
        return Marker(
          point: point,
          width: 52,
          height: 52,
          child: GestureDetector(
            onTap: () {
              _skipNextMapTapSelection = true;
              _clearPendingMapSelection();
              if (_pickingRouteStart) {
                _selectMapRouteStart(
                  LatLng(carpark.latitude, carpark.longitude),
                );
                return;
              }
              if (_pickingRouteDestination) {
                _selectRouteDestinationCarpark(carpark);
                return;
              }
              final choices = _findOverlappingMarkerChoices(
                point,
                tappedCarpark: carpark,
              );
              if (choices.length <= 1) {
                _showCarparkDetails(carpark);
                return;
              }
              _showMarkerChoiceSheet(choices);
            },
            onLongPress: () {
              _skipNextMapTapSelection = true;
              _clearPendingMapSelection();
              final choices = _findOverlappingMarkerChoices(
                point,
                tappedCarpark: carpark,
              );
              if (choices.length > 1) {
                _showMarkerChoiceSheet(choices);
                return;
              }
              if (_pickingRouteStart) {
                _selectMapRouteStart(
                  LatLng(carpark.latitude, carpark.longitude),
                );
                return;
              }
              if (_pickingRouteDestination) {
                _selectRouteDestinationCarpark(carpark);
                return;
              }
              unawaited(_showMarkerRouteChoiceSheet(carpark));
            },
            child: Icon(Icons.local_parking, color: markerColor, size: 32),
          ),
        );
      }

      final grouped = <String, List<Carpark>>{};
      for (final carpark in _carparks) {
        final key =
            '${carpark.latitude.toStringAsFixed(6)},${carpark.longitude.toStringAsFixed(6)}';
        grouped.putIfAbsent(key, () => []).add(carpark);
      }

      final markers = <Marker>[];
      final radius = _duplicateMarkerRadius();
      for (final group in grouped.values) {
        if (group.length == 1) {
          final carpark = group.first;
          markers.add(
            buildMarker(carpark, LatLng(carpark.latitude, carpark.longitude)),
          );
          continue;
        }
        for (var i = 0; i < group.length; i++) {
          final carpark = group[i];
          final angle = (2 * math.pi * i) / group.length;
          final offsetLat = carpark.latitude + math.sin(angle) * radius;
          final offsetLng = carpark.longitude + math.cos(angle) * radius;
          markers.add(buildMarker(carpark, LatLng(offsetLat, offsetLng)));
        }
      }

      return markers;
    } else {
      // Create clusters
      return _createClusters();
    }
  }

  List<_MarkerChoiceItem> _findOverlappingMarkerChoices(
    LatLng tapPoint, {
    Carpark? tappedCarpark,
    MeteredStreetGroup? tappedMetered,
  }) {
    final camera = _mapController.camera;
    final tapOffset = camera.getOffsetFromOrigin(tapPoint);
    const radius = 20.0;
    const radiusSq = radius * radius;
    final items = <_MarkerChoiceItem>[];

    for (final carpark in _carparks) {
      final offset = camera.getOffsetFromOrigin(
        LatLng(carpark.latitude, carpark.longitude),
      );
      final dx = offset.dx - tapOffset.dx;
      final dy = offset.dy - tapOffset.dy;
      if ((dx * dx + dy * dy) <= radiusSq) {
        items.add(_carparkChoiceItem(carpark));
      }
    }

    if (_searchLocationMarker != null) {
      final dist = const Distance();
      final meterGroups = _visibleMeteredGroups()
          .where((group) {
            final d = dist(_searchLocationMarker!, group.center);
            return d <= _searchRadiusMeters;
          })
          .toList(growable: false);
      for (final group in meterGroups) {
        final offset = camera.getOffsetFromOrigin(group.center);
        final dx = offset.dx - tapOffset.dx;
        final dy = offset.dy - tapOffset.dy;
        if ((dx * dx + dy * dy) <= radiusSq) {
          items.add(_meteredChoiceItem(group));
        }
      }
    }

    if (tappedCarpark != null &&
        !items.any((item) => item.carpark?.id == tappedCarpark.id)) {
      items.add(_carparkChoiceItem(tappedCarpark));
    }
    if (tappedMetered != null &&
        !items.any((item) => item.meteredGroup?.key == tappedMetered.key)) {
      items.add(_meteredChoiceItem(tappedMetered));
    }

    return items;
  }

  Future<void> _loadMeteredGroups() async {
    try {
      final groups = await _meteredService.fetchStreetGroups(
        vehicleTypes: _HomeScreenState._meteredVehicleTypes,
      );
      if (!mounted) return;
      _safeSetState(() {
        _meteredGroups = groups;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('HomeScreen: _loadMeteredGroups error -> $e');
      }
    }
  }

  List<MeteredStreetGroup> _visibleMeteredGroups() {
    if (_meteredGroups.isEmpty) return const [];
    try {
      final bounds = _mapController.camera.visibleBounds;
      return _meteredGroups
          .where((group) {
            final lat = group.center.latitude;
            final lng = group.center.longitude;
            return lat >= bounds.south &&
                lat <= bounds.north &&
                lng >= bounds.west &&
                lng <= bounds.east;
          })
          .toList(growable: false);
    } catch (_) {
      return _meteredGroups;
    }
  }

  List<Marker> _buildMeteredMarkers() {
    if (_searchLocationMarker == null) return const [];
    final groups = _visibleMeteredGroups()
        .where((group) {
          final dist = const Distance();
          final d = dist(_searchLocationMarker!, group.center);
          return d <= _searchRadiusMeters;
        })
        .toList(growable: false);
    if (groups.isEmpty) return const [];
    return groups
        .map((group) {
          final markerColor = _resolveOpeningStatusColor(
            group.hasVacancy ? 'open' : 'closed',
            _mapThemes[_selectedTheme]?.accentColor ?? Colors.blue,
          );
          return Marker(
            point: group.center,
            width: 52,
            height: 52,
            child: GestureDetector(
              onTap: () {
                _skipNextMapTapSelection = true;
                _clearPendingMapSelection();
                if (_pickingRouteStart) {
                  _selectMapRouteStart(group.center);
                  return;
                }
                if (_pickingRouteDestination) {
                  _selectRouteDestinationMeteredGroup(group);
                  return;
                }
                final choices = _findOverlappingMarkerChoices(
                  group.center,
                  tappedMetered: group,
                );
                if (choices.length <= 1) {
                  _showMeteredGroupSheet(group);
                  return;
                }
                _showMarkerChoiceSheet(choices);
              },
              onLongPress: () {
                _skipNextMapTapSelection = true;
                _clearPendingMapSelection();
                final choices = _findOverlappingMarkerChoices(
                  group.center,
                  tappedMetered: group,
                );
                if (choices.length > 1) {
                  _showMarkerChoiceSheet(choices);
                  return;
                }
                if (_pickingRouteStart) {
                  _selectMapRouteStart(group.center);
                  return;
                }
                if (_pickingRouteDestination) {
                  _selectRouteDestinationMeteredGroup(group);
                  return;
                }
                unawaited(_showMeteredMarkerRouteChoiceSheet(group));
              },
              child: Center(
                child: Text(
                  'M',
                  style: TextStyle(
                    color: markerColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 32,
                  ),
                ),
              ),
            ),
          );
        })
        .toList(growable: false);
  }

  // Create clusters based on proximity

  List<Marker> _createClusters() {
    if (_carparks.isEmpty) return [];

    // Adjust cluster radius based on zoom level
    double clusterRadius = _getClusterRadius();
    final accentColor = _mapThemes[_selectedTheme]?.accentColor ?? Colors.blue;

    List<List<Carpark>> clusters = [];
    List<bool> clustered = List.filled(_carparks.length, false);

    for (int i = 0; i < _carparks.length; i++) {
      if (clustered[i]) continue;

      List<Carpark> cluster = [_carparks[i]];
      clustered[i] = true;

      for (int j = i + 1; j < _carparks.length; j++) {
        if (clustered[j]) continue;

        double distance = _calculateDistance(
          LatLng(_carparks[i].latitude, _carparks[i].longitude),
          LatLng(_carparks[j].latitude, _carparks[j].longitude),
        );

        if (distance <= clusterRadius) {
          cluster.add(_carparks[j]);
          clustered[j] = true;
        }
      }

      clusters.add(cluster);
    }

    // Create cluster markers
    return clusters.map((cluster) {
      // Calculate center of cluster
      double avgLat =
          cluster.map((c) => c.latitude).reduce((a, b) => a + b) /
          cluster.length;
      double avgLon =
          cluster.map((c) => c.longitude).reduce((a, b) => a + b) /
          cluster.length;

      return Marker(
        point: LatLng(avgLat, avgLon),
        width: 60,
        height: 60,
        child: GestureDetector(
          onTap: () {
            // Zoom in to the cluster
            _mapController.move(
              LatLng(avgLat, avgLon),
              math.min(_currentZoom + 2, 18),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.72),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.8),
                width: 3,
              ),
            ),
            child: Center(
              child: Text(
                '${cluster.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  // Get cluster radius based on zoom level

  double _getClusterRadius() {
    if (_currentZoom >= 13) return 0.01;
    if (_currentZoom >= 12) return 0.02;
    if (_currentZoom >= 11) return 0.04;
    if (_currentZoom >= 10) return 0.08;
    return 0.15;
  }

  double _duplicateMarkerRadius() {
    if (_currentZoom >= 16) return 0.00005;
    if (_currentZoom >= 14) return 0.0001;
    return 0.00015;
  }

  List<Carpark> _sortCarparksForReference(
    Iterable<Carpark> source,
    LatLng reference,
  ) {
    final sorted = List<Carpark>.from(source, growable: true);
    sorted.sort(
      (a, b) => _distanceToCarpark(
        reference,
        a,
      ).compareTo(_distanceToCarpark(reference, b)),
    );
    return sorted;
  }

  double _distanceToCarpark(LatLng origin, Carpark carpark) {
    return _calculateDistance(
      origin,
      LatLng(carpark.latitude, carpark.longitude),
    );
  }

  void _prefetchNearbyCarparkImages({int limit = 6, bool force = false}) {
    if (!mounted || _carparks.isEmpty) return;
    if (!force && _currentZoom < 13) return;

    late final LatLng center;
    try {
      center = _mapController.camera.center;
    } catch (_) {
      center = _currentLocation ?? _HomeScreenState._defaultCenter;
    }

    if (!force && _lastPrefetchCenter != null) {
      final delta = _calculateDistance(center, _lastPrefetchCenter!);
      if (delta < 0.005) {
        return;
      }
    }
    _lastPrefetchCenter = center;

    final prioritized = _sortCarparksForReference(_carparks, center);
    int prefetched = 0;
    for (final carpark in prioritized) {
      if (carpark.photoUrl == null || carpark.photoUrl!.isEmpty) continue;
      if (_prefetchedCarparkIds.contains(carpark.id)) continue;
      _prefetchCarparkImage(carpark);
      prefetched++;
      if (prefetched >= limit) break;
    }
  }

  void _prefetchCarparkImage(Carpark carpark) {
    final url = carpark.photoUrl;
    if (url == null || url.isEmpty) return;
    if (_prefetchedCarparkIds.contains(carpark.id)) return;
    _prefetchedCarparkIds.add(carpark.id);
    Future(() async {
      if (!mounted) return;
      try {
        await precacheImage(NetworkImage(url), context);
      } catch (_) {
        // Swallow errors: failing to prefetch should not break UI flow.
      }
    });
  }

  void _handleMapEvent(MapEvent event) {
    if (!_showMap) return;
    final zoom = event.camera.zoom;
    final zoomChanged = (zoom - _currentZoom).abs() >= 0.1;

    if (zoomChanged && event is MapEventWithMove) {
      _safeSetState(() {
        _currentZoom = zoom;
      });
      if (kDebugMode) {
        debugPrint('Map zoom: ${_currentZoom.toStringAsFixed(2)}');
      }
      if (zoom >= 13) {
        _prefetchNearbyCarparkImages();
      }
      _scheduleHkSpeedWideBuffer();
    }

    if (event is MapEventMoveEnd) {
      final center = event.camera.center;
      final last = _lastPrefetchCenter;
      final movedEnough =
          last == null || _calculateDistance(center, last) >= 0.01;
      if (movedEnough && _currentZoom >= 13) {
        _prefetchNearbyCarparkImages();
      }
      _scheduleHkSpeedWideBuffer(expandAfterDelay: true);
    }
  }

  void _adjustZoom(double delta) {
    if (!_showMap) return;
    final center = _mapController.camera.center;
    final newZoom = (_mapController.camera.zoom + delta).clamp(0.0, 18.0);
    _mapController.move(center, newZoom);
  }

  void _scheduleHkSpeedWideBuffer({bool expandAfterDelay = false}) {
    if (!_showHkSpeedMap) return;
    if (!expandAfterDelay) {
      _hkSpeedWideBufferTimer?.cancel();
      if (_hkSpeedWideBuffer) {
        _safeSetState(() {
          _hkSpeedWideBuffer = false;
        });
      }
      return;
    }
    _hkSpeedWideBufferTimer?.cancel();
    _hkSpeedWideBufferTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted || !_showHkSpeedMap) return;
      if (_hkSpeedWideBuffer) return;
      _safeSetState(() {
        _hkSpeedWideBuffer = true;
      });
    });
  }
}
