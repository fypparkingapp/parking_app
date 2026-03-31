import 'dart:ui';

import 'package:flutter/foundation.dart';

enum AppLanguage { english, traditionalChinese, simplifiedChinese }

final ValueNotifier<AppLanguage> appLanguageNotifier =
    ValueNotifier<AppLanguage>(AppLanguage.traditionalChinese);

extension AppLanguageX on AppLanguage {
  String get label {
    switch (this) {
      case AppLanguage.english:
        return 'English';
      case AppLanguage.traditionalChinese:
        return 'Traditional Chinese';
      case AppLanguage.simplifiedChinese:
        return 'Simplified Chinese';
    }
  }

  String get storageValue {
    switch (this) {
      case AppLanguage.english:
        return 'en';
      case AppLanguage.traditionalChinese:
        return 'tc';
      case AppLanguage.simplifiedChinese:
        return 'sc';
    }
  }

  Locale get locale {
    switch (this) {
      case AppLanguage.english:
        return const Locale('en');
      case AppLanguage.traditionalChinese:
        return const Locale('zh', 'TW');
      case AppLanguage.simplifiedChinese:
        return const Locale('zh', 'CN');
    }
  }

  bool get prefersChinese =>
      this == AppLanguage.traditionalChinese ||
      this == AppLanguage.simplifiedChinese;
}

AppLanguage languageFromStorage(String? raw) {
  switch (raw) {
    case 'en':
      return AppLanguage.english;
    case 'sc':
      return AppLanguage.simplifiedChinese;
    case 'tc':
      return AppLanguage.traditionalChinese;
    default:
      return AppLanguage.traditionalChinese;
  }
}

AppLanguage languageFromLocale(Locale locale) {
  if (locale.languageCode.toLowerCase() != 'zh') {
    return AppLanguage.english;
  }
  final country = locale.countryCode?.toUpperCase();
  if (country == 'CN') return AppLanguage.simplifiedChinese;
  if (country == 'TW') return AppLanguage.traditionalChinese;
  return AppLanguage.traditionalChinese;
}
