import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import '../models/flashcard.dart';

/// Сервис для кэширования сгенерированных упражнений
class ExerciseCacheService {
  static const String _cacheKey = 'exercise_cache';
  static const int _maxCacheSize = 100; // Максимальное количество кэшированных упражнений
  static const int _maxExercisesPerWord = 5; // Максимальное количество упражнений для одного слова
  
  /// Получение упражнения из кэша
  /// Возвращает null, если упражнение не найдено
  /// Параметр index позволяет выбрать конкретное упражнение из кэша, если их несколько
  static Future<Map<String, dynamic>?> getExercise(String hanzi, {int? index}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cacheJson = prefs.getString(_cacheKey);
      
      if (cacheJson == null) {
        return null;
      }
      
      final Map<String, dynamic> cache = jsonDecode(cacheJson);
      final dynamic exerciseData = cache[hanzi];
      
      if (exerciseData == null) {
        return null;
      }
      
      // Проверяем, сохранен ли массив упражнений или одиночное упражнение
      if (exerciseData is List) {
        if (exerciseData.isEmpty) {
          return null;
        }
        
        // Если указан индекс, берем его, иначе берем случайное упражнение
        final exerciseIndex = index ?? (DateTime.now().millisecondsSinceEpoch % exerciseData.length);
        final selectedExercise = exerciseData[exerciseIndex];
        
        developer.log('Получено упражнение из кэша для "$hanzi" (${exerciseIndex + 1}/${exerciseData.length})', 
            name: 'exercise_cache');
        
        // Добавляем информацию о индексе упражнения
        final result = Map<String, dynamic>.from(selectedExercise);
        result['cache_index'] = exerciseIndex;
        result['cache_total'] = exerciseData.length;
        return result;
      } else {
        // Обратная совместимость со старым форматом (одиночное упражнение)
        developer.log('Получено упражнение из кэша для "$hanzi" (устаревший формат)', 
            name: 'exercise_cache');
        
        // Преобразуем старый формат в новый при чтении
        final result = Map<String, dynamic>.from(exerciseData);
        result['cache_index'] = 0;
        result['cache_total'] = 1;
        return result;
      }
    } catch (e) {
      developer.log('Ошибка при получении упражнения из кэша: $e', name: 'exercise_cache');
      return null;
    }
  }
  
  /// Получение следующего упражнения для слова
  /// Циклически переходит к следующему упражнению в списке
  static Future<Map<String, dynamic>?> getNextExercise(String hanzi, int currentIndex) async {
    try {
      final allExercises = await getAllExercises(hanzi);
      if (allExercises == null || allExercises.isEmpty) {
        return null;
      }
      
      // Переходим к следующему упражнению циклически
      final nextIndex = (currentIndex + 1) % allExercises.length;
      return await getExercise(hanzi, index: nextIndex);
    } catch (e) {
      developer.log('Ошибка при получении следующего упражнения: $e', name: 'exercise_cache');
      return null;
    }
  }
  
  /// Получение всех упражнений для слова из кэша
  static Future<List<Map<String, dynamic>>?> getAllExercises(String hanzi) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cacheJson = prefs.getString(_cacheKey);
      
      if (cacheJson == null) {
        return null;
      }
      
      final Map<String, dynamic> cache = jsonDecode(cacheJson);
      final dynamic exerciseData = cache[hanzi];
      
      if (exerciseData == null) {
        return null;
      }
      
      // Проверяем, сохранен ли массив упражнений или одиночное упражнение
      if (exerciseData is List) {
        developer.log('Получено ${exerciseData.length} упражнений из кэша для "$hanzi"', 
            name: 'exercise_cache');
        
        return exerciseData.map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        // Обратная совместимость со старым форматом (одиночное упражнение)
        developer.log('Получено 1 упражнение из кэша для "$hanzi" (устаревший формат)', 
            name: 'exercise_cache');
        
        return [Map<String, dynamic>.from(exerciseData)];
      }
    } catch (e) {
      developer.log('Ошибка при получении всех упражнений из кэша: $e', name: 'exercise_cache');
      return null;
    }
  }
  
  /// Получение количества упражнений для слова в кэше
  static Future<int> getExerciseCount(String hanzi) async {
    try {
      final exercises = await getAllExercises(hanzi);
      return exercises?.length ?? 0;
    } catch (e) {
      developer.log('Ошибка при подсчете упражнений в кэше: $e', name: 'exercise_cache');
      return 0;
    }
  }
  
  /// Сохранение упражнения в кэш
  static Future<void> saveExercise(String hanzi, Map<String, dynamic> exerciseData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? cacheJson = prefs.getString(_cacheKey);
      
      Map<String, dynamic> cache = {};
      if (cacheJson != null) {
        cache = Map<String, dynamic>.from(jsonDecode(cacheJson));
      }
      
      // Проверяем, есть ли уже упражнения для этого слова
      if (cache.containsKey(hanzi)) {
        final dynamic existingData = cache[hanzi];
        
        // Преобразуем в список, если это еще не список
        List<dynamic> exercisesList;
        if (existingData is List) {
          exercisesList = existingData;
        } else {
          // Старый формат - превращаем в список с одним элементом
          exercisesList = [existingData];
        }
        
        // Проверяем на дубликат содержимого
        bool isDuplicate = false;
        for (var existing in exercisesList) {
          if (existing['maskedText'] == exerciseData['maskedText']) {
            isDuplicate = true;
            break;
          }
        }
        
        // Добавляем новое упражнение, если это не дубликат
        if (!isDuplicate) {
          // Проверяем лимит упражнений для слова
          if (exercisesList.length >= _maxExercisesPerWord) {
            // Удаляем самое старое упражнение
            exercisesList.removeAt(0);
          }
          exercisesList.add(exerciseData);
          
          developer.log('Упражнение для "$hanzi" добавлено в кэш (всего: ${exercisesList.length})', 
              name: 'exercise_cache');
        } else {
          developer.log('Упражнение для "$hanzi" не добавлено в кэш (дубликат)', 
              name: 'exercise_cache');
        }
        
        cache[hanzi] = exercisesList;
      } else {
        // Ограничиваем размер кэша (по количеству слов)
        if (cache.length >= _maxCacheSize && !cache.containsKey(hanzi)) {
          // Удаляем случайный элемент для освобождения места
          final String keyToRemove = cache.keys.first;
          cache.remove(keyToRemove);
          developer.log('Удален кэш для "$keyToRemove" для освобождения места', 
              name: 'exercise_cache');
        }
        
        // Добавляем новое упражнение в виде списка
        cache[hanzi] = [exerciseData];
        developer.log('Создан новый кэш для "$hanzi"', name: 'exercise_cache');
      }
      
      await prefs.setString(_cacheKey, jsonEncode(cache));
    } catch (e) {
      developer.log('Ошибка при сохранении упражнения в кэш: $e', name: 'exercise_cache');
    }
  }
  
  /// Предварительная загрузка упражнений для списка карточек
  static Future<void> prefetchExercises(List<Flashcard> flashcards, Function(Flashcard) generateExercise) async {
    try {
      developer.log('Начало предварительной загрузки упражнений для ${flashcards.length} карточек', name: 'exercise_cache');
      
      for (final flashcard in flashcards) {
        // Проверяем, есть ли упражнение в кэше
        final cachedExercise = await getExercise(flashcard.hanzi);
        
        if (cachedExercise == null) {
          // Если упражнения нет в кэше, генерируем его
          try {
            final exerciseData = await generateExercise(flashcard);
            await saveExercise(flashcard.hanzi, exerciseData);
          } catch (e) {
            developer.log('Ошибка при предзагрузке упражнения для ${flashcard.hanzi}: $e', name: 'exercise_cache');
            // Продолжаем с следующей карточкой
            continue;
          }
        }
      }
      
      developer.log('Предварительная загрузка упражнений завершена', name: 'exercise_cache');
    } catch (e) {
      developer.log('Ошибка при предварительной загрузке упражнений: $e', name: 'exercise_cache');
    }
  }
  
  /// Очистка кэша
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      developer.log('Кэш упражнений очищен', name: 'exercise_cache');
    } catch (e) {
      developer.log('Ошибка при очистке кэша упражнений: $e', name: 'exercise_cache');
    }
  }
} 