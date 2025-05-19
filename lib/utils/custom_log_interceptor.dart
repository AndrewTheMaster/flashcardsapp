import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Класс для логирования событий в приложении
class CustomLogInterceptor {
  static const String _tag = 'FlashCards';
  static bool _isEnabled = true;
  static List<String> _logHistory = [];
  static int _maxHistorySize = 100;
  static List<Function(String)> _listeners = [];
  static Function(String)? _callback;
  
  /// Включить/выключить логирование
  static void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }
  
  /// Установка максимального размера истории логов
  static void setMaxHistorySize(int size) {
    _maxHistorySize = size;
    // Обрезаем историю если нужно
    if (_logHistory.length > _maxHistorySize) {
      _logHistory = _logHistory.sublist(_logHistory.length - _maxHistorySize);
    }
  }
  
  /// Установка callback функции для логов
  static void setCallback(Function(String) callback) {
    _callback = callback;
  }
  
  /// Регистрация callback функции для логов (alias для setCallback)
  static void registerCallback(Function(String) callback) {
    _callback = callback;
  }
  
  /// Удаление callback функции
  static void unregisterCallback(Function(String)? callback) {
    if (_callback == callback) {
      _callback = null;
    }
  }
  
  /// Добавление слушателя логов
  static void addListener(Function(String) listener) {
    _listeners.add(listener);
  }
  
  /// Добавление слушателя логов (alias для addListener)
  static void addLogListener(Function(String) listener) {
    addListener(listener);
  }
  
  /// Удаление всех слушателей логов
  static void removeAllListeners() {
    _listeners.clear();
  }
  
  /// Логирование информационного сообщения
  static void log(String message) {
    if (_isEnabled) {
      developer.log(message, name: _tag);
      _logHistory.add(message);
      
      // Обрезаем историю если нужно
      if (_logHistory.length > _maxHistorySize) {
        _logHistory.removeAt(0);
      }
      
      // Вызываем callback если он установлен
      if (_callback != null) {
        _callback!(message);
      }
      
      // Уведомляем слушателей
      for (var listener in _listeners) {
        listener(message);
      }
    }
  }
  
  /// Логирование предупреждения
  static void warning(String message) {
    if (_isEnabled) {
      final warningMessage = '⚠️ $message';
      developer.log(warningMessage, name: _tag);
      _logHistory.add(warningMessage);
      
      // Обрезаем историю если нужно
      if (_logHistory.length > _maxHistorySize) {
        _logHistory.removeAt(0);
      }
      
      // Вызываем callback если он установлен
      if (_callback != null) {
        _callback!(warningMessage);
      }
      
      // Уведомляем слушателей
      for (var listener in _listeners) {
        listener(warningMessage);
      }
    }
  }
  
  /// Логирование ошибки
  static void error(String message) {
    if (_isEnabled) {
      final errorMessage = '❌ $message';
      developer.log(errorMessage, name: _tag, error: message);
      _logHistory.add(errorMessage);
      
      // Обрезаем историю если нужно
      if (_logHistory.length > _maxHistorySize) {
        _logHistory.removeAt(0);
      }
      
      // Вызываем callback если он установлен
      if (_callback != null) {
        _callback!(errorMessage);
      }
      
      // Уведомляем слушателей
      for (var listener in _listeners) {
        listener(errorMessage);
      }
    }
  }
  
  /// Логирование с кастомным тегом
  static void custom(String message, String tag) {
    if (_isEnabled) {
      developer.log(message, name: tag);
      _logHistory.add('[$tag] $message');
      
      // Обрезаем историю если нужно
      if (_logHistory.length > _maxHistorySize) {
        _logHistory.removeAt(0);
      }
      
      // Вызываем callback если он установлен
      if (_callback != null) {
        _callback!('[$tag] $message');
      }
      
      // Уведомляем слушателей
      for (var listener in _listeners) {
        listener('[$tag] $message');
      }
    }
  }
  
  /// Получение истории логов
  static List<String> getLogHistory() {
    return List.from(_logHistory);
  }
  
  /// Очистка истории логов
  static void clearLogHistory() {
    _logHistory.clear();
  }
} 