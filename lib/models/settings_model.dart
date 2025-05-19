import 'package:flutter/material.dart';

enum AppLanguage {
  english,
  russian
}

enum TranslationServiceType {
  bkrsParser,
  helsinkiTranslation
}

enum ExerciseGenerationService {
  gemma3BertWwm
}

class SettingsModel {
  AppLanguage language;
  ThemeMode themeMode;
  TranslationServiceType translationService;
  ExerciseGenerationService exerciseService;
  bool offlineMode;
  String? serverAddress;
  String exerciseComplexity;

  SettingsModel({
    this.language = AppLanguage.english,
    this.themeMode = ThemeMode.system,
    this.translationService = TranslationServiceType.bkrsParser,
    this.exerciseService = ExerciseGenerationService.gemma3BertWwm,
    this.offlineMode = false,
    this.serverAddress = "http://localhost:8000",
    this.exerciseComplexity = "normal",
  });

  SettingsModel copyWith({
    AppLanguage? language,
    ThemeMode? themeMode,
    TranslationServiceType? translationService,
    ExerciseGenerationService? exerciseService,
    bool? offlineMode,
    String? serverAddress,
    String? exerciseComplexity,
  }) {
    return SettingsModel(
      language: language ?? this.language,
      themeMode: themeMode ?? this.themeMode,
      translationService: translationService ?? this.translationService,
      exerciseService: exerciseService ?? this.exerciseService,
      offlineMode: offlineMode ?? this.offlineMode,
      serverAddress: serverAddress ?? this.serverAddress,
      exerciseComplexity: exerciseComplexity ?? this.exerciseComplexity,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'language': language.index,
      'themeMode': themeMode.index,
      'translationService': translationService.index,
      'exerciseService': exerciseService.index,
      'offlineMode': offlineMode,
      'serverAddress': serverAddress,
      'exerciseComplexity': exerciseComplexity,
    };
  }

  factory SettingsModel.fromJson(Map<String, dynamic> json) {
    return SettingsModel(
      language: AppLanguage.values[json['language'] ?? 0],
      themeMode: ThemeMode.values[json['themeMode'] ?? 0],
      translationService: TranslationServiceType.values[json['translationService'] ?? 0],
      exerciseService: ExerciseGenerationService.values[json['exerciseService'] ?? 0],
      offlineMode: json['offlineMode'] ?? false,
      serverAddress: json['serverAddress'] ?? "http://localhost:8000",
      exerciseComplexity: json['exerciseComplexity'] ?? "normal",
    );
  }
} 