import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:developer' as developer;
import '../models/flashcard.dart';
import '../providers/settings_provider.dart';
import '../models/settings_model.dart';
import 'package:dio/dio.dart';  // Добавляем Dio для поддержки CancelToken
import 'package:dio_smart_retry/dio_smart_retry.dart'; // Импорт для автоматических повторных попыток

class RestApiService {
  final SettingsProvider _settingsProvider;
  final Dio _dio = Dio(); // Инициализируем Dio для HTTP запросов
  
  // Map для хранения полученных задач и их статусов
  final Map<String, Timer> _taskPollingTimers = {};
  
  RestApiService(this._settingsProvider) {
    // Инициализация Dio с настройками повторных попыток
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 60); // Увеличен до 60 секунд
    _dio.options.sendTimeout = const Duration(seconds: 30);
    
    // Добавляем интерцептор для повторных попыток при ошибках сети
    _dio.interceptors.add(
      RetryInterceptor(
        dio: _dio,
        logPrint: (message) => developer.log(message, name: 'dio_retry'),
        retries: 3, // количество повторных попыток
        retryDelays: const [
          Duration(seconds: 1), // пауза перед первой повторной попыткой
          Duration(seconds: 2), // перед второй
          Duration(seconds: 3), // перед третьей
        ],
      ),
    );
  }
  
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
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      
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
  Future<Map<String, String>> getTranslation(String hanzi, {String? pinyin, String? translation, CancelToken? cancelToken}) async {
    try {
      final url = Uri.parse('$_baseUrl/translate');
      
      final requestData = {
        'hanzi': hanzi,
        if (pinyin != null) 'pinyin': pinyin,
        if (translation != null) 'translation': translation,
      };
      
      final Response response = await _dio.postUri(
        url,
        data: requestData,
        options: Options(
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          responseType: ResponseType.json,
          sendTimeout: const Duration(seconds: 20),  // Увеличиваем таймаут
          receiveTimeout: const Duration(seconds: 20),  // Увеличиваем таймаут
        ),
        cancelToken: cancelToken,
      );
      
      _logApiCall('/translate', 
          requestData: requestData, 
          statusCode: response.statusCode, 
          responseData: response.data);
      
      if (response.statusCode == 200) {
        final data = response.data;
        
        developer.log(
          'ARGOS перевод получен: "${hanzi}" -> "${data['english_translation'] ?? ''}" -> "${data['translation'] ?? ''}"',
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
  
  /// Отмена всех активных таймеров опроса задач
  void cancelAllTaskPolling() {
    _taskPollingTimers.forEach((taskId, timer) {
      timer.cancel();
    });
    _taskPollingTimers.clear();
    developer.log('Все активные таймеры опроса задач отменены', name: 'rest_api_service');
  }
  
  /// Генерация упражнения с использованием Gemma3-IT-QAT и BERT-Chinese-WWM
  /// Параметры:
  /// - flashcard: Карточка для которой нужно сгенерировать упражнение
  /// - complexity: Сложность упражнения (simple, normal, complex)
  /// - cancelToken: Токен для отмены запроса
  /// - timeout: Таймаут запроса (по умолчанию 60 секунд)
  /// - useAsyncMode: Использовать асинхронную генерацию с поллингом (по умолчанию true)
  /// Возвращает:
  /// - Объект с полями maskedText, options, correctAnswer и др.
  Future<Map<String, dynamic>> generateExercise(
    Flashcard flashcard, {
    String complexity = 'normal',
    CancelToken? cancelToken,
    Duration timeout = const Duration(seconds: 60),
    bool useAsyncMode = true,
    Function(double progress)? onProgress,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/generate');
      
      // Добавляем логирование стека вызовов для отладки
      String stackTrace = StackTrace.current.toString().split('\n').take(5).join('\n');
      developer.log(
        'Вызов API generateExercise из:\n$stackTrace',
        name: 'rest_api_service_debug'
      );
      
      // Определяем язык системы для перевода
      String systemLanguage = 'ru';
      if (_settingsProvider.language == AppLanguage.english) {
        systemLanguage = 'en';
      }
      
      final requestData = {
        'word': flashcard.hanzi,
        'hsk_level': 3, // Фиксированное значение HSK
        'system_language': systemLanguage,
        'validate': true, // Включаем валидацию BERT-Chinese-WWM
        'retry_on_invalid': true,
        'fast_response': useAsyncMode, // Включаем асинхронный режим
      };
      
      developer.log(
        'Отправка запроса на генерацию для "${flashcard.hanzi}" (timeout: ${timeout.inSeconds} сек, async: $useAsyncMode)',
        name: 'rest_api_service_exercise'
      );
      
      final Response response = await _dio.postUri(
        url,
        data: requestData,
        options: Options(
          contentType: 'application/json',
          responseType: ResponseType.json,
          sendTimeout: const Duration(seconds: 30),  // Увеличиваем таймаут для initial запроса
          receiveTimeout: timeout,  // Используем переданный таймаут (60 секунд по умолчанию)
        ),
        cancelToken: cancelToken,
      );
      
      _logApiCall('/generate', 
          requestData: requestData, 
          statusCode: response.statusCode, 
          responseData: response.data != null ? json.encode(response.data) : null);
      
      if (response.statusCode == 200) {
        final data = response.data;
        
        // Проверяем, получен ли task_id вместо готового результата
        if (useAsyncMode && data['task_id'] != null) {
          final taskId = data['task_id'];
          developer.log(
            'Получен task_id: $taskId. Начинаем опрос статуса задачи.',
            name: 'rest_api_service_exercise'
          );
          
          // Запускаем опрос статуса задачи
          return await _pollTaskStatus(
            taskId, 
            flashcard.hanzi,
            cancelToken: cancelToken,
            timeout: timeout,
            onProgress: onProgress,
          );
        }
        
        // Если получен готовый результат сразу
        return _processExerciseResult(data, flashcard);
      } else {
        throw Exception('Ошибка при генерации упражнения: ${response.statusCode}');
      }
    } on DioException catch (e) {
      // Обрабатываем исключения Dio отдельно
      if (CancelToken.isCancel(e)) {
        developer.log('Запрос отменен пользователем', name: 'rest_api_service');
        throw Exception('Запрос отменен пользователем');
      } else if (e.type == DioExceptionType.connectionTimeout ||
                 e.type == DioExceptionType.receiveTimeout ||
                 e.type == DioExceptionType.sendTimeout) {
        developer.log('Таймаут запроса: ${e.message}', name: 'rest_api_service');
        throw Exception('Превышено время ожидания ответа от сервера (${e.type}). Проверьте подключение и повторите попытку.');
      }
      
      _logApiCall('/generate', 
          requestData: {'word': flashcard.hanzi}, 
          error: 'DioException: ${e.message}');
      throw Exception('Ошибка при запросе генерации упражнения: ${e.message}');
    } catch (e) {
      _logApiCall('/generate', 
          requestData: {'word': flashcard.hanzi}, 
          error: e.toString());
      throw Exception('Ошибка при запросе генерации упражнения: $e');
    }
  }
  
  /// Метод для опроса статуса задачи с сервера
  Future<Map<String, dynamic>> _pollTaskStatus(
    String taskId, 
    String originalWord, {
    CancelToken? cancelToken,
    Duration timeout = const Duration(seconds: 60),
    Function(double progress)? onProgress,
  }) async {
    // Создаем Completer для управления асинхронным результатом
    final completer = Completer<Map<String, dynamic>>();
    
    // Устанавливаем максимальное количество попыток и интервал опроса
    final maxAttempts = 30; // Максимальное количество попыток
    final pollInterval = const Duration(seconds: 2); // Интервал между опросами
    int attempt = 0;
    int consecutiveErrorCount = 0; // Счетчик последовательных ошибок
    final maxConsecutiveErrors = 3; // Максимальное количество последовательных ошибок
    
    void pollTask() {
      // Если задача была отменена, прекращаем опрос
      if (cancelToken?.isCancelled ?? false) {
        if (!completer.isCompleted) {
          completer.completeError(Exception('Запрос отменен пользователем'));
        }
        return;
      }
      
      // Если превышено максимальное время ожидания
      if (attempt >= maxAttempts) {
        if (!completer.isCompleted) {
          completer.completeError(Exception('Превышено максимальное время ожидания генерации упражнения (60 секунд)'));
        }
        return;
      }
      
      attempt++;
      
      // Обновляем прогресс
      if (onProgress != null) {
        final progress = (attempt / maxAttempts) * 0.9; // 90% прогресса - опрос статуса
        onProgress(progress);
      }
      
      // Выполняем запрос статуса задачи
      _dio.getUri(
        Uri.parse('$_baseUrl/task/$taskId'),
        options: Options(
          responseType: ResponseType.json,
          receiveTimeout: const Duration(seconds: 30), // Увеличен с 10 до 30 секунд
          sendTimeout: const Duration(seconds: 30),    // Увеличен с 10 до 30 секунд
        ),
        cancelToken: cancelToken,
      ).then((response) {
        if (response.statusCode == 200) {
          final data = response.data;
          final status = data['status'];
          
          // Сбрасываем счетчик ошибок при успешном запросе
          consecutiveErrorCount = 0;
          
          if (status == 'completed') {
            // Задача завершена, получаем результат
            developer.log(
              'Задача $taskId завершена успешно. Результат получен.',
              name: 'rest_api_service_exercise'
            );
            
            if (onProgress != null) {
              onProgress(1.0); // 100% прогресса - задача завершена
            }
            
            if (!completer.isCompleted) {
              final result = data['result'];
              completer.complete(_processExerciseResult(result, Flashcard(
                hanzi: originalWord,
                pinyin: '',
                translation: '',
              )));
            }
            
            // Отменяем таймер
            if (_taskPollingTimers.containsKey(taskId)) {
              _taskPollingTimers[taskId]?.cancel();
              _taskPollingTimers.remove(taskId);
            }
          } else if (status == 'error') {
            // Задача завершилась с ошибкой
            developer.log(
              'Задача $taskId завершена с ошибкой: ${data['error'] ?? "Неизвестная ошибка"}',
              name: 'rest_api_service_exercise'
            );
            
            if (!completer.isCompleted) {
              completer.completeError(Exception('Ошибка генерации упражнения: ${data['error'] ?? "Неизвестная ошибка"}'));
            }
            
            // Отменяем таймер
            if (_taskPollingTimers.containsKey(taskId)) {
              _taskPollingTimers[taskId]?.cancel();
              _taskPollingTimers.remove(taskId);
            }
          } else if (status == 'processing') {
            // Задача все еще выполняется, но сервер отправляет информацию о прогрессе
            final progress = data['progress'] as double? ?? 0.0;
            
            if (onProgress != null) {
              // Обновляем прогресс на основе информации от сервера (умножаем на 0.9, чтобы оставить 10% на финальный этап)
              onProgress(progress * 0.9);
            }
            
            developer.log(
              'Задача $taskId выполняется: прогресс $progress. Попытка $attempt из $maxAttempts',
              name: 'rest_api_service_exercise'
            );
          } else {
            // Задача все еще выполняется, продолжаем опрос
            developer.log(
              'Задача $taskId все еще выполняется. Попытка $attempt из $maxAttempts',
              name: 'rest_api_service_exercise'
            );
          }
        } else {
          // Увеличиваем счетчик ошибок
          consecutiveErrorCount++;
          
          developer.log(
            'Ошибка при получении статуса задачи: ${response.statusCode}. Последовательные ошибки: $consecutiveErrorCount/$maxConsecutiveErrors',
            name: 'rest_api_service_exercise'
          );
          
          // Если количество последовательных ошибок превысило лимит, завершаем с ошибкой
          if (consecutiveErrorCount >= maxConsecutiveErrors) {
            if (!completer.isCompleted) {
              completer.completeError(Exception('Слишком много ошибок при попытке получить статус задачи'));
            }
            
            // Отменяем таймер
            if (_taskPollingTimers.containsKey(taskId)) {
              _taskPollingTimers[taskId]?.cancel();
              _taskPollingTimers.remove(taskId);
            }
          }
        }
      }).catchError((e) {
        // Увеличиваем счетчик ошибок
        consecutiveErrorCount++;
        
        developer.log(
          'Ошибка при опросе статуса задачи: $e. Последовательные ошибки: $consecutiveErrorCount/$maxConsecutiveErrors',
          name: 'rest_api_service_exercise'
        );
        
        // Если количество последовательных ошибок превысило лимит, завершаем с ошибкой
        if (consecutiveErrorCount >= maxConsecutiveErrors) {
          if (!completer.isCompleted) {
            if (e is DioException && 
                (e.type == DioExceptionType.connectionTimeout ||
                 e.type == DioExceptionType.receiveTimeout ||
                 e.type == DioExceptionType.sendTimeout)) {
              completer.completeError(Exception('Превышено время ожидания ответа от сервера при опросе статуса задачи'));
            } else {
              completer.completeError(Exception('Слишком много ошибок при попытке получить статус задачи: $e'));
            }
          }
          
          // Отменяем таймер
          if (_taskPollingTimers.containsKey(taskId)) {
            _taskPollingTimers[taskId]?.cancel();
            _taskPollingTimers.remove(taskId);
          }
        }
      });
    }
    
    // Запускаем опрос с указанным интервалом
    _taskPollingTimers[taskId] = Timer.periodic(pollInterval, (_) => pollTask());
    
    // Вызываем первый опрос сразу
    pollTask();
    
    // Устанавливаем общий таймаут на операцию
    Timer(timeout, () {
      if (!completer.isCompleted) {
        // Отменяем таймер опроса
        if (_taskPollingTimers.containsKey(taskId)) {
          _taskPollingTimers[taskId]?.cancel();
          _taskPollingTimers.remove(taskId);
        }
        
        completer.completeError(Exception('Превышено время ожидания ответа от сервера (${timeout.inSeconds} сек). Генерация упражнения слишком долгая.'));
      }
    });
    
    return completer.future;
  }
  
  /// Метод для обработки результата упражнения
  Map<String, dynamic> _processExerciseResult(Map<String, dynamic> data, Flashcard flashcard) {
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
  }
  
  /// Генерация упражнения с пропусками для карточки (устаревший метод)
  Future<Map<String, dynamic>> generateFillBlanksExercise(Flashcard flashcard, {
    String complexity = 'normal',
    CancelToken? cancelToken, 
    Duration timeout = const Duration(seconds: 15)
  }) async {
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
      
      final Response response = await _dio.postUri(
        url,
        data: requestData,
        options: Options(
          contentType: 'application/json',
          responseType: ResponseType.json,
          sendTimeout: timeout,
          receiveTimeout: timeout,
        ),
        cancelToken: cancelToken,
      ).timeout(timeout);
      
      _logApiCall('/generate-exercise', 
          requestData: requestData, 
          statusCode: response.statusCode, 
          responseData: response.data);
      
      if (response.statusCode == 200) {
        final data = response.data;
        
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
  Future<List<Map<String, dynamic>>> generateMultipleExercises(
    List<Flashcard> flashcards, {
    int count = 5,
    CancelToken? cancelToken,
    Duration timeout = const Duration(seconds: 30)
  }) async {
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
      
      final Response response = await _dio.postUri(
        url,
        data: requestData,
        options: Options(
          contentType: 'application/json',
          responseType: ResponseType.json,
          sendTimeout: timeout,
          receiveTimeout: timeout,
        ),
        cancelToken: cancelToken,
      ).timeout(timeout);
      
      _logApiCall('/generate-multiple-exercises', 
          requestData: {'count': count, 'cards_count': flashcards.length}, 
          statusCode: response.statusCode, 
          responseData: null); // не логируем полный ответ для экономии места
      
      if (response.statusCode == 200) {
        final data = response.data;
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