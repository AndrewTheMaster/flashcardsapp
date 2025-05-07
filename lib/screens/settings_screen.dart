import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../localization/app_localizations.dart';
import '../models/settings_model.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('settings'.tr(context)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Секция выбора темы
            Text(
              'theme'.tr(context),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ThemeSelector(
              currentThemeMode: settingsProvider.themeMode,
              onThemeSelected: settingsProvider.setThemeMode,
            ),
            
            const SizedBox(height: 24),
            
            // Секция выбора языка
            Text(
              'language'.tr(context),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            LanguageSelector(
              currentLanguage: settingsProvider.language,
              onLanguageSelected: settingsProvider.setLanguage,
            ),
          ],
        ),
      ),
    );
  }
}

class ThemeSelector extends StatelessWidget {
  final ThemeMode currentThemeMode;
  final Function(ThemeMode) onThemeSelected;

  const ThemeSelector({
    Key? key,
    required this.currentThemeMode,
    required this.onThemeSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RadioListTile<ThemeMode>(
          title: Text('light_mode'.tr(context)),
          value: ThemeMode.light,
          groupValue: currentThemeMode,
          onChanged: (value) => onThemeSelected(value!),
        ),
        RadioListTile<ThemeMode>(
          title: Text('dark_mode'.tr(context)),
          value: ThemeMode.dark,
          groupValue: currentThemeMode,
          onChanged: (value) => onThemeSelected(value!),
        ),
        RadioListTile<ThemeMode>(
          title: Text('system_mode'.tr(context)),
          value: ThemeMode.system,
          groupValue: currentThemeMode,
          onChanged: (value) => onThemeSelected(value!),
        ),
      ],
    );
  }
}

class LanguageSelector extends StatelessWidget {
  final AppLanguage currentLanguage;
  final Function(AppLanguage) onLanguageSelected;

  const LanguageSelector({
    Key? key,
    required this.currentLanguage,
    required this.onLanguageSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RadioListTile<AppLanguage>(
          title: Text('english'.tr(context)),
          value: AppLanguage.english,
          groupValue: currentLanguage,
          onChanged: (value) => onLanguageSelected(value!),
        ),
        RadioListTile<AppLanguage>(
          title: Text('russian'.tr(context)),
          value: AppLanguage.russian,
          groupValue: currentLanguage,
          onChanged: (value) => onLanguageSelected(value!),
        ),
      ],
    );
  }
} 