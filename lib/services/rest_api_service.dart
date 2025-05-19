import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:developer' as developer;
import '../models/flashcard.dart';
import '../providers/settings_provider.dart';
import '../models/settings_model.dart';

class RestApiService {
  final SettingsProvider _settingsProvider;
  
  RestApiService(this._settingsProvider);
  
  String get _baseUrl => _settingsProvider.serverAddress ?? "http://localhost:8000";
  
  /// Логирование запросов к API сервера
  void _logApiCall(String endpoint, {Map<String, dynamic>? requestData, dynamic responseData, int? statusCode, String? error}) {
    final logData = {
      'timestamp': DateTime.now().toIso8601String(),
      'endpoint': endpoint,
      'request': requestData,
      'response': responseData,
      'status_code': statusCode,
      'error': error,
    };
    
    developer.log(jsonEncode(logData), name: 'rest_api_service');
  }
  
  /// Проверка доступности сервера
  Future<bool> checkServerHealth() async {
    try {
      final url = Uri.parse('$_baseUrl/health');
      final response = await http.get(url).timeout(Duration(seconds: 5));
      
      _logApiCall('/health', statusCode: response.statusCode, responseData: response.body);
      
      return response.statusCode == 200;
    } catch (e) {
      _logApiCall('/health', error: e.toString());
      return false;
    }
  }
  
  /// Получение перевода для символа
  /// Параметры:
  /// - hanzi: Китайский символ
  /// - pinyin: Пиньинь (опционально)
  /// - translation: Перевод (опционально)
  /// Возвращает:
  /// - Объект с полями hanzi, pinyin, translation и englishTranslation
  Future<Map<String, String>> getTranslation(String hanzi, {String? pinyin, String? translation}) async {
    try {
      final url = Uri.parse('$_baseUrl/translate');
      
      final requestData = {
        'hanzi': hanzi,
        if (pinyin != null) 'pinyin': pinyin,
        if (translation != null) 'translation': translation,
      };
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode(requestData),
      ).timeout(Duration(seconds: 10));
      
      // Явно указываем кодировку UTF-8 при декодировании
      final responseBody = utf8.decode(response.bodyBytes);
      
      _logApiCall('/translate', 
          requestData: requestData, 
          statusCode: response.statusCode, 
          responseData: responseBody);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        
        developer.log(
          'ARGOS перевод получен: "${hanzi}" -> "${data['english_translation']}" -> "${data['translation']}"',
          name: 'rest_api_service_translation'
        );
        
        return {
          'hanzi': data['hanzi'] ?? hanzi,
          'pinyin': data['pinyin'] ?? '',
          'translation': data['translation'] ?? '',
          'englishTranslation': data['english_translation'] ?? '',
        };
      } else {
        throw Exception('Ошибка при получении перевода: ${response.statusCode}');
      }
    } catch (e) {
      _logApiCall('/translate', requestData: {'hanzi': hanzi}, error: e.toString());
      throw Exception('Ошибка при запросе перевода: $e');
    }
  }
  
  /// Генерация упражнения с использованием Gemma3-IT-QAT и BERT-Chinese-WWM
  /// Параметры:
  /// - flashcard: Карточка для которой нужно сгенерировать упражнение
  /// - complexity: Сложность упражнения (simple, normal, complex)
  /// Возвращает:
  /// - Объект с полями maskedText, options, correctAnswer и др.
  Future<Map<String, dynamic>> generateExercise(Flashcard flashcard, {String complexity = 'normal'}) async {
    try {
      final url = Uri.parse('$_baseUrl/generate');
      
      // Определяем язык системы для перевода
      String systemLanguage = 'ru';
      if (_settingsProvider.language == AppLanguage.english) {
        systemLanguage = 'en';
      }
      
      final requestData = {
        'word': flashcard.hanzi,
        'hsk_level': 3, // Можно сделать динамическим в будущем
        'system_language': systemLanguage,
        'validate': true, // Включаем валидацию BERT-Chinese-WWM
        'retry_on_invalid': true,
      };
      
      developer.log(
        'Отправка запроса на генерацию для "${flashcard.hanzi}" (timeout: 60 сек)',
        name: 'rest_api_service_exercise'
      );
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode(requestData),
      ).timeout(Duration(seconds: 60)); // Увеличиваем таймаут для генерации до 60 секунд
      
      // Явно указываем кодировку UTF-8 при декодировании
      final responseBody = utf8.decode(response.bodyBytes);
      
      _logApiCall('/generate', 
          requestData: requestData, 
          statusCode: response.statusCode, 
          responseData: responseBody);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        
        // Логируем информацию о валидации
        final validation = data['validation'] ?? {};
        final isValid = validation['is_valid'] ?? false;
        final confidence = validation['confidence'] ?? 0.0;
        
        developer.log(
          'Gemma3+BERT упражнение получено: "${flashcard.hanzi}" -> "${data['sentence_with_gap'] ?? ''}" (валидация: ${isValid ? "пройдена" : "не пройдена"}, уверенность: ${(confidence * 100).toStringAsFixed(1)}%)',
          name: 'rest_api_service_exercise'
        );
        
        // Добавляем информацию об источнике
        final source = data['generated_with'] ?? 'Gemma3-4B-IT';
        
        // Преобразуем формат ответа сервера в формат, используемый в приложении
        return {
          'maskedText': data['sentence_with_gap'] ?? '',
          'options': List<String>.from(data['options'] ?? []),
          'correctAnswer': data['answer'] ?? flashcard.hanzi,
          'pinyin': data['pinyin'] ?? '',
          'translation': data['translation'] ?? '',
          'validation': data['validation'] ?? {},
          'sentence': data['sentence'] ?? '',
          'source': 'Сгенерировано с $source',
          'generated_with': source,
        };
      } else {
        throw Exception('Ошибка при генерации упражнения: ${response.statusCode} - ${responseBody}');
      }
    } catch (e) {
      _logApiCall('/generate', 
          requestData: {'word': flashcard.hanzi}, 
          error: e.toString());
      throw Exception('Ошибка при запросе генерации упражнения: $e');
    }
  }
  
  /// Генерация упражнения с пропусками для карточки (устаревший метод)
  Future<Map<String, dynamic>> generateFillBlanksExercise(Flashcard flashcard, {String complexity = 'normal'}) async {
    try {
      final url = Uri.parse('$_baseUrl/generate-exercise');
      
      final requestData = {
        'hanzi': flashcard.hanzi,
        'pinyin': flashcard.pinyin,
        'translation': flashcard.translation,
        'difficulty': 'medium',
        'options_count': 4,
        'complexity': complexity,
      };
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode(requestData),
      ).timeout(Duration(seconds: 15));
      
      // Явно указываем кодировку UTF-8 при декодировании
      final responseBody = utf8.decode(response.bodyBytes);
      
      _logApiCall('/generate-exercise', 
          requestData: requestData, 
          statusCode: response.statusCode, 
          responseData: responseBody);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        
        developer.log(
          'BERT упражнение получено: "${flashcard.hanzi}" -> "${data['masked_text']}" (категория: ${data['category'] ?? 'не указана'})',
          name: 'rest_api_service_exercise'
        );
        
        return {
          'maskedText': data['masked_text'] ?? '',
          'options': List<String>.from(data['options'] ?? []),
          'correctAnswer': data['correct_answer'] ?? flashcard.hanzi,
          'category': data['category'] ?? 'default',
        };
      } else {
        throw Exception('Ошибка при генерации упражнения: ${response.statusCode}');
      }
    } catch (e) {
      _logApiCall('/generate-exercise', 
          requestData: {'hanzi': flashcard.hanzi}, 
          error: e.toString());
      throw Exception('Ошибка при запросе генерации упражнения: $e');
    }
  }
  
  /// Генерация нескольких упражнений для карточек
  Future<List<Map<String, dynamic>>> generateMultipleExercises(List<Flashcard> flashcards, {int count = 5}) async {
    try {
      final url = Uri.parse('$_baseUrl/generate-multiple-exercises');
      
      final requestData = {
        'cards': flashcards.map((card) => {
          'hanzi': card.hanzi,
          'pinyin': card.pinyin,
          'translation': card.translation,
        }).toList(),
        'count': count,
        'difficulty': 'medium',
      };
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode(requestData),
      ).timeout(Duration(seconds: 30));
      
      // Явно указываем кодировку UTF-8 при декодировании
      final responseBody = utf8.decode(response.bodyBytes);
      
      _logApiCall('/generate-multiple-exercises', 
          requestData: {'count': count, 'cards_count': flashcards.length}, 
          statusCode: response.statusCode, 
          responseData: null); // не логируем полный ответ для экономии места
      
      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        return List<Map<String, dynamic>>.from(data['exercises'] ?? []);
      } else {
        throw Exception('Ошибка при генерации упражнений: ${response.statusCode}');
      }
    } catch (e) {
      _logApiCall('/generate-multiple-exercises', 
          requestData: {'cards_count': flashcards.length}, 
          error: e.toString());
      throw Exception('Ошибка при запросе генерации упражнений: $e');
    }
  }
} 