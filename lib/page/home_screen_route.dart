part of 'appmain.dart';

extension _HomeScreenRoute on _HomeScreenState {
  void _openParkingMainScreen() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ParkingMapScreen()));
  }

  void _openMeteredParkingScreen() {
    final theme = _mapThemes[_selectedTheme]!;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MeteredParkingScreen(
          themeConfig: theme,
          language: _language,
          initialCenter: _currentLocation ?? _HomeScreenState._defaultCenter,
        ),
      ),
    );
  }

  void _openNavigation(Carpark carpark) {
    unawaited(_pushNavigationScreen(carpark));
  }

  Future<void> _pushNavigationScreen(
    Carpark carpark, {
    bool autoStartNavigation = false,
  }) async {
    unawaited(_rememberRecentSearch(carpark));
    final theme = _mapThemes[_selectedTheme]!;
    final displayName = _carparkDisplayName(carpark);
    final displayAddress = _displayAddress(carpark);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NavigationScreen(
          carpark: carpark,
          carparkDisplayName: displayName,
          carparkDisplayAddress: displayAddress,
          osrmBaseUrl: _HomeScreenState._osrmBaseUrl,
          languageCode: _language.storageValue,
          initialManualOrigin: _routeStartOverride,
          initialTollTimeMode: _routeTollTimeMode,
          initialTollDateTime: _routeTollDateTime,
          initialVehicleType: _vehicleType,
          autoStartNavigation: autoStartNavigation,
          showHkSpeedMap: _showHkSpeedMap,
          hkSpeedMapSource: _hkSpeedMapSource,
          statusBarStyle: _selectedTheme == 'Dark'
              ? SystemUiOverlayStyle.light
              : (_selectedTheme == 'Light' || _selectedTheme == 'Standard'
                    ? SystemUiOverlayStyle.dark
                    : null),
          preferDarkSheetText: _selectedTheme == 'Standard',
          tileUrlTemplate: theme.urlTemplate,
          tileSubdomains: List<String>.from(theme.subdomains),
          accentColor: theme.accentColor,
          backgroundColor: theme.backgroundColor,
          appBarColor: theme.appBarColor,
          appBarForeground: theme.appBarForeground,
        ),
      ),
    );
    if (!mounted) return;
    _safeSetState(() {
      _routeStartOverride = null;
      _routeDestination = null;
      _pickingRouteStart = false;
      _pickingRouteDestination = false;
    });
  }

  void _openMeteredNavigation(MeteredStreetGroup group) {
    unawaited(_pushMeteredNavigationScreen(group));
  }

  Future<void> _pushMeteredNavigationScreen(MeteredStreetGroup group) async {
    final theme = _mapThemes[_selectedTheme]!;
    final displayName = _meteredStreetLabel(group);
    final displayAddress = _meteredDistrictLabel(group);
    final carpark = Carpark(
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
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NavigationScreen(
          carpark: carpark,
          carparkDisplayName: displayName,
          carparkDisplayAddress: displayAddress,
          osrmBaseUrl: _HomeScreenState._osrmBaseUrl,
          languageCode: _language.storageValue,
          initialManualOrigin: _routeStartOverride,
          initialTollTimeMode: _routeTollTimeMode,
          initialTollDateTime: _routeTollDateTime,
          initialVehicleType: _vehicleType,
          showHkSpeedMap: _showHkSpeedMap,
          hkSpeedMapSource: _hkSpeedMapSource,
          statusBarStyle: _selectedTheme == 'Dark'
              ? SystemUiOverlayStyle.light
              : (_selectedTheme == 'Light' || _selectedTheme == 'Standard'
                    ? SystemUiOverlayStyle.dark
                    : null),
          preferDarkSheetText: _selectedTheme == 'Standard',
          tileUrlTemplate: theme.urlTemplate,
          tileSubdomains: List<String>.from(theme.subdomains),
          accentColor: theme.accentColor,
          backgroundColor: theme.backgroundColor,
          appBarColor: theme.appBarColor,
          appBarForeground: theme.appBarForeground,
        ),
      ),
    );
    if (!mounted) return;
    _safeSetState(() {
      _routeStartOverride = null;
      _routeDestination = null;
      _pickingRouteStart = false;
      _pickingRouteDestination = false;
    });
  }
}
