import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:parking_app/config/api_config.dart';
import 'package:parking_app/l10n/app_localizations.dart';
import 'package:parking_app/manager/language_manager.dart';
import 'package:parking_app/manager/map_theme_manager.dart';
import 'package:parking_app/network/metered_parking_service.dart';
import 'package:parking_app/network/parking_api.dart';
import 'package:parking_app/network/toll_service.dart';
import 'package:parking_app/network/vacancy_prediction_service.dart';
import 'package:parking_app/page/navigation_screen.dart';
import 'package:parking_app/page/open_screen.dart';
import 'package:parking_app/page/settings.dart';
import 'package:parking_app/widget/hk_speed_map_layer.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _RoutePickAction { start, destination }

class MeteredParkingScreen extends StatefulWidget {
  const MeteredParkingScreen({
    super.key,
    required this.themeConfig,
    required this.language,
    this.initialCenter,
  });

  final MapThemeConfig themeConfig;
  final AppLanguage language;
  final LatLng? initialCenter;

  @override
  State<MeteredParkingScreen> createState() => _MeteredParkingScreenState();
}

class _MeteredParkingScreenState extends State<MeteredParkingScreen> {
  static const String _osrmBaseUrl = ApiConfig.osrmBaseUrl;
  static const String _themePrefKey = 'selectedTheme';
  static const String _languagePrefKey = 'selectedLanguage';
  static const String _vehicleTypePrefKey = 'selectedVehicleType';
  static const String _hkSpeedMapSourcePrefKey = 'hkSpeedMapSource';
  static const String _recentMeteredPrefKey = 'recentMeteredSearches';
  static const String _recentCombinedPrefKey = 'recentSearchCombined';
  static const int _maxRecentMetered = 10;
  static const int _maxCombinedRecentSearches = 20;
  static const int _maxVisibleGroups = 200;

  final MapController _mapController = MapController();
  final MeteredParkingService _service = MeteredParkingService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late MapThemeConfig _themeConfig;
  late AppLanguage _language;
  late String _selectedThemeKey;
  bool _useClustering = true;
  bool _showHkSpeedMap = false;
  HkSpeedMapSource _hkSpeedMapSource = HkSpeedMapSource.standard;
  HkVehicleType _vehicleType = HkVehicleType.privateCar;
  List<MeteredStreetGroup> _groups = const [];
  List<MeteredStreetGroup> _visibleGroups = const [];
  LatLng? _routeStartOverride;
  Carpark? _routeDestination;
  final Set<String> _selectedVehicleTypes = const {'A'};
  List<String> _recentMeteredKeys = const [];
  bool _loading = true;
  String? _error;
  Timer? _refreshDebounce;
  double _currentZoom = 13;
  final Map<String, MapThemeConfig> _mapThemes = {
    'Standard': const MapThemeConfig(
      label: 'Default',
      urlTemplate: ApiConfig.cartoVoyagerTileUrl,
      subdomains: ['a', 'b', 'c', 'd'],
      appBarColor: Color(0xFF1565C0),
      appBarForeground: Colors.white,
      accentColor: Color(0xFF1976D2),
      backgroundColor: Color.fromARGB(255, 255, 255, 255),
    ),
    'Dark': const MapThemeConfig(
      label: 'Night Drive',
      urlTemplate: ApiConfig.cartoDarkTileUrl,
      subdomains: ['a', 'b', 'c', 'd'],
      appBarColor: Color(0xFF101820),
      appBarForeground: Colors.white,
      accentColor: Color.fromARGB(255, 173, 175, 175),
      backgroundColor: Color(0xFF0F1117),
    ),
    'Light': const MapThemeConfig(
      label: 'Clean Atlas',
      urlTemplate: ApiConfig.cartoLightTileUrl,
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
    _selectedThemeKey = _mapThemes.keys.first;
    _themeConfig = _mapThemes[_selectedThemeKey]!;
    _language = widget.language;
    _restoreRecentMeteredSearches();
    _restoreThemePreference();
    _restoreLanguagePreference();
    _restoreVehicleTypePreference();
    _restoreHkSpeedMapSourcePreference();
    _load();
    _getCurrentLocation(recenter: false);
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final groups = await _service.fetchStreetGroups(
        vehicleTypes: _selectedVehicleTypes,
      );
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _visibleGroups = groups;
        _loading = false;
      });
      _refreshVisibleGroups();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _restoreRecentMeteredSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys =
          prefs.getStringList(_recentMeteredPrefKey) ?? const <String>[];
      if (!mounted) return;
      setState(() => _recentMeteredKeys = keys);
    } catch (_) {}
  }

  Future<void> _saveRecentMeteredSearches(List<String> keys) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_recentMeteredPrefKey, keys);
    } catch (_) {}
  }

  Future<void> _rememberRecentMeteredSearch(MeteredStreetGroup group) async {
    final next = <String>[
      group.key,
      ..._recentMeteredKeys,
    ].where((key) => key.isNotEmpty).toList(growable: false);
    final unique = <String>[];
    final seen = <String>{};
    for (final key in next) {
      if (!seen.add(key)) continue;
      unique.add(key);
      if (unique.length >= _maxRecentMetered) break;
    }
    if (!mounted) return;
    setState(() => _recentMeteredKeys = unique);
    await _saveRecentMeteredSearches(unique);
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing =
          prefs.getStringList(_recentCombinedPrefKey) ?? const <String>[];
      final nextCombined = <String>[
        'm:${group.key}',
        ...existing,
      ].where((entry) => entry.isNotEmpty).toList(growable: false);
      final uniqueCombined = <String>[];
      final seenCombined = <String>{};
      for (final entry in nextCombined) {
        if (!seenCombined.add(entry)) continue;
        uniqueCombined.add(entry);
        if (uniqueCombined.length >= _maxCombinedRecentSearches) break;
      }
      await prefs.setStringList(_recentCombinedPrefKey, uniqueCombined);
    } catch (_) {}
  }

  Future<void> _clearRecentMeteredSearches() async {
    if (!mounted) return;
    setState(() => _recentMeteredKeys = const []);
    await _saveRecentMeteredSearches(const []);
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing =
          prefs.getStringList(_recentCombinedPrefKey) ?? const <String>[];
      final filtered = existing
          .where((entry) => !entry.startsWith('m:'))
          .toList(growable: false);
      await prefs.setStringList(_recentCombinedPrefKey, filtered);
    } catch (_) {}
  }

  String _authText({
    required String en,
    required String zhHant,
    required String zhHans,
  }) {
    switch (_language) {
      case AppLanguage.english:
        return en;
      case AppLanguage.traditionalChinese:
        return zhHant;
      case AppLanguage.simplifiedChinese:
        return zhHans;
    }
  }

  void _showAuthSnack({
    required String en,
    required String zhHant,
    required String zhHans,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_authText(en: en, zhHant: zhHant, zhHans: zhHans)),
      ),
    );
  }

  void _showEmailSignInError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        _showAuthSnack(
          en: 'Invalid email format.',
          zhHant: '電郵格式無效。',
          zhHans: '电邮格式无效。',
        );
        return;
      case 'invalid-credential':
        _showAuthSnack(
          en: 'Email/password is incorrect, or this email uses another provider (for example Google).',
          zhHant: '電郵或密碼不正確，或此電郵使用其他登入方式（例如 Google）。',
          zhHans: '电邮或密码不正确，或此电邮使用其他登录方式（例如 Google）。',
        );
        return;
      case 'user-disabled':
        _showAuthSnack(
          en: 'This account has been disabled.',
          zhHant: '此帳戶已被停用。',
          zhHans: '此账户已被停用。',
        );
        return;
      case 'too-many-requests':
        _showAuthSnack(
          en: 'Too many attempts. Please try again later.',
          zhHant: '嘗試次數過多，請稍後再試。',
          zhHans: '尝试次数过多，请稍后再试。',
        );
        return;
      default:
        _showAuthSnack(
          en: 'Email sign-in failed: ${e.message ?? e.code}',
          zhHant: '電郵登入失敗：${e.message ?? e.code}',
          zhHans: '电邮登录失败：${e.message ?? e.code}',
        );
    }
  }

  Future<void> _signInWithEmail(String email, String password) async {
    final normalized = email.trim();
    if (normalized.isEmpty || password.isEmpty) {
      _showAuthSnack(
        en: 'Please enter both email and password.',
        zhHant: '請輸入電郵及密碼。',
        zhHans: '请输入电邮及密码。',
      );
      return;
    }
    final auth = FirebaseAuth.instance;
    final currentUser = auth.currentUser;
    try {
      if (currentUser != null) {
        final currentEmail = (currentUser.email ?? '').trim().toLowerCase();
        if (currentEmail.isNotEmpty &&
            currentEmail != normalized.toLowerCase()) {
          _showAuthSnack(
            en: 'Sign out first before signing in with another email account.',
            zhHant: '請先登出，再用另一個電郵帳戶登入。',
            zhHans: '请先登出，再用另一个电邮账户登录。',
          );
          return;
        }

        final credential = EmailAuthProvider.credential(
          email: normalized,
          password: password,
        );
        await currentUser.linkWithCredential(credential);
        _showAuthSnack(
          en: 'Email/password linked to current account.',
          zhHant: '已把電郵/密碼連結到目前帳戶。',
          zhHans: '已把电邮/密码关联到当前账户。',
        );
        if (!mounted) return;
        setState(() {});
        return;
      }

      await auth.signInWithEmailAndPassword(
        email: normalized,
        password: password,
      );
      if (!mounted) return;
      setState(() {});
      _showAuthSnack(
        en: 'Signed in with email.',
        zhHant: '已使用電郵登入。',
        zhHans: '已使用电邮登录。',
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'provider-already-linked') {
        _showAuthSnack(
          en: 'Email/password is already linked.',
          zhHant: '電郵/密碼已連結。',
          zhHans: '电邮/密码已关联。',
        );
        return;
      }
      _showEmailSignInError(e);
    } catch (e) {
      _showAuthSnack(
        en: 'Email sign-in failed: $e',
        zhHant: '電郵登入失敗：$e',
        zhHans: '电邮登录失败：$e',
      );
    }
  }

  Future<void> _registerWithEmail(String email, String password) async {
    final normalized = email.trim();
    if (normalized.isEmpty || password.isEmpty) {
      _showAuthSnack(
        en: 'Please enter both email and password.',
        zhHant: '請輸入電郵及密碼。',
        zhHans: '请输入电邮及密码。',
      );
      return;
    }

    final auth = FirebaseAuth.instance;
    final currentUser = auth.currentUser;
    final credential = EmailAuthProvider.credential(
      email: normalized,
      password: password,
    );

    try {
      if (currentUser != null) {
        final currentEmail = (currentUser.email ?? '').trim().toLowerCase();
        if (currentEmail.isNotEmpty &&
            currentEmail != normalized.toLowerCase()) {
          _showAuthSnack(
            en: 'Sign out first before linking a different email account.',
            zhHant: '請先登出，才可連結其他電郵帳戶。',
            zhHans: '请先登出，才可关联其他电邮账户。',
          );
          return;
        }

        await currentUser.linkWithCredential(credential);
        _showAuthSnack(
          en: 'Email/password linked to current account.',
          zhHant: '已把電郵/密碼連結到目前帳戶。',
          zhHans: '已把电邮/密码关联到当前账户。',
        );
      } else {
        await auth.createUserWithEmailAndPassword(
          email: normalized,
          password: password,
        );
        _showAuthSnack(
          en: 'Account created with email/password.',
          zhHant: '已建立電郵/密碼帳戶。',
          zhHans: '已建立电邮/密码账户。',
        );
      }
      if (!mounted) return;
      setState(() {});
    } on FirebaseAuthException catch (e) {
      if (e.code == 'provider-already-linked') {
        _showAuthSnack(
          en: 'Email/password is already linked.',
          zhHant: '電郵/密碼已連結。',
          zhHans: '电邮/密码已关联。',
        );
        return;
      }
      if (e.code == 'email-already-in-use' ||
          e.code == 'credential-already-in-use') {
        await _signInWithEmail(normalized, password);
        return;
      }
      _showAuthSnack(
        en: 'Email registration failed: ${e.message ?? e.code}',
        zhHant: '電郵註冊失敗：${e.message ?? e.code}',
        zhHans: '电邮注册失败：${e.message ?? e.code}',
      );
    } catch (e) {
      _showAuthSnack(
        en: 'Email registration failed: $e',
        zhHant: '電郵註冊失敗：$e',
        zhHans: '电邮注册失败：$e',
      );
    }
  }

  Future<void> _signInWithGoogle() async {
    final auth = FirebaseAuth.instance;
    try {
      if (kIsWeb) {
        await auth.signInWithPopup(GoogleAuthProvider());
      } else {
        final googleSignIn = GoogleSignIn.instance;
        await googleSignIn.initialize();
        GoogleSignInAccount user;
        try {
          user = await googleSignIn.authenticate();
        } on GoogleSignInException catch (e) {
          final desc = (e.description ?? '').toLowerCase();
          if (e.code == GoogleSignInExceptionCode.canceled &&
              desc.contains('reauth')) {
            await googleSignIn.signOut();
            user = await googleSignIn.authenticate();
          } else {
            rethrow;
          }
        }
        final credential = GoogleAuthProvider.credential(
          idToken: user.authentication.idToken,
        );
        final currentUser = auth.currentUser;
        if (currentUser == null) {
          await auth.signInWithCredential(credential);
        } else {
          await currentUser.linkWithCredential(credential);
          _showAuthSnack(
            en: 'Google account linked.',
            zhHant: '已連結 Google 帳戶。',
            zhHans: '已关联 Google 账户。',
          );
        }
      }
      if (!mounted) return;
      setState(() {});
    } on FirebaseAuthException catch (e) {
      if (e.code == 'provider-already-linked') {
        _showAuthSnack(
          en: 'Google account is already linked.',
          zhHant: 'Google 帳戶已連結。',
          zhHans: 'Google 账户已关联。',
        );
        return;
      }
      if (e.code == 'account-exists-with-different-credential') {
        _showAuthSnack(
          en: 'This email already uses a different sign-in method. Sign in with email/password first, then link Google.',
          zhHant: '此電郵已使用其他登入方式。請先用電郵/密碼登入，再連結 Google。',
          zhHans: '此电邮已使用其他登录方式。请先用电邮/密码登录，再关联 Google。',
        );
        return;
      }
      _showAuthSnack(
        en: 'Google sign-in failed: ${e.message ?? e.code}',
        zhHant: 'Google 登入失敗：${e.message ?? e.code}',
        zhHans: 'Google 登录失败：${e.message ?? e.code}',
      );
    } catch (e) {
      _showAuthSnack(
        en: 'Google sign-in failed: $e',
        zhHant: 'Google 登入失敗：$e',
        zhHans: 'Google 登录失败：$e',
      );
    }
  }

  Future<void> _signOutGoogle() async {
    try {
      if (!kIsWeb) {
        await GoogleSignIn.instance.signOut();
      }
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      setState(() {});
      _showAuthSnack(en: 'Signed out.', zhHant: '已登出。', zhHans: '已登出。');
    } catch (e) {
      _showAuthSnack(
        en: 'Sign-out failed: $e',
        zhHant: '登出失敗：$e',
        zhHans: '登出失败：$e',
      );
    }
  }

  List<MeteredStreetGroup> _resolveRecentGroups() {
    if (_recentMeteredKeys.isEmpty || _groups.isEmpty) return const [];
    final map = <String, MeteredStreetGroup>{
      for (final group in _groups) group.key: group,
    };
    final out = <MeteredStreetGroup>[];
    for (final key in _recentMeteredKeys) {
      final group = map[key];
      if (group != null) out.add(group);
    }
    return out;
  }

  String _streetLabel(MeteredStreetGroup group) {
    String street;
    String section;
    switch (_language) {
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

  String _districtLabel(MeteredStreetGroup group) {
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

  String _streetLabelFor(MeteredStreetGroup group, AppLanguage language) {
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

  void _openNavigationForMetered(MeteredStreetGroup group) {
    _openNavigationForCarpark(
      _meteredGroupAsCarpark(group),
      _streetLabel(group),
      _districtLabel(group),
    );
  }

  void _openNavigationForCarpark(
    Carpark carpark,
    String displayName,
    String displayAddress,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NavigationScreen(
          carpark: carpark,
          carparkDisplayName: displayName,
          carparkDisplayAddress: displayAddress,
          osrmBaseUrl: _osrmBaseUrl,
          languageCode: _language.storageValue,
          initialManualOrigin: _routeStartOverride,
          initialVehicleType: HkVehicleType.privateCar,
          showHkSpeedMap: _showHkSpeedMap,
          hkSpeedMapSource: _hkSpeedMapSource,
          tileUrlTemplate: _themeConfig.urlTemplate,
          tileSubdomains: List<String>.from(_themeConfig.subdomains),
          accentColor: _themeConfig.accentColor,
          backgroundColor: _themeConfig.backgroundColor,
          appBarColor: _themeConfig.appBarColor,
          appBarForeground: _themeConfig.appBarForeground,
        ),
      ),
    );
  }

  Carpark _meteredGroupAsCarpark(MeteredStreetGroup group) {
    return Carpark(
      id: 'metered:${group.key}',
      nameEn: _streetLabelFor(group, AppLanguage.english),
      nameTc: _streetLabelFor(group, AppLanguage.traditionalChinese),
      nameSc: _streetLabelFor(group, AppLanguage.simplifiedChinese),
      addressEn: group.districtEn,
      addressTc: group.districtTc,
      addressSc: group.districtSc,
      latitude: group.center.latitude,
      longitude: group.center.longitude,
      operatorName: 'Metered',
    );
  }

  Carpark _manualPointAsCarpark(LatLng latLng) {
    final coords =
        '${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}';
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

  void _openNavigationIfRouteReady() {
    final destination = _routeDestination;
    if (destination == null || _routeStartOverride == null) return;
    _openNavigationForCarpark(
      destination,
      _displayNameForCarpark(destination),
      _displayAddressForCarpark(destination),
    );
  }

  String _displayNameForCarpark(Carpark carpark) {
    switch (_language) {
      case AppLanguage.english:
        return carpark.nameEn.isNotEmpty ? carpark.nameEn : carpark.id;
      case AppLanguage.traditionalChinese:
        return carpark.nameTc.isNotEmpty ? carpark.nameTc : carpark.nameEn;
      case AppLanguage.simplifiedChinese:
        return carpark.nameSc.isNotEmpty ? carpark.nameSc : carpark.nameEn;
    }
  }

  String _displayAddressForCarpark(Carpark carpark) {
    switch (_language) {
      case AppLanguage.english:
        return carpark.addressEn;
      case AppLanguage.traditionalChinese:
        return carpark.addressTc.isNotEmpty
            ? carpark.addressTc
            : carpark.addressEn;
      case AppLanguage.simplifiedChinese:
        return carpark.addressSc.isNotEmpty
            ? carpark.addressSc
            : carpark.addressEn;
    }
  }

  String _destinationLabel() {
    switch (_language) {
      case AppLanguage.english:
        return 'Set as destination';
      case AppLanguage.traditionalChinese:
        return '設為目的地';
      case AppLanguage.simplifiedChinese:
        return '设为目的地';
    }
  }

  Future<void> _showRouteChoiceForMetered(MeteredStreetGroup group) async {
    final l10n = AppLocalizations.of(context)!;
    final action = await showModalBottomSheet<_RoutePickAction>(
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
              ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(_destinationLabel()),
                subtitle: Text(_streetLabel(group)),
                onTap: () => Navigator.of(
                  sheetContext,
                ).pop(_RoutePickAction.destination),
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(l10n.choose_start_point),
                subtitle: Text(_streetLabel(group)),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_RoutePickAction.start),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (!mounted || action == null) return;
    if (action == _RoutePickAction.start) {
      setState(() {
        _routeStartOverride = group.center;
      });
      _openNavigationIfRouteReady();
      return;
    }
    setState(() {
      _routeDestination = _meteredGroupAsCarpark(group);
    });
    _openNavigationIfRouteReady();
  }

  Future<void> _showMapRouteChoice(LatLng latLng) async {
    final l10n = AppLocalizations.of(context)!;
    final action = await showModalBottomSheet<_RoutePickAction>(
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
              ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(_destinationLabel()),
                subtitle: Text(
                  '${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}',
                ),
                onTap: () => Navigator.of(
                  sheetContext,
                ).pop(_RoutePickAction.destination),
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(l10n.choose_start_point),
                subtitle: Text(
                  '${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}',
                ),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_RoutePickAction.start),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (!mounted || action == null) return;
    if (action == _RoutePickAction.start) {
      setState(() => _routeStartOverride = latLng);
      _openNavigationIfRouteReady();
      return;
    }
    setState(() => _routeDestination = _manualPointAsCarpark(latLng));
    _openNavigationIfRouteReady();
  }

  List<Marker> _buildGroupMarkers(Color accentColor) {
    final useClustering = _useClustering && _currentZoom < 14;
    final groups = _visibleGroups;
    if (useClustering) {
      final clusters = _clusterGroups(groups);
      return clusters
          .map((cluster) {
            if (cluster.length == 1) {
              final group = cluster.first;
              final color = group.hasVacancy ? Colors.blue : Colors.red;
              return _buildSingleMarker(group, color);
            }
            final center = _clusterCenter(cluster);
            return Marker(
              point: center,
              width: 52,
              height: 52,
              child: GestureDetector(
                onTap: () {
                  _mapController.move(center, math.min(_currentZoom + 3, 18));
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
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            );
          })
          .toList(growable: false);
    }
    return groups
        .map((group) {
          final color = group.hasVacancy ? Colors.blue : Colors.red;
          return _buildSingleMarker(group, color);
        })
        .toList(growable: false);
  }

  Marker _buildSingleMarker(MeteredStreetGroup group, Color color) {
    return Marker(
      point: group.center,
      width: 36,
      height: 36,
      child: GestureDetector(
        onTap: () => _showGroupSheet(group),
        onLongPress: () {
          unawaited(_showRouteChoiceForMetered(group));
        },
        child: Icon(Icons.local_parking, color: color, size: 30),
      ),
    );
  }

  double _calculateDistance(LatLng p1, LatLng p2) {
    final dx = p1.latitude - p2.latitude;
    final dy = p1.longitude - p2.longitude;
    return math.sqrt(dx * dx + dy * dy);
  }

  double _getClusterRadius() {
    if (_currentZoom >= 14) return 0.008;
    if (_currentZoom >= 13) return 0.015;
    if (_currentZoom >= 12) return 0.03;
    if (_currentZoom >= 11) return 0.06;
    return 0.1;
  }

  List<List<MeteredStreetGroup>> _clusterGroups(
    List<MeteredStreetGroup> groups,
  ) {
    if (groups.isEmpty) return const [];
    final clusterRadius = _getClusterRadius();
    final clusters = <List<MeteredStreetGroup>>[];
    final clustered = List<bool>.filled(groups.length, false);

    for (var i = 0; i < groups.length; i++) {
      if (clustered[i]) continue;
      final cluster = <MeteredStreetGroup>[groups[i]];
      clustered[i] = true;

      for (var j = i + 1; j < groups.length; j++) {
        if (clustered[j]) continue;
        final distance = _calculateDistance(groups[i].center, groups[j].center);
        if (distance <= clusterRadius) {
          cluster.add(groups[j]);
          clustered[j] = true;
        }
      }
      clusters.add(cluster);
    }
    return clusters;
  }

  LatLng _clusterCenter(List<MeteredStreetGroup> cluster) {
    final avgLat =
        cluster.map((g) => g.center.latitude).reduce((a, b) => a + b) /
        cluster.length;
    final avgLng =
        cluster.map((g) => g.center.longitude).reduce((a, b) => a + b) /
        cluster.length;
    return LatLng(avgLat, avgLng);
  }

  void _showGroupSheet(MeteredStreetGroup group) {
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
      backgroundColor: _themeConfig.backgroundColor,
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
                        color: _themeConfig.accentColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.local_parking,
                        color: _themeConfig.accentColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _streetLabel(group),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _districtLabel(group),
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
                    color: _themeConfig.accentColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Text(
                        l10n.metered_vacant,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: _themeConfig.accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${group.vacant}/${group.total}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: _themeConfig.accentColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _vehicleLabel(group.vehicleType, l10n),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: _themeConfig.accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FutureBuilder<MeterVacancyForecast?>(
                  future: predictionFuture,
                  builder: (sheetContext, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _themeConfig.accentColor.withValues(
                            alpha: 0.08,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              color: _themeConfig.accentColor,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              l10n.predictedVacancy,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: _themeConfig.accentColor,
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
                        color: _themeConfig.accentColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            color: _themeConfig.accentColor,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.predictedVacancy,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: _themeConfig.accentColor,
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
                                            color: _themeConfig.accentColor,
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
                    _buildStatusPill(
                      label: _operatingStatusLabel(l10n, operatingStatus),
                    ),
                    _buildInfoChip(
                      label: l10n.metered_occupied,
                      value: occupiedCount.toString(),
                    ),
                    _buildInfoChip(
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
                      _openNavigationForMetered(group);
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

  Widget _buildStatusPill({required String label}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _themeConfig.accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _themeConfig.accentColor.withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: _themeConfig.accentColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInfoChip({required String label, required String value}) {
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

  Future<void> _restoreThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_themePrefKey);
      if (saved != null && _mapThemes.containsKey(saved)) {
        setState(() {
          _selectedThemeKey = saved;
          _themeConfig = _mapThemes[saved] ?? _themeConfig;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveThemePreference(String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themePrefKey, value);
    } catch (_) {}
  }

  Future<void> _restoreLanguagePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_languagePrefKey);
      final restored = languageFromStorage(saved);
      setState(() {
        _language = restored;
      });
      appLanguageNotifier.value = restored;
    } catch (_) {}
  }

  Future<void> _saveLanguagePreference(AppLanguage value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languagePrefKey, value.storageValue);
      appLanguageNotifier.value = value;
    } catch (_) {}
  }

  Future<void> _restoreVehicleTypePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_vehicleTypePrefKey);
      if (saved == null) return;
      final restored = HkVehicleType.values.firstWhere(
        (type) => type.name == saved,
        orElse: () => HkVehicleType.privateCar,
      );
      setState(() {
        _vehicleType = restored;
      });
    } catch (_) {}
  }

  Future<void> _saveVehicleTypePreference(HkVehicleType value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_vehicleTypePrefKey, value.name);
    } catch (_) {}
  }

  Future<void> _restoreHkSpeedMapSourcePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_hkSpeedMapSourcePrefKey);
      setState(() {
        _hkSpeedMapSource = hkSpeedMapSourceFromStorage(saved);
      });
    } catch (_) {}
  }

  Future<void> _saveHkSpeedMapSourcePreference(HkSpeedMapSource value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_hkSpeedMapSourcePrefKey, value.storageValue);
    } catch (_) {}
  }

  void _scheduleRefreshVisibleGroups() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 80), () {
      if (mounted) _refreshVisibleGroups();
    });
  }

  void _refreshVisibleGroups() {
    if (!mounted || _groups.isEmpty) return;
    LatLng? center;
    double zoom = 13;
    LatLngBounds? bounds;
    try {
      final camera = _mapController.camera;
      center = camera.center;
      zoom = camera.zoom;
      bounds = camera.visibleBounds;
    } catch (_) {
      center = null;
    }
    _currentZoom = zoom;
    int maxVisible = _maxVisibleGroups;
    double radius = 2600;
    if (zoom < 12) {
      maxVisible = 120;
      radius = 9000;
    } else if (zoom < 14) {
      maxVisible = 180;
      radius = 5000;
    } else if (zoom < 16) {
      maxVisible = 300;
      radius = 3000;
    } else {
      maxVisible = 420;
      radius = 1800;
    }
    List<MeteredStreetGroup> next;
    final currentCenter = center;
    final visibleBounds = bounds;
    if (visibleBounds != null) {
      next = _groups.where((g) => visibleBounds.contains(g.center)).toList();
      if (next.isEmpty && currentCenter != null) {
        final dist = const Distance();
        next = _groups
            .where((g) => dist(g.center, currentCenter) <= radius)
            .toList();
      }
    } else if (currentCenter == null) {
      next = _groups;
    } else {
      final dist = const Distance();
      next = _groups
          .where((g) => dist(g.center, currentCenter) <= radius)
          .toList();
    }
    if (currentCenter != null && next.length > maxVisible) {
      final dist = const Distance();
      next.sort(
        (a, b) => dist(
          a.center,
          currentCenter,
        ).compareTo(dist(b.center, currentCenter)),
      );
    }
    if (next.length > maxVisible) {
      next = next.take(maxVisible).toList();
    }
    if (next.length == _visibleGroups.length) return;
    setState(() => _visibleGroups = next);
  }

  LocationSettings _locationSettings() {
    if (kIsWeb) {
      return WebSettings(accuracy: LocationAccuracy.high);
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: LocationAccuracy.high,
          intervalDuration: Duration(seconds: 1),
        );
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return AppleSettings(
          accuracy: LocationAccuracy.high,
          pauseLocationUpdatesAutomatically: false,
        );
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return LocationSettings(accuracy: LocationAccuracy.high);
    }
  }

  Future<void> _getCurrentLocation({bool recenter = true}) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: _locationSettings(),
      );
      if (!mounted) return;
      final loc = LatLng(position.latitude, position.longitude);
      if (recenter) {
        _mapController.move(loc, _mapController.camera.zoom);
      }
    } catch (_) {}
  }

  void _adjustZoom(double delta) {
    try {
      final camera = _mapController.camera;
      final next = (camera.zoom + delta).clamp(3.0, 18.0);
      _mapController.move(camera.center, next);
    } catch (_) {}
  }

  String _vehicleLabel(String code, AppLocalizations l10n) {
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

  Future<void> _openMeteredSearch() async {
    if (_groups.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    final result = await showSearch<MeteredStreetGroup?>(
      context: context,
      delegate: _MeteredSearchDelegate(
        groups: _groups,
        l10n: l10n,
        streetLabel: (group) => _streetLabel(group),
        districtLabel: (group) => _districtLabel(group),
        recentGroups: _resolveRecentGroups(),
        onClearRecents: _clearRecentMeteredSearches,
        searchFieldLabelText: l10n.search_parking,
        appBarColor: _themeConfig.appBarColor,
        appBarForeground: _themeConfig.appBarForeground,
        accentColor: _themeConfig.accentColor,
        backgroundColor: _themeConfig.backgroundColor,
        forceLightSearch: true,
      ),
    );
    if (!mounted || result == null) return;
    await _rememberRecentMeteredSearch(result);
    _mapController.move(result.center, math.max(_currentZoom, 15));
    _showGroupSheet(result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final useDarkFade =
        ThemeData.estimateBrightnessForColor(_themeConfig.backgroundColor) ==
        Brightness.dark;
    final fadeColor = useDarkFade ? Colors.black : Colors.white;
    final useDarkStatusText =
        ThemeData.estimateBrightnessForColor(_themeConfig.appBarColor) ==
        Brightness.light;
    final overlayStyle = useDarkStatusText
        ? SystemUiOverlayStyle.dark
        : SystemUiOverlayStyle.light;
    final center = widget.initialCenter ?? const LatLng(22.3193, 114.1694);
    final canPop = Navigator.of(context).canPop();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: _themeConfig.backgroundColor,
        drawer: SettingsDrawer(
          themeConfig: _themeConfig,
          mapThemes: _mapThemes,
          selectedThemeKey: _selectedThemeKey,
          onSelectTheme: (value) {
            setState(() {
              _selectedThemeKey = value;
              _themeConfig = _mapThemes[value] ?? _themeConfig;
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
            });
          },
          hkSpeedMapSource: _hkSpeedMapSource,
          onSelectHkSpeedMapSource: (value) {
            setState(() {
              _hkSpeedMapSource = value;
            });
            _saveHkSpeedMapSourcePreference(value);
          },
          onZoomIn: () => _adjustZoom(1.0),
          onZoomOut: () => _adjustZoom(-1.0),
          onGoToCurrentLocation: () => _getCurrentLocation(),
          onResetView: () {
            _mapController.move(
              _mapController.camera.center,
              _mapController.camera.zoom,
            );
          },
          onClearCache: () async {},
          vehicleType: _vehicleType,
          onSelectVehicleType: (value) {
            setState(() {
              _vehicleType = value;
            });
            _saveVehicleTypePreference(value);
          },
          signedInEmail: FirebaseAuth.instance.currentUser?.email,
          onEmailSignIn: _signInWithEmail,
          onEmailRegister: _registerWithEmail,
          onGoogleSignIn: _signInWithGoogle,
          onGoogleSignOut: _signOutGoogle,
        ),
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 13,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onLongPress: (tapPosition, latLng) {
                  unawaited(_showMapRouteChoice(latLng));
                },
                onMapEvent: (_) => _scheduleRefreshVisibleGroups(),
              ),
              children: [
                TileLayer(
                  urlTemplate: _themeConfig.urlTemplate,
                  subdomains: _themeConfig.subdomains,
                ),
                if (_showHkSpeedMap)
                  HkSpeedMapTileLayer(
                    source: _hkSpeedMapSource,
                    opacity: _currentZoom < 12 ? 0.45 : 0.6,
                  ),
                CurrentLocationLayer(
                  style: LocationMarkerStyle(
                    markerSize: const Size(20, 20),
                    markerDirection: MarkerDirection.heading,
                    headingSectorColor: _themeConfig.accentColor.withOpacity(
                      0.5,
                    ),
                    headingSectorRadius: 60,
                  ),
                ),
                if (_groups.isNotEmpty)
                  MarkerLayer(
                    markers: _buildGroupMarkers(_themeConfig.accentColor),
                  ),
                if (_routeStartOverride != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _routeStartOverride!,
                        width: 44,
                        height: 44,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _routeStartOverride = null),
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
                          onTap: () => setState(() => _routeDestination = null),
                          child: const Icon(
                            Icons.place,
                            color: Colors.red,
                            size: 36,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: SizedBox(
                height: 120 + MediaQuery.of(context).padding.top,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    IgnorePointer(
                      child: Container(
                        height: 120 + MediaQuery.of(context).padding.top,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: const Alignment(0.5, 0.0),
                            end: const Alignment(0.5, 1.0),
                            colors: [
                              fadeColor.withAlpha(204),
                              fadeColor.withAlpha(0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 36,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: Text(
                          l10n.metered_parking_title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: useDarkFade ? Colors.white : Colors.black,
                            fontSize: 20,
                            fontFamily: 'PingFang TC',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (canPop)
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
                        Icons.arrow_back,
                        color: Color(0xFF00008B),
                        size: 20,
                      ),
                    ),
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
                  onTap: () => _scaffoldKey.currentState?.openDrawer(),
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
                    child: const Icon(Icons.settings, color: Color(0xFF00008B)),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 120,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildMapControlButton(
                      heroTag: 'meteredRefresh',
                      icon: Icons.refresh,
                      onPressed: _load,
                    ),
                    const SizedBox(height: 8),
                    _buildMapControlButton(
                      heroTag: 'meteredZoomIn',
                      icon: Icons.add,
                      onPressed: () => _adjustZoom(1.0),
                    ),
                    const SizedBox(height: 8),
                    _buildMapControlButton(
                      heroTag: 'meteredZoomOut',
                      icon: Icons.remove,
                      onPressed: () => _adjustZoom(-1.0),
                    ),
                    const SizedBox(height: 8),
                    _buildMapControlButton(
                      heroTag: 'meteredMyLocation',
                      icon: Icons.my_location,
                      onPressed: () => _getCurrentLocation(),
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
                              onTap: _openMeteredSearch,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.search,
                                    color: Color(0xFF00008B),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      l10n.search_parking,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: Colors.black87.withValues(
                                              alpha: 0.7,
                                            ),
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: _loading
                    ? OpenScreen(
                        key: const ValueKey('metered-loading-screen'),
                        message: l10n.loading_metered_parking,
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            if (!_loading && _groups.isEmpty)
              Positioned.fill(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error == null
                          ? l10n.metered_no_data
                          : l10n.route_fetch_failed(_error!),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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
}

class _MeteredSearchDelegate extends SearchDelegate<MeteredStreetGroup?> {
  _MeteredSearchDelegate({
    required this.groups,
    required this.l10n,
    required this.streetLabel,
    required this.districtLabel,
    required this.recentGroups,
    required this.onClearRecents,
    required this.searchFieldLabelText,
    required this.appBarColor,
    required this.appBarForeground,
    required this.accentColor,
    required this.backgroundColor,
    required this.forceLightSearch,
  }) : _recentGroups = List<MeteredStreetGroup>.from(recentGroups);

  final List<MeteredStreetGroup> groups;
  final AppLocalizations l10n;
  final String Function(MeteredStreetGroup group) streetLabel;
  final String Function(MeteredStreetGroup group) districtLabel;
  final List<MeteredStreetGroup> recentGroups;
  final Future<void> Function() onClearRecents;
  final String searchFieldLabelText;
  final Color appBarColor;
  final Color appBarForeground;
  final Color accentColor;
  final Color backgroundColor;
  final bool forceLightSearch;
  final ValueNotifier<int> _refreshSignal = ValueNotifier<int>(0);
  List<MeteredStreetGroup> _recentGroups;
  late final bool _useDarkSearch =
      !forceLightSearch &&
      ThemeData.estimateBrightnessForColor(appBarColor) == Brightness.dark;
  late final bool _useDarkSurface =
      ThemeData.estimateBrightnessForColor(backgroundColor) == Brightness.dark;

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
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          tooltip: l10n.clear,
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      tooltip: l10n.back,
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _refreshSignal,
      builder: (context, _, __) => _buildBody(context),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _refreshSignal,
      builder: (context, _, __) => _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      if (_recentGroups.isEmpty) {
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
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
          onClear: () async {
            await onClearRecents();
            _recentGroups = const [];
            _refreshSignal.value++;
            showSuggestions(context);
          },
        ),
        ..._recentGroups.map((group) => _buildGroupTile(context, group)),
      ];
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: _withDividers(rows),
      );
    }

    final items = _filterGroups(trimmed);
    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
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
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: _withDividers(
        items.map((group) => _buildGroupTile(context, group)).toList(),
      ),
    );
  }

  List<MeteredStreetGroup> _filterGroups(String queryText) {
    final q = queryText.trim().toLowerCase();
    if (q.isEmpty) return groups;
    return groups
        .where((group) => _matchesGroup(group, q))
        .toList(growable: false);
  }

  bool _matchesGroup(MeteredStreetGroup group, String queryText) {
    final buffer = StringBuffer()
      ..write(group.streetEn)
      ..write(' ')
      ..write(group.streetTc)
      ..write(' ')
      ..write(group.streetSc)
      ..write(' ')
      ..write(group.sectionEn)
      ..write(' ')
      ..write(group.sectionTc)
      ..write(' ')
      ..write(group.sectionSc)
      ..write(' ')
      ..write(group.districtEn)
      ..write(' ')
      ..write(group.districtTc)
      ..write(' ')
      ..write(group.districtSc);
    return buffer.toString().toLowerCase().contains(queryText);
  }

  Widget _buildGroupTile(BuildContext context, MeteredStreetGroup group) {
    final title = streetLabel(group);
    final subtitle = districtLabel(group);
    return ListTile(
      title: Text(title),
      subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
      trailing: Text('${group.vacant}/${group.total}'),
      onTap: () => close(context, group),
    );
  }

  List<Widget> _withDividers(List<Widget> rows) {
    if (rows.isEmpty) return const [];
    final out = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      out.add(rows[i]);
      if (i != rows.length - 1) {
        out.add(const Divider(height: 1));
      }
    }
    return out;
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required VoidCallback? onClear,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const Spacer(),
          if (onClear != null)
            TextButton(onPressed: onClear, child: Text(l10n.clear)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _refreshSignal.dispose();
    super.dispose();
  }
}
