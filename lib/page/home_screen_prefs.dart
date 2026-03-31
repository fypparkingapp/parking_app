part of 'appmain.dart';

Timer? _cloudPrefsSyncDebounce;

extension _HomeScreenPrefs on _HomeScreenState {
  Future<void> _reloadCloudPreferences() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _pullCloudPreferences(user.uid);
  }

  void _scheduleCloudSync() {
    _cloudPrefsSyncDebounce?.cancel();
    _cloudPrefsSyncDebounce = Timer(const Duration(milliseconds: 800), () {
      unawaited(_syncPrefsToCloud());
    });
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
        return;
      }

      await auth.signInWithEmailAndPassword(
        email: normalized,
        password: password,
      );
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
        return;
      }

      await auth.createUserWithEmailAndPassword(
        email: normalized,
        password: password,
      );
      _showAuthSnack(
        en: 'Account created with email/password.',
        zhHant: '已建立電郵/密碼帳戶。',
        zhHans: '已建立电邮/密码账户。',
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
        final provider = GoogleAuthProvider();
        await auth.signInWithPopup(provider);
      } else {
        final googleSignIn = GoogleSignIn.instance;
        await googleSignIn.initialize();
        GoogleSignInAccount googleUser;
        try {
          googleUser = await googleSignIn.authenticate();
        } on GoogleSignInException catch (e) {
          final desc = (e.description ?? '').toLowerCase();
          if (e.code == GoogleSignInExceptionCode.canceled &&
              desc.contains('reauth')) {
            await googleSignIn.signOut();
            googleUser = await googleSignIn.authenticate();
          } else {
            rethrow;
          }
        }
        final googleAuth = googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
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
      _showAuthSnack(en: 'Signed out.', zhHant: '已登出。', zhHans: '已登出。');
    } catch (e) {
      _showAuthSnack(
        en: 'Sign-out failed: $e',
        zhHant: '登出失敗：$e',
        zhHans: '登出失败：$e',
      );
    }
  }

  Future<void> _pullCloudPreferences(String uid) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('prefs')
          .doc('app')
          .get()
          .timeout(const Duration(seconds: 6));
      final data = snapshot.data();
      if (data == null || data.isEmpty) {
        _scheduleCloudSync();
        if (kDebugMode) {
          debugPrint('HomeScreen: cloud prefs empty, scheduled initial sync');
        }
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final theme = data[_HomeScreenState._themePrefKey];
      final language = data[_HomeScreenState._languagePrefKey];
      final vehicleType = data[_HomeScreenState._vehicleTypePrefKey];
      final hkSpeedMapSource = data[_HomeScreenState._hkSpeedMapSourcePrefKey];
      final smartNavigationPreference =
          data[_HomeScreenState._smartNavigationPrefKey];
      final recentCarparks = data[_HomeScreenState._recentSearchPrefKey];
      final recentMetered = data[_HomeScreenState._recentMeteredPrefKey];
      final recentCombined = data[_HomeScreenState._recentCombinedPrefKey];
      final favorites = data[_HomeScreenState._favoriteCarparkPrefKey];
      final savedPlaces = data[_HomeScreenState._savedPlacesPrefKey];

      if (theme is String && _mapThemes.containsKey(theme)) {
        await prefs.setString(_HomeScreenState._themePrefKey, theme);
        _selectedTheme = theme;
      }
      if (language is String) {
        await prefs.setString(_HomeScreenState._languagePrefKey, language);
        final restoredLang = languageFromStorage(language);
        _language = restoredLang;
        appLanguageNotifier.value = restoredLang;
      }
      if (vehicleType is String) {
        await prefs.setString(
          _HomeScreenState._vehicleTypePrefKey,
          vehicleType,
        );
        _vehicleType = _vehicleTypeFromStorage(vehicleType);
      }
      if (hkSpeedMapSource is String) {
        await prefs.setString(
          _HomeScreenState._hkSpeedMapSourcePrefKey,
          hkSpeedMapSource,
        );
        _hkSpeedMapSource = hkSpeedMapSourceFromStorage(hkSpeedMapSource);
      }
      if (smartNavigationPreference is String) {
        await prefs.setString(
          _HomeScreenState._smartNavigationPrefKey,
          smartNavigationPreference,
        );
        _smartNavigationPreference = _smartNavigationPreferenceFromStorage(
          smartNavigationPreference,
        );
      }
      if (recentCarparks is List) {
        final values = recentCarparks.whereType<String>().toList(
          growable: false,
        );
        await prefs.setStringList(
          _HomeScreenState._recentSearchPrefKey,
          values,
        );
        _recentSearchCarparkIds = values;
      }
      if (recentMetered is List) {
        final values = recentMetered.whereType<String>().toList(
          growable: false,
        );
        await prefs.setStringList(
          _HomeScreenState._recentMeteredPrefKey,
          values,
        );
        _recentMeteredKeys = values;
      }
      if (recentCombined is List) {
        final values = recentCombined.whereType<String>().toList(
          growable: false,
        );
        await prefs.setStringList(
          _HomeScreenState._recentCombinedPrefKey,
          values,
        );
        _recentCombinedKeys = values;
      }
      if (favorites is List) {
        final values = favorites.whereType<String>().toList(growable: false);
        await prefs.setStringList(
          _HomeScreenState._favoriteCarparkPrefKey,
          values,
        );
        _favoriteCarparkIds = values;
      }
      if (savedPlaces is List) {
        final values = savedPlaces.whereType<String>().toList(growable: false);
        await prefs.setStringList(_HomeScreenState._savedPlacesPrefKey, values);
        final parsed = <SavedPlace>[];
        for (final item in values) {
          try {
            final decoded = jsonDecode(item);
            if (decoded is Map<String, dynamic>) {
              parsed.add(SavedPlace.fromJson(decoded));
            }
          } catch (_) {}
        }
        _savedPlaces = parsed;
      }
      _safeSetState(() {});
      if (kDebugMode) {
        debugPrint('HomeScreen: cloud prefs loaded');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('HomeScreen: _pullCloudPreferences skipped -> $e');
      }
    }
  }

  Future<void> _syncPrefsToCloud() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final encodedSavedPlaces = _savedPlaces
          .map((place) => jsonEncode(place.toJson()))
          .toList();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('prefs')
          .doc('app')
          .set({
            _HomeScreenState._themePrefKey: _selectedTheme,
            _HomeScreenState._languagePrefKey: _language.storageValue,
            _HomeScreenState._vehicleTypePrefKey: _vehicleType.name,
            _HomeScreenState._hkSpeedMapSourcePrefKey:
                _hkSpeedMapSource.storageValue,
            _HomeScreenState._smartNavigationPrefKey:
                _smartNavigationPreference.name,
            _HomeScreenState._recentSearchPrefKey: _recentSearchCarparkIds,
            _HomeScreenState._recentMeteredPrefKey: _recentMeteredKeys,
            _HomeScreenState._recentCombinedPrefKey: _recentCombinedKeys,
            _HomeScreenState._favoriteCarparkPrefKey: _favoriteCarparkIds,
            _HomeScreenState._savedPlacesPrefKey: encodedSavedPlaces,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 6));
      if (kDebugMode) {
        debugPrint('HomeScreen: cloud prefs synced');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('HomeScreen: _syncPrefsToCloud skipped -> $e');
      }
    }
  }

  String _savedPlaceKey(SavedPlace place) {
    final labelKey = place.label.trim().toLowerCase();
    final latKey = place.latitude.toStringAsFixed(6);
    final lngKey = place.longitude.toStringAsFixed(6);
    return '$labelKey|$latKey|$lngKey';
  }

  Future<void> _restoreSavedPlaces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw =
          prefs.getStringList(_HomeScreenState._savedPlacesPrefKey) ??
          const <String>[];
      final places = <SavedPlace>[];
      for (final item in raw) {
        try {
          final decoded = jsonDecode(item);
          if (decoded is Map<String, dynamic>) {
            final place = SavedPlace.fromJson(decoded);
            if (place.label.isNotEmpty) {
              places.add(place);
            }
          }
        } catch (_) {}
      }
      _safeSetState(() => _savedPlaces = places);
    } catch (_) {}
  }

  Future<void> _saveSavedPlaces(List<SavedPlace> places) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = places
          .map((place) => jsonEncode(place.toJson()))
          .toList();
      await prefs.setStringList(_HomeScreenState._savedPlacesPrefKey, encoded);
      _scheduleCloudSync();
    } catch (_) {}
  }

  Future<void> _addSavedPlace(SavedPlace place) async {
    if (place.label.trim().isEmpty) return;
    final placeKey = _savedPlaceKey(place);
    final next = <SavedPlace>[
      place,
      ..._savedPlaces.where((item) => _savedPlaceKey(item) != placeKey),
    ];
    final limited = next.length > _HomeScreenState._maxSavedPlaces
        ? next.sublist(0, _HomeScreenState._maxSavedPlaces)
        : next;
    _safeSetState(() => _savedPlaces = limited);
    await _saveSavedPlaces(limited);
  }

  Future<void> _removeSavedPlace(SavedPlace place) async {
    final placeKey = _savedPlaceKey(place);
    final next = _savedPlaces
        .where((item) => _savedPlaceKey(item) != placeKey)
        .toList();
    _safeSetState(() => _savedPlaces = next);
    await _saveSavedPlaces(next);
  }

  Future<void> _restoreRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids =
          prefs.getStringList(_HomeScreenState._recentSearchPrefKey) ??
          const <String>[];
      _safeSetState(() => _recentSearchCarparkIds = ids);
    } catch (_) {}
  }

  Future<void> _saveRecentSearches(List<String> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_HomeScreenState._recentSearchPrefKey, ids);
      _scheduleCloudSync();
    } catch (_) {}
  }

  Future<void> _rememberRecentSearch(Carpark carpark) async {
    final next = <String>[
      carpark.id,
      ..._recentSearchCarparkIds,
    ].where((id) => id.isNotEmpty).toList(growable: false);
    final unique = <String>[];
    final seen = <String>{};
    for (final id in next) {
      if (!seen.add(id)) continue;
      unique.add(id);
      if (unique.length >= _HomeScreenState._maxRecentSearches) break;
    }
    final combined = _prependCombinedRecent('p:${carpark.id}');
    _safeSetState(() {
      _recentSearchCarparkIds = unique;
      _recentCombinedKeys = combined;
    });
    await _saveRecentSearches(unique);
    await _saveRecentCombinedSearches(combined);
  }

  Future<void> _clearRecentSearches() async {
    final filtered = _recentCombinedKeys
        .where((value) => !value.startsWith('p:'))
        .toList(growable: false);
    _safeSetState(() {
      _recentSearchCarparkIds = const [];
      _recentCombinedKeys = filtered;
    });
    await _saveRecentSearches(const []);
    await _saveRecentCombinedSearches(filtered);
  }

  Future<void> _restoreRecentMeteredSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys =
          prefs.getStringList(_HomeScreenState._recentMeteredPrefKey) ??
          const <String>[];
      _safeSetState(() => _recentMeteredKeys = keys);
    } catch (_) {}
  }

  Future<void> _saveRecentMeteredSearches(List<String> keys) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_HomeScreenState._recentMeteredPrefKey, keys);
      _scheduleCloudSync();
    } catch (_) {}
  }

  Future<void> _restoreRecentCombinedSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final values =
          prefs.getStringList(_HomeScreenState._recentCombinedPrefKey) ??
          const <String>[];
      _safeSetState(() => _recentCombinedKeys = values);
    } catch (_) {}
  }

  Future<void> _saveRecentCombinedSearches(List<String> values) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _HomeScreenState._recentCombinedPrefKey,
        values,
      );
      _scheduleCloudSync();
    } catch (_) {}
  }

  List<String> _prependCombinedRecent(String entry) {
    final next = <String>[
      entry,
      ..._recentCombinedKeys,
    ].where((value) => value.isNotEmpty).toList(growable: false);
    final unique = <String>[];
    final seen = <String>{};
    for (final value in next) {
      if (!seen.add(value)) continue;
      unique.add(value);
      if (unique.length >= _HomeScreenState._maxCombinedRecentSearches) break;
    }
    return unique;
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
      if (unique.length >= _HomeScreenState._maxRecentMetered) break;
    }
    final combined = _prependCombinedRecent('m:${group.key}');
    _safeSetState(() {
      _recentMeteredKeys = unique;
      _recentCombinedKeys = combined;
    });
    await _saveRecentMeteredSearches(unique);
    await _saveRecentCombinedSearches(combined);
  }

  Future<void> _clearRecentMeteredSearches() async {
    final filtered = _recentCombinedKeys
        .where((value) => !value.startsWith('m:'))
        .toList(growable: false);
    _safeSetState(() {
      _recentMeteredKeys = const [];
      _recentCombinedKeys = filtered;
    });
    await _saveRecentMeteredSearches(const []);
    await _saveRecentCombinedSearches(filtered);
  }

  Future<void> _restoreFavoriteCarparks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids =
          prefs.getStringList(_HomeScreenState._favoriteCarparkPrefKey) ??
          const <String>[];
      _safeSetState(() => _favoriteCarparkIds = ids);
    } catch (_) {}
  }

  Future<void> _saveFavoriteCarparks(List<String> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_HomeScreenState._favoriteCarparkPrefKey, ids);
      _scheduleCloudSync();
    } catch (_) {}
  }

  Future<void> _toggleFavoriteCarpark(Carpark carpark) async {
    final id = carpark.id;
    if (id.isEmpty) return;
    final next = List<String>.from(_favoriteCarparkIds);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.insert(0, id);
      if (next.length > _HomeScreenState._maxFavoriteCarparks) {
        next.removeRange(_HomeScreenState._maxFavoriteCarparks, next.length);
      }
    }
    _safeSetState(() => _favoriteCarparkIds = next);
    await _saveFavoriteCarparks(next);
  }

  Future<void> _clearFavoriteCarparks() async {
    _safeSetState(() => _favoriteCarparkIds = const []);
    await _saveFavoriteCarparks(const []);
  }

  Future<void> _restoreThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_HomeScreenState._themePrefKey);
    if (saved != null && _mapThemes.containsKey(saved)) {
      _safeSetState(() {
        _selectedTheme = saved;
      });
    }
  }

  Future<void> _saveThemePreference(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_HomeScreenState._themePrefKey, value);
    _scheduleCloudSync();
  }

  Future<void> _restoreLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_HomeScreenState._languagePrefKey);
    final restored = languageFromStorage(saved);
    _safeSetState(() {
      _language = restored;
    });
    appLanguageNotifier.value = restored;
  }

  Future<void> _saveLanguagePreference(AppLanguage value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _HomeScreenState._languagePrefKey,
      value.storageValue,
    );
    appLanguageNotifier.value = value;
    _scheduleCloudSync();
  }

  Future<void> _restoreVehicleTypePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_HomeScreenState._vehicleTypePrefKey);
    final restored = _vehicleTypeFromStorage(saved);
    _safeSetState(() {
      _vehicleType = restored;
    });
  }

  Future<void> _saveVehicleTypePreference(HkVehicleType value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_HomeScreenState._vehicleTypePrefKey, value.name);
    _scheduleCloudSync();
  }

  Future<void> _restoreHkSpeedMapSourcePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_HomeScreenState._hkSpeedMapSourcePrefKey);
    final restored = hkSpeedMapSourceFromStorage(saved);
    _safeSetState(() {
      _hkSpeedMapSource = restored;
    });
  }

  Future<void> _saveHkSpeedMapSourcePreference(HkSpeedMapSource value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _HomeScreenState._hkSpeedMapSourcePrefKey,
      value.storageValue,
    );
    _scheduleCloudSync();
  }

  SmartNavigationPreference _smartNavigationPreferenceFromStorage(
    String? value,
  ) {
    switch (value) {
      case 'fastest':
        return SmartNavigationPreference.fastest;
      case 'availability':
        return SmartNavigationPreference.availability;
      case 'shortestWalk':
        return SmartNavigationPreference.shortestWalk;
      case 'cheapest':
      default:
        return SmartNavigationPreference.cheapest;
    }
  }

  Future<void> _restoreSmartNavigationPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_HomeScreenState._smartNavigationPrefKey);
    final restored = _smartNavigationPreferenceFromStorage(saved);
    _safeSetState(() {
      _smartNavigationPreference = restored;
    });
  }

  Future<void> _saveSmartNavigationPreference(
    SmartNavigationPreference value,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_HomeScreenState._smartNavigationPrefKey, value.name);
    _scheduleCloudSync();
  }
}
