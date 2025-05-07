import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings_model.dart';

class SettingsProvider with ChangeNotifier {
  SettingsModel _settings = SettingsModel();

  SettingsModel get settings => _settings;

  // Геттеры для удобства
  ThemeMode get themeMode => _settings.themeMode;
  AppLanguage get language => _settings.language;
  bool get isDarkMode => _settings.themeMode == ThemeMode.dark;
  
  // Инициализация настроек из SharedPreferences
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Загрузка темы
    final themeModeIndex = prefs.getInt('theme_mode') ?? 0;
    final themeMode = ThemeMode.values[themeModeIndex];
    
    // Загрузка языка
    final languageIndex = prefs.getInt('language') ?? 0;
    final language = AppLanguage.values[languageIndex];
    
    _settings = SettingsModel(
      themeMode: themeMode,
      language: language,
    );
    
    notifyListeners();
  }
  
  // Сохранение настроек
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setInt('theme_mode', _settings.themeMode.index);
    await prefs.setInt('language', _settings.language.index);
  }
  
  // Изменение темы
  void setThemeMode(ThemeMode mode) {
    if (_settings.themeMode == mode) return;
    
    _settings = _settings.copyWith(themeMode: mode);
    _saveSettings();
    notifyListeners();
  }
  
  // Переключение между светлой и темной темами
  void toggleTheme() {
    final newMode = _settings.themeMode == ThemeMode.dark 
        ? ThemeMode.light 
        : ThemeMode.dark;
    
    setThemeMode(newMode);
  }
  
  // Изменение языка
  void setLanguage(AppLanguage language) {
    if (_settings.language == language) return;
    
    _settings = _settings.copyWith(language: language);
    _saveSettings();
    notifyListeners();
  }
} 