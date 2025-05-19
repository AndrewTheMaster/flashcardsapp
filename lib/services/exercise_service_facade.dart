import 'dart:developer' as developer;
import '../models/flashcard.dart';
import '../models/settings_model.dart';
import '../providers/settings_provider.dart';
import 'rest_api_service.dart';
import 'exercise_cache_service.dart';
import 'translation_service.dart' as translation_service;

/// Фасад для работы с различными сервисами по генерации упражнений
/// и переводу в зависимости от настроек пользователя
class ExerciseServiceFacade {
  final SettingsProvider _settingsProvider;
  late RestApiService _restApiService;
  late translation_service.TranslationService _translationService;
  String? _lastServerAddress;
  
  ExerciseServiceFacade(this._settingsProvider) {
    _restApiService = RestApiService(_settingsProvider);
    _translationService = translation_service.TranslationService(settingsProvider: _settingsProvider);
    _lastServerAddress = _settingsProvider.serverAddress;
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
    // Проверяем, изменился ли адрес сервера
    bool serverAddressChanged = _checkServerAddressChange();
    
    // Создаем функцию генерации для передачи в сервис кэширования
    Future<Map<String, dynamic>> generateExerciseFn(Flashcard card) async {
      return await generateFillBlanksExercise(card, forceRefresh: forceRefresh || serverAddressChanged);
    }
    
    // Запускаем предварительную загрузку
    await ExerciseCacheService.prefetchExercises(
      flashcards, 
      (card) => generateExerciseFn(card)
    );
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
  Future<Map<String, dynamic>> generateFillBlanksExercise(Flashcard flashcard, {String complexity = 'normal', bool forceRefresh = false}) async {
    final hanzi = flashcard.hanzi;
    
    try {
      // Проверяем режим офлайн и изменение адреса сервера
      final isOffline = _settingsProvider.offlineMode;
      final serverAddressChanged = _checkServerAddressChange();
      
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
          
          return cachedExercise;
        }
      } else if (forceRefresh) {
        developer.log(
          'Пропуск кэша для "$hanzi" (запрошено принудительное обновление)',
          name: 'exercise_service_facade'
        );
      } else if (serverAddressChanged) {
        developer.log(
          'Пропуск кэша для "$hanzi" (изменился адрес сервера)',
          name: 'exercise_service_facade'
        );
      }
      
      developer.log(
        'Генерация упражнения для "$hanzi". Сервис: gemma3BertWwm, офлайн режим: $isOffline, сложность: $complexity', 
        name: 'exercise_service_facade'
      );
      
      Map<String, dynamic> result;
      
      if (isOffline) {
        // В офлайн режиме используем локальную генерацию
        result = _generateLocalExercise(flashcard);
        result['source'] = 'Локальная генерация (офлайн режим)';
        
        // Добавляем заглушки для валидации в офлайн-режиме
        result['validation'] = {
          'is_valid': true,
          'confidence': 0.75,
          'semantic_score': 0.8,
          'distractor_score': 0.7,
          'note': 'Локальная генерация без валидации'
        };
      } else {
        // Используем REST API с Gemma3 + BERT-WWM
        try {
          result = await _restApiService.generateExercise(flashcard, complexity: complexity);
          
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
          // Если произошла ошибка, используем локальную генерацию
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
        }
      }
      
      // Сохраняем результат в кэш
      await ExerciseCacheService.saveExercise(hanzi, result);
      
      return result;
    } catch (e) {
      developer.log('Ошибка генерации упражнения: $e', name: 'exercise_service_facade');
      
      // Возвращаем базовое упражнение при ошибке
      final fallbackResult = {
        'maskedText': '这是 [BLANK]。',
        'options': [flashcard.hanzi, '好', '人', '不'],
        'correctAnswer': flashcard.hanzi,
        'source': 'Аварийный fallback (ошибка генерации)',
        'validation': {
          'is_valid': true,
          'confidence': 0.5,
          'semantic_score': 0.5,
          'distractor_score': 0.5,
          'note': 'Аварийная генерация при ошибке'
        }
      };
      
      // Даже фоллбэк сохраняем в кэш, чтобы не генерировать его постоянно
      await ExerciseCacheService.saveExercise(hanzi, fallbackResult);
      
      return fallbackResult;
    }
  }
  
  /// Локальная генерация простого упражнения
  Map<String, dynamic> _generateLocalExercise(Flashcard flashcard) {
    // Простая локальная генерация
    return {
      'maskedText': '请使用 [BLANK] 造句。',
      'options': [flashcard.hanzi, '这个词', '那个词', '好词'],
      'correctAnswer': flashcard.hanzi,
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