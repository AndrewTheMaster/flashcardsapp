import 'package:flutter/material.dart';

enum AppLanguage { english, russian }

class SettingsModel {
  AppLanguage language;
  ThemeMode themeMode;
  bool notificationsEnabled;
  int reviewInterval;

  SettingsModel({
    this.language = AppLanguage.english,
    this.themeMode = ThemeMode.system,
    this.notificationsEnabled = true,
    this.reviewInterval = 1,
  });

  Map<String, dynamic> toJson() {
    return {
      'language': language.index,
      'themeMode': themeMode.index,
      'notificationsEnabled': notificationsEnabled,
      'reviewInterval': reviewInterval,
    };
  }

  factory SettingsModel.fromJson(Map<String, dynamic> json) {
    return SettingsModel(
      language: AppLanguage.values[json['language'] ?? 0],
      themeMode: ThemeMode.values[json['themeMode'] ?? 0],
      notificationsEnabled: json['notificationsEnabled'] ?? true,
      reviewInterval: json['reviewInterval'] ?? 1,
    );
  }

  SettingsModel copyWith({
    AppLanguage? language,
    ThemeMode? themeMode,
    bool? notificationsEnabled,
    int? reviewInterval,
  }) {
    return SettingsModel(
      language: language ?? this.language,
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      reviewInterval: reviewInterval ?? this.reviewInterval,
    );
  }
} 