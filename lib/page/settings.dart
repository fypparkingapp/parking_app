import 'package:flutter/material.dart';
import 'package:parking_app/network/toll_service.dart';
import 'package:parking_app/l10n/app_localizations.dart';
import 'package:parking_app/manager/language_manager.dart';
import 'package:parking_app/manager/map_theme_manager.dart';
import 'package:parking_app/widget/hk_speed_map_layer.dart';

class SettingsDrawer extends StatelessWidget {
  const SettingsDrawer({
    super.key,
    required this.themeConfig,
    required this.mapThemes,
    required this.selectedThemeKey,
    required this.onSelectTheme,
    required this.language,
    required this.onSelectLanguage,
    required this.useClustering,
    required this.onUseClusteringChanged,
    required this.showHkSpeedMap,
    required this.onShowHkSpeedMapChanged,
    required this.hkSpeedMapSource,
    required this.onSelectHkSpeedMapSource,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onGoToCurrentLocation,
    required this.onResetView,
    required this.onClearCache,
    required this.vehicleType,
    required this.onSelectVehicleType,
    required this.signedInEmail,
    required this.onEmailSignIn,
    required this.onEmailRegister,
    required this.onGoogleSignIn,
    required this.onGoogleSignOut,
    this.onReloadCloudPreferences,
  });

  final MapThemeConfig themeConfig;
  final Map<String, MapThemeConfig> mapThemes;
  final String selectedThemeKey;
  final ValueChanged<String> onSelectTheme;
  final AppLanguage language;
  final ValueChanged<AppLanguage> onSelectLanguage;
  final bool useClustering;
  final ValueChanged<bool> onUseClusteringChanged;
  final bool showHkSpeedMap;
  final ValueChanged<bool> onShowHkSpeedMapChanged;
  final HkSpeedMapSource hkSpeedMapSource;
  final ValueChanged<HkSpeedMapSource> onSelectHkSpeedMapSource;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final Future<void> Function() onGoToCurrentLocation;
  final VoidCallback onResetView;
  final Future<void> Function() onClearCache;
  final HkVehicleType vehicleType;
  final ValueChanged<HkVehicleType> onSelectVehicleType;
  final String? signedInEmail;
  final Future<void> Function(String email, String password) onEmailSignIn;
  final Future<void> Function(String email, String password) onEmailRegister;
  final Future<void> Function() onGoogleSignIn;
  final Future<void> Function() onGoogleSignOut;
  final Future<void> Function()? onReloadCloudPreferences;

  String _mapThemeLabel(
    AppLocalizations l10n,
    String key,
    MapThemeConfig config,
  ) {
    switch (key) {
      case 'Standard':
        return l10n.map_theme_default;
      case 'Dark':
        return l10n.map_theme_night_drive;
      case 'Light':
        return l10n.map_theme_clean_atlas;
      default:
        return config.label;
    }
  }

  String _vehicleTypeLabel(AppLocalizations l10n, HkVehicleType type) {
    switch (type) {
      case HkVehicleType.privateCar:
        return l10n.vehicle_type_private_car;
      case HkVehicleType.motorcycle:
        return l10n.vehicle_type_motorcycle;
      case HkVehicleType.taxi:
        return l10n.vehicle_type_taxi;
    }
  }

  String _accountSectionTitle() {
    switch (language) {
      case AppLanguage.english:
        return 'Account';
      case AppLanguage.traditionalChinese:
        return '帳戶';
      case AppLanguage.simplifiedChinese:
        return '账户';
    }
  }

  String _googleSignInLabel() {
    switch (language) {
      case AppLanguage.english:
        return 'Sign in with Google';
      case AppLanguage.traditionalChinese:
        return '使用 Google 登入';
      case AppLanguage.simplifiedChinese:
        return '使用 Google 登录';
    }
  }

  String _googleLinkLabel() {
    switch (language) {
      case AppLanguage.english:
        return 'Link Google account';
      case AppLanguage.traditionalChinese:
        return '連結 Google 帳戶';
      case AppLanguage.simplifiedChinese:
        return '关联 Google 账户';
    }
  }

  String _emailSignInLabel() {
    switch (language) {
      case AppLanguage.english:
        return 'Sign in with Email';
      case AppLanguage.traditionalChinese:
        return '使用電郵登入';
      case AppLanguage.simplifiedChinese:
        return '使用电邮登录';
    }
  }

  String _emailLinkLabel() {
    switch (language) {
      case AppLanguage.english:
        return 'Link Email/Password';
      case AppLanguage.traditionalChinese:
        return '連結電郵/密碼';
      case AppLanguage.simplifiedChinese:
        return '关联电邮/密码';
    }
  }

  String _emailDialogTitle() {
    switch (language) {
      case AppLanguage.english:
        return 'Email Authentication';
      case AppLanguage.traditionalChinese:
        return '電郵驗證';
      case AppLanguage.simplifiedChinese:
        return '电邮验证';
    }
  }

  String _emailFieldLabel() {
    switch (language) {
      case AppLanguage.english:
        return 'Email';
      case AppLanguage.traditionalChinese:
        return '電郵';
      case AppLanguage.simplifiedChinese:
        return '电邮';
    }
  }

  String _passwordFieldLabel() {
    switch (language) {
      case AppLanguage.english:
        return 'Password';
      case AppLanguage.traditionalChinese:
        return '密碼';
      case AppLanguage.simplifiedChinese:
        return '密码';
    }
  }

  String _registerEmailLabel() {
    switch (language) {
      case AppLanguage.english:
        return 'Register';
      case AppLanguage.traditionalChinese:
        return '註冊';
      case AppLanguage.simplifiedChinese:
        return '注册';
    }
  }

  String _invalidEmailPasswordLabel() {
    switch (language) {
      case AppLanguage.english:
        return 'Please enter both email and password.';
      case AppLanguage.traditionalChinese:
        return '請輸入電郵及密碼。';
      case AppLanguage.simplifiedChinese:
        return '请输入电邮及密码。';
    }
  }

  String _googleSignOutLabel() {
    switch (language) {
      case AppLanguage.english:
        return 'Sign out';
      case AppLanguage.traditionalChinese:
        return '登出';
      case AppLanguage.simplifiedChinese:
        return '登出';
    }
  }

  String _reloadCloudPrefsLabel() {
    switch (language) {
      case AppLanguage.english:
        return 'Reload cloud preferences';
      case AppLanguage.traditionalChinese:
        return '重新載入雲端偏好設定';
      case AppLanguage.simplifiedChinese:
        return '重新载入云端偏好设置';
    }
  }

  Future<void> _showEmailAuthDialog(BuildContext context) async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    var obscure = true;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(_emailDialogTitle()),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.email],
                    decoration: InputDecoration(labelText: _emailFieldLabel()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: obscure,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: _passwordFieldLabel(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            obscure = !obscure;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    MaterialLocalizations.of(context).cancelButtonLabel,
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final email = emailController.text.trim();
                    final password = passwordController.text;
                    if (email.isEmpty || password.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(_invalidEmailPasswordLabel())),
                      );
                      return;
                    }
                    Navigator.of(dialogContext).pop();
                    await onEmailRegister(email, password);
                  },
                  child: Text(_registerEmailLabel()),
                ),
                FilledButton(
                  onPressed: () async {
                    final email = emailController.text.trim();
                    final password = passwordController.text;
                    if (email.isEmpty || password.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(_invalidEmailPasswordLabel())),
                      );
                      return;
                    }
                    Navigator.of(dialogContext).pop();
                    await onEmailSignIn(email, password);
                  },
                  child: Text(_emailSignInLabel()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isSignedIn = signedInEmail != null && signedInEmail!.isNotEmpty;
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: themeConfig.appBarColor),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  l10n.map_settings_title,
                  style: TextStyle(
                    color: themeConfig.appBarForeground,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Text(
                l10n.language,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...AppLanguage.values.map(
              (lang) => RadioListTile<AppLanguage>(
                title: Text(switch (lang) {
                  AppLanguage.english => l10n.language_english,
                  AppLanguage.traditionalChinese =>
                    l10n.language_traditional_chinese,
                  AppLanguage.simplifiedChinese =>
                    l10n.language_simplified_chinese,
                }),
                value: lang,
                groupValue: language,
                onChanged: (value) {
                  if (value == null) return;
                  onSelectLanguage(value);
                },
                activeColor: themeConfig.accentColor,
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Text(
                l10n.map_style,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...mapThemes.entries.map((entry) {
              final key = entry.key;
              final config = entry.value;
              return RadioListTile<String>(
                title: Text(_mapThemeLabel(l10n, key, config)),
                value: key,
                groupValue: selectedThemeKey,
                onChanged: (value) {
                  if (value == null) return;
                  onSelectTheme(value);
                },
                activeColor: themeConfig.accentColor,
              );
            }),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Text(
                l10n.vehicle_type,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...HkVehicleType.values.map(
              (type) => RadioListTile<HkVehicleType>(
                title: Text(_vehicleTypeLabel(l10n, type)),
                value: type,
                groupValue: vehicleType,
                onChanged: (value) {
                  if (value == null) return;
                  onSelectVehicleType(value);
                },
                activeColor: themeConfig.accentColor,
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Text(
                l10n.map_controls,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SwitchListTile(
              title: Text(l10n.cluster_nearby_carparks),
              value: useClustering,
              onChanged: (value) => onUseClusteringChanged(value),
              activeThumbColor: themeConfig.accentColor,
            ),
            SwitchListTile(
              title: const Text('HK Speed Map'),
              value: showHkSpeedMap,
              onChanged: (value) => onShowHkSpeedMapChanged(value),
              activeThumbColor: themeConfig.accentColor,
            ),
            if (showHkSpeedMap)
              ...HkSpeedMapSource.values.map(
                (source) => RadioListTile<HkSpeedMapSource>(
                  title: Text(source.label),
                  subtitle: Text(source.description),
                  value: source,
                  groupValue: hkSpeedMapSource,
                  onChanged: (value) {
                    if (value == null) return;
                    onSelectHkSpeedMapSource(value);
                  },
                  activeColor: themeConfig.accentColor,
                ),
              ),
            ListTile(
              leading: const Icon(Icons.zoom_in),
              title: Text(l10n.zoom_in),
              onTap: () {
                Navigator.of(context).pop();
                onZoomIn();
              },
            ),
            ListTile(
              leading: const Icon(Icons.zoom_out),
              title: Text(l10n.zoom_out),
              onTap: () {
                Navigator.of(context).pop();
                onZoomOut();
              },
            ),
            ListTile(
              leading: const Icon(Icons.my_location),
              title: Text(l10n.go_to_my_location),
              onTap: () async {
                Navigator.of(context).pop();
                await onGoToCurrentLocation();
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: Text(l10n.reset_view),
              onTap: () {
                Navigator.of(context).pop();
                onResetView();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever),
              title: Text(l10n.clear_cached_parking_data),
              subtitle: Text(l10n.clear_cached_parking_data_subtitle),
              onTap: () async {
                Navigator.of(context).pop();
                await onClearCache();
              },
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Text(
                _accountSectionTitle(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (signedInEmail != null && signedInEmail!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: Text(signedInEmail!),
              ),
            if (signedInEmail != null && onReloadCloudPreferences != null)
              ListTile(
                leading: const Icon(Icons.refresh),
                title: Text(_reloadCloudPrefsLabel()),
                onTap: () async {
                  Navigator.of(context).pop();
                  await onReloadCloudPreferences!.call();
                },
              ),
            ListTile(
              leading: Icon(isSignedIn ? Icons.alternate_email : Icons.login),
              title: Text(isSignedIn ? _emailLinkLabel() : _emailSignInLabel()),
              onTap: () async {
                await _showEmailAuthDialog(context);
              },
            ),
            ListTile(
              leading: Icon(isSignedIn ? Icons.link : Icons.login),
              title: Text(
                isSignedIn ? _googleLinkLabel() : _googleSignInLabel(),
              ),
              onTap: () async {
                await onGoogleSignIn();
              },
            ),
            if (isSignedIn)
              ListTile(
                leading: const Icon(Icons.logout),
                title: Text(_googleSignOutLabel()),
                onTap: () async {
                  Navigator.of(context).pop();
                  await onGoogleSignOut();
                },
              ),
          ],
        ),
      ),
    );
  }
}
