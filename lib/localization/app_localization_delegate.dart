import 'package:flutter/material.dart';
import '../models/settings_model.dart';
import 'app_localizations.dart';

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  final AppLanguage language;

  const AppLocalizationsDelegate(this.language);

  @override
  bool isSupported(Locale locale) {
    return ['en', 'ru'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(language);
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) {
    return language != old.language;
  }
} 