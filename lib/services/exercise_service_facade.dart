import 'dart:developer' as developer;
import '../models/flashcard.dart';
import '../models/settings_model.dart';
import '../providers/settings_provider.dart';
import 'rest_api_service.dart';
import 'exercise_cache_service.dart';
import 'translation_service.dart' as translation_service;
import 'package:dio/dio.dart';  // Добавляем импорт для CancelToken

/// Фасад для работы с различными сервисами по генерации упражнений
/// и переводу в зависимости от настроек пользователя
class ExerciseServiceFacade {
  final SettingsProvider _settingsProvider;
  late RestApiService _restApiService;
  late translation_service.TranslationService _translationService;
  String? _lastServerAddress;
  
  // Флаг для предотвращения параллельных вызовов prefetchExercises
  static bool _prefetchInProgress = false;
  
  // Для ограничения частоты вызовов (throttling)
  static DateTime _lastGenerateTime = DateTime.now().subtract(Duration(hours: 1));
  static const Duration _minGenerateInterval = Duration(seconds: 1); // Увеличено с 500мс до 1000мс
  
  // Для отмены запросов
  final List<CancelToken> _activeCancelTokens = [];
  
  ExerciseServiceFacade(this._settingsProvider) {
    _restApiService = RestApiService(_settingsProvider);
    _translationService = translation_service.TranslationService(settingsProvider: _settingsProvider);
    _lastServerAddress = _settingsProvider.serverAddress;
  }
  
  /// Отмена всех активных запросов и таймеров опроса
  void cancelAllRequests() {
    // Отмена всех активных запросов через токены
    for (var token in _activeCancelTokens) {
      if (!token.isCancelled) {
        token.cancel('Запрос отменен пользователем');
      }
    }
    _activeCancelTokens.clear();
    
    // Отмена всех таймеров опроса статуса задач
    _restApiService.cancelAllTaskPolling();
    
    _prefetchInProgress = false; // Сбрасываем флаг блокировки
    developer.log('Все активные API запросы отменены', name: 'exercise_service_facade');
  }
  
  /// Получение перевода в зависимости от выбранного сервиса
  Future<Map<String, String>> getTranslation(String hanzi, {String? pinyin, String? translation}) async {
    try {
      // Проверяем режим офлайн
      final isOffline = _settingsProvider.offlineMode;
      
      developer.log(
        'Получение перевода для "$hanzi". Сервис: ${_settingsProvider.translationService}, офлайн режим: $isOffline', 
        name: 'exercise_service_facade'
      );
      
      if (isOffline) {
        // В офлайн режиме всегда используем BKRS парсинг через статический метод
        return await translation_service.TranslationService.translateStatic(hanzi);
      } else {
        // Используем выбранный сервис перевода
        return await _translationService.translate(hanzi);
      }
    } catch (e) {
      developer.log('Ошибка перевода: $e', name: 'exercise_service_facade');
      // Возвращаем пустые значения при ошибке
      return {
        'hanzi': hanzi,
        'pinyin': pinyin ?? '',
        'translation': translation ?? '',
        'englishTranslation': '',
      };
    }
  }
  
  /// Предварительная загрузка упражнений для списка карточек
  Future<void> prefetchExercises(List<Flashcard> flashcards, {bool forceRefresh = false}) async {
    // Отмена любой текущей предзагрузки
    if (_prefetchInProgress) {
      cancelAllRequests();
      await Future.delayed(Duration(seconds: 1));
    }
    
    _prefetchInProgress = true;
    
    try {
      // Проверяем наличие карточек
      if (flashcards.isEmpty) {
        developer.log('Пустой список карточек для предзагрузки', name: 'exercise_service_facade');
        return;
      }
      
      // Обрабатываем только первую карточку из списка
      final card = flashcards.first;
      
      developer.log(
        'Предзагрузка для 1 карточки из ${flashcards.length} (строго последовательный режим)',
        name: 'exercise_service_facade'
      );
      
      await ExerciseCacheService.beginBatchCaching();
      
      try {
        // Проверяем, есть ли упражнение уже в кэше
        bool hasCached = false;
        if (!forceRefresh && !_checkServerAddressChange()) {
          hasCached = await ExerciseCacheService.hasCachedExercises(card.hanzi);
        }
        
        if (!hasCached) {
          // Генерируем упражнение для одной карточки
          await generateFillBlanksExercise(card, forceRefresh: forceRefresh);
          developer.log(
            'Предзагрузка упражнения для "${card.hanzi}" завершена успешно',
            name: 'exercise_service_facade'
          );
        } else {
          developer.log(
            'Упражнение для "${card.hanzi}" уже в кэше, пропускаем',
            name: 'exercise_service_facade'
          );
        }
      } catch (e) {
        developer.log(
          'Ошибка при предзагрузке упражнения: $e', 
          name: 'exercise_service_facade'
        );
      }
      
      await ExerciseCacheService.completeBatchCaching();
      
    } finally {
      _prefetchInProgress = false;
    }
  }
  
  /// Проверяет, изменился ли адрес сервера
  bool _checkServerAddressChange() {
    String? currentServerAddress = _settingsProvider.serverAddress;
    bool changed = _lastServerAddress != currentServerAddress;
    
    if (changed) {
      developer.log(
        'Обнаружено изменение адреса сервера: $_lastServerAddress -> $currentServerAddress. Кэш будет обновлен.',
        name: 'exercise_service_facade'
      );
      
      // Обновляем сохраненный адрес
      _lastServerAddress = currentServerAddress;
    }
    
    return changed;
  }
  
  /// Генерация упражнения с пропусками
  Future<Map<String, dynamic>> generateFillBlanksExercise(Flashcard flashcard, {
    String complexity = 'normal', 
    bool forceRefresh = false,
    Function(double progress)? onProgress,
  }) async {
    final hanzi = flashcard.hanzi;
    
    try {
      // Проверяем режим офлайн и изменение адреса сервера
      final isOffline = _settingsProvider.offlineMode;
      final serverAddressChanged = _checkServerAddressChange();
      
      // Применяем throttling для предотвращения слишком частых обращений к API
      final now = DateTime.now();
      final timeSinceLastCall = now.difference(_lastGenerateTime);
      if (timeSinceLastCall < _minGenerateInterval) {
        // Слишком частые запросы, делаем паузу
        final delay = _minGenerateInterval - timeSinceLastCall;
        developer.log(
          'Применение задержки ${delay.inMilliseconds}мс для предотвращения частых API вызовов',
          name: 'exercise_service_facade'
        );
        await Future.delayed(delay);
      }
      _lastGenerateTime = DateTime.now();
      
      // Выводим лог после применения throttling
      developer.log(
        'Генерация упражнения для "$hanzi". Сервис: ${_settingsProvider.exerciseService}, офлайн режим: $isOffline, сложность: $complexity', 
        name: 'exercise_service_facade'
      );
      
      // Если нужно принудительное обновление или изменился адрес сервера, пропускаем проверку кэша
      if (!forceRefresh && !serverAddressChanged) {
        // Проверяем кэш только если не требуется обновление
        final cachedExercise = await ExerciseCacheService.getExercise(hanzi);
        if (cachedExercise != null) {
          developer.log(
            'Использование кэшированного упражнения для "$hanzi"',
            name: 'exercise_service_facade'
          );
          // Добавляем информацию об источнике
          final cacheTotal = cachedExercise['cache_total'] ?? 1;
          final cacheIndex = cachedExercise['cache_index'] ?? 0;
          cachedExercise['source'] = 'Из кэша (${cacheIndex + 1}/${cacheTotal})';
          
          // Проверяем есть ли информация о валидации
          if (!cachedExercise.containsKey('validation')) {
            cachedExercise['validation'] = {
              'is_valid': true,
              'confidence': 0.8,
              'semantic_score': 0.8,
              'distractor_score': 0.8,
              'note': 'Значения по умолчанию (из кэша)'
            };
          }
          
          // Если есть callback для прогресса, вызываем его с 1.0 (100%)
          if (onProgress != null) {
            onProgress(1.0);
          }
          
          return cachedExercise;
        }
      }
      
      Map<String, dynamic> result;
      
      if (isOffline) {
        // В офлайн режиме используем локальную генерацию
        result = _generateLocalExercise(flashcard);
        result['source'] = 'Локальная генерация (офлайн режим)';
        
        // Добавляем заглушки для валидации
        result['validation'] = {
          'is_valid': true,
          'confidence': 0.7,
          'semantic_score': 0.7,
          'distractor_score': 0.7,
          'note': 'Локальная генерация без валидации'
        };
        
        // Если есть callback для прогресса, вызываем его с 1.0 (100%)
        if (onProgress != null) {
          onProgress(1.0);
        }
      } else {
        // Создаем токен отмены для запроса
        final cancelToken = CancelToken();
        _activeCancelTokens.add(cancelToken);
        
        // Онлайн режим - используем REST API
        try {
          // Увеличиваем таймаут и включаем асинхронный режим
          result = await _restApiService.generateExercise(
            flashcard,
            complexity: complexity,
            cancelToken: cancelToken,
            timeout: Duration(seconds: 60), // Увеличиваем таймаут с 30 до 60 секунд
            useAsyncMode: true, // Включаем асинхронный режим
            onProgress: onProgress, // Передаем callback для отслеживания прогресса
          );
          
          // Добавляем информацию об источнике, если её нет
          if (!result.containsKey('source')) {
            final generatedWith = result['generated_with'] ?? 'Gemma3 + BERT';
            result['source'] = 'Сгенерировано сервером ($generatedWith)';
          }
          
          // Логируем информацию о валидации
          final validation = result['validation'] ?? {};
          final isValid = validation['is_valid'] ?? false;
          final confidence = validation['confidence'] ?? 0.0;
          
          developer.log(
            'Валидация упражнения: ${isValid ? "пройдена" : "не пройдена"}, ' +
            'уверенность: ${(confidence * 100).toStringAsFixed(1)}%, ' +
            'семантика: ${(validation['semantic_score'] ?? 0.0) * 100}%, ' +
            'дистракторы: ${(validation['distractor_score'] ?? 0.0) * 100}%',
            name: 'exercise_service_facade'
          );
        } catch (e) {
          developer.log(
            'Ошибка генерации упражнения через REST API: $e', 
            name: 'exercise_service_facade'
          );

          // При ошибке, пробуем использовать кэш, даже если запрашивалось обновление
          final cachedExercise = await ExerciseCacheService.getExercise(hanzi);
          if (cachedExercise != null) {
            developer.log(
              'Используем кэшированное упражнение после ошибки для "$hanzi"',
              name: 'exercise_service_facade'
            );
            
            // Если есть callback для прогресса, вызываем его с 1.0 (100%)
            if (onProgress != null) {
              onProgress(1.0);
            }
            
            return cachedExercise;
          }
          
          // Если произошла ошибка и в кэше ничего нет, используем локальную генерацию
          result = _generateLocalExercise(flashcard);
          result['source'] = 'Локальный fallback (ошибка сервера)';
          
          // Добавляем заглушки для валидации при ошибке
          result['validation'] = {
            'is_valid': true,
            'confidence': 0.5,
            'semantic_score': 0.5,
            'distractor_score': 0.5,
            'note': 'Локальная генерация из-за ошибки сервера'
          };
          
          // Если есть callback для прогресса, вызываем его с 1.0 (100%)
          if (onProgress != null) {
            onProgress(1.0);
          }
        } finally {
          // Удаляем токен отмены из списка активных
          _activeCancelTokens.remove(cancelToken);
        }
      }
      
      // Сохраняем результат в кэш
      await ExerciseCacheService.saveExercise(hanzi, result);
      
      return result;
    } catch (e) {
      developer.log('Ошибка генерации упражнения: $e', name: 'exercise_service_facade');
      
      // Если есть callback для прогресса, вызываем его с 1.0 (100%), даже при ошибке
      if (onProgress != null) {
        onProgress(1.0);
      }
      
      // Возвращаем базовое упражнение при ошибке
      return _createFallbackExercise(flashcard);
    }
  }
  
  /// Создание запасного упражнения в случае ошибки
  Map<String, dynamic> _createFallbackExercise(Flashcard flashcard) {
    final hanzi = flashcard.hanzi;
    final pinyin = flashcard.pinyin;
    final translation = flashcard.translation;
    
    return {
      'maskedText': '这是 [BLANK]。',
      'options': [hanzi, '好', '人', '不'],
      'correctAnswer': hanzi,
      'pinyin': pinyin,
      'translation': translation,
      'source': 'Аварийный fallback (ошибка генерации)',
      'validation': {
        'is_valid': true,
        'confidence': 0.5,
        'semantic_score': 0.5,
        'distractor_score': 0.5,
        'note': 'Аварийная генерация при ошибке'
      }
    };
  }
  
  /// Локальная генерация простого упражнения
  Map<String, dynamic> _generateLocalExercise(Flashcard flashcard) {
    // Простая локальная генерация
    return {
      'maskedText': '请使用 [BLANK] 造句。',
      'options': [flashcard.hanzi, '这个词', '那个词', '好词'],
      'correctAnswer': flashcard.hanzi,
      'pinyin': flashcard.pinyin,
      'translation': flashcard.translation,
      'category': 'local',
      'source': 'Локальная генерация'
    };
  }
  
  /// Проверка доступности сервера
  Future<bool> checkServerAvailability() async {
    try {
      return await _restApiService.checkServerHealth();
    } catch (e) {
      developer.log('Ошибка проверки сервера: $e', name: 'exercise_service_facade');
      return false;
    }
  }
  
  /// Очистка кэша упражнений
  Future<void> clearExerciseCache() async {
    await ExerciseCacheService.clearCache();
    developer.log('Кэш упражнений очищен', name: 'exercise_service_facade');
  }
  
  /// Получение метаданных последнего сгенерированного упражнения
  Future<Map<String, dynamic>> getLastExerciseMetadata(String hanzi) async {
    try {
      // Пытаемся получить метаданные из кэша
      final exerciseData = await ExerciseCacheService.getExercise(hanzi);
      
      if (exerciseData != null) {
        // Добавляем источник, если он не был указан
        if (!exerciseData.containsKey('source')) {
          final cacheTotal = exerciseData['cache_total'] ?? 1;
          final cacheIndex = exerciseData['cache_index'] ?? 0;
          exerciseData['source'] = 'Из кэша (${cacheIndex + 1}/${cacheTotal})';
        }
        return exerciseData;
      }
      
      // Базовые метаданные если ничего не найдено
      return {
        'source': 'Неизвестно (не найдено в кэше)',
      };
    } catch (e) {
      developer.log('Ошибка получения метаданных упражнения: $e', name: 'exercise_service_facade');
      return {
        'source': 'Ошибка получения метаданных',
      };
    }
  }
  
  /// Получение следующего упражнения для слова
  Future<Map<String, dynamic>> getNextExercise(Flashcard flashcard) async {
    final hanzi = flashcard.hanzi;
    
    try {
      // Получаем текущие метаданные из кэша
      final currentExercise = await ExerciseCacheService.getExercise(hanzi);
      
      if (currentExercise != null) {
        final currentIndex = currentExercise['cache_index'] ?? 0;
        final totalExercises = currentExercise['cache_total'] ?? 1;
        
        // Если упражнений в кэше больше одного, получаем следующее
        if (totalExercises > 1) {
          final nextExercise = await ExerciseCacheService.getNextExercise(hanzi, currentIndex);
          if (nextExercise != null) {
            developer.log(
              'Переход к следующему упражнению для "$hanzi" (${nextExercise['cache_index'] + 1}/${nextExercise['cache_total']})',
              name: 'exercise_service_facade'
            );
            
            // Добавляем информацию об источнике
            nextExercise['source'] = 'Из кэша (${nextExercise['cache_index'] + 1}/${nextExercise['cache_total']})';
            return nextExercise;
          }
        }
      }
      
      // Если нет следующего упражнения или что-то пошло не так, генерируем новое
      return await generateFillBlanksExercise(flashcard, forceRefresh: true);
    } catch (e) {
      developer.log('Ошибка при получении следующего упражнения: $e', name: 'exercise_service_facade');
      return await generateFillBlanksExercise(flashcard, forceRefresh: true);
    }
  }
} 