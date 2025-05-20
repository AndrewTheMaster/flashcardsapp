import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings_model.dart';
import 'dart:developer' as developer;

class SettingsProvider with ChangeNotifier {
  SettingsModel _settings = SettingsModel();

  SettingsModel get settings => _settings;

  // Геттеры для удобства
  ThemeMode get themeMode => _settings.themeMode;
  AppLanguage get language => _settings.language;
  TranslationServiceType get translationService => _settings.translationService;
  ExerciseGenerationService get exerciseService => _settings.exerciseService;
  bool get offlineMode => _settings.offlineMode;
  String? get serverAddress => _settings.serverAddress;
  String get exerciseComplexity => _settings.exerciseComplexity;
  bool get isDarkMode => _settings.themeMode == ThemeMode.dark;
  bool get debugMode => _settings.debugMode;
  
  // Инициализация настроек из SharedPreferences
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Загрузка темы
    final themeModeIndex = prefs.getInt('theme_mode') ?? 0;
    final themeMode = ThemeMode.values[themeModeIndex];
    
    // Загрузка языка
    final languageIndex = prefs.getInt('language') ?? 0;
    final language = AppLanguage.values[languageIndex];
    
    // Загрузка сервиса перевода
    final translationServiceIndex = prefs.getInt('translation_service') ?? 0;
    final translationService = translationServiceIndex < TranslationServiceType.values.length 
        ? TranslationServiceType.values[translationServiceIndex]
        : TranslationServiceType.bkrsParser;
    
    // Загрузка сервиса генерации упражнений
    final exerciseServiceIndex = prefs.getInt('exercise_service') ?? 0;
    final exerciseService = exerciseServiceIndex < ExerciseGenerationService.values.length
        ? ExerciseGenerationService.values[exerciseServiceIndex]
        : ExerciseGenerationService.gemma3BertWwm;
    
    // Загрузка настроек сервера
    final offlineMode = prefs.getBool('offline_mode') ?? false;
    final serverAddress = prefs.getString('server_address') ?? "http://localhost:8000";
    
    // Загрузка сложности упражнений
    final exerciseComplexity = prefs.getString('exercise_complexity') ?? "normal";
    
    // Загрузка режима отладки
    final debugMode = prefs.getBool('debug_mode') ?? false;
    
    _settings = SettingsModel(
      themeMode: themeMode,
      language: language,
      translationService: translationService,
      exerciseService: exerciseService,
      offlineMode: offlineMode,
      serverAddress: serverAddress,
      exerciseComplexity: exerciseComplexity,
      debugMode: debugMode,
    );
    
    developer.log('SettingsProvider: настройки загружены', name: 'settings_provider');
    
    notifyListeners();
  }
  
  // Сохранение настроек
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setInt('theme_mode', _settings.themeMode.index);
    await prefs.setInt('language', _settings.language.index);
    await prefs.setInt('translation_service', _settings.translationService.index);
    await prefs.setInt('exercise_service', _settings.exerciseService.index);
    await prefs.setBool('offline_mode', _settings.offlineMode);
    await prefs.setString('server_address', _settings.serverAddress ?? "http://localhost:8000");
    await prefs.setString('exercise_complexity', _settings.exerciseComplexity);
    await prefs.setBool('debug_mode', _settings.debugMode);
    
    developer.log('SettingsProvider: настройки сохранены', name: 'settings_provider');
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
  
  // Изменение сервиса перевода
  void setTranslationService(TranslationServiceType service) {
    if (_settings.translationService == service) return;
    
    _settings = _settings.copyWith(translationService: service);
    _saveSettings();
    developer.log('SettingsProvider: сервис перевода изменен на $service', name: 'settings_provider');
    notifyListeners();
  }
  
  // Изменение сервиса генерации упражнений
  void setExerciseService(ExerciseGenerationService service) {
    if (_settings.exerciseService == service) return;
    
    _settings = _settings.copyWith(exerciseService: service);
    _saveSettings();
    developer.log('SettingsProvider: сервис упражнений изменен на $service', name: 'settings_provider');
    notifyListeners();
  }
  
  // Изменение режима офлайн
  void setOfflineMode(bool mode) {
    if (_settings.offlineMode == mode) return;
    
    _settings = _settings.copyWith(offlineMode: mode);
    _saveSettings();
    developer.log('SettingsProvider: режим офлайн изменен на $mode', name: 'settings_provider');
    notifyListeners();
  }
  
  // Изменение адреса сервера
  void setServerAddress(String address) {
    if (_settings.serverAddress == address) return;
    
    _settings = _settings.copyWith(serverAddress: address);
    _saveSettings();
    developer.log('SettingsProvider: адрес сервера изменен на $address', name: 'settings_provider');
    notifyListeners();
  }
  
  // Изменение сложности упражнений
  void setExerciseComplexity(String complexity) {
    if (_settings.exerciseComplexity == complexity) return;
    
    _settings = _settings.copyWith(exerciseComplexity: complexity);
    _saveSettings();
    developer.log('SettingsProvider: сложность упражнений изменена на $complexity', name: 'settings_provider');
    notifyListeners();
  }
  
  // Изменение режима отладки
  void setDebugMode(bool mode) {
    if (_settings.debugMode == mode) return;
    
    _settings = _settings.copyWith(debugMode: mode);
    _saveSettings();
    developer.log('SettingsProvider: режим отладки изменен на $mode', name: 'settings_provider');
    notifyListeners();
  }
} 