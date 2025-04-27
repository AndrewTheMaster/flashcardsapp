import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:developer' as developer;
import '../models/settings_model.dart';
import 'model_service_provider.dart';

class TranslationService {
  static const String apiUrl = 'https://api.example.com/translate'; // Replace with actual API URL
  
  static bool useLocalModel = true; // Flag to control whether to use local model or network API

  // Main translation function
  static Future<Map<String, String>> translate(String hanzi, {AppLanguage? targetLanguage}) async {
    // Default to local model if available
    if (useLocalModel) {
      try {
        bool isRussian = targetLanguage == AppLanguage.russian;
        return await ModelServiceProvider.translateText(hanzi, isRussian);
      } catch (e) {
        developer.log('TranslationService: Local model failed, falling back to API: $e', name: 'translation');
        // Fall back to online API if local model fails
      }
    }
    
    // Use online API as fallback or if local model is disabled
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'text': hanzi,
          'target_language': targetLanguage == AppLanguage.russian ? 'ru' : 'en',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'pinyin': data['pinyin'] ?? '',
          'translation': data['translation'] ?? '',
        };
      } else {
        // For demo, fallback to simulated translation
        return _simulateTranslation(hanzi, targetLanguage);
      }
    } catch (e) {
      developer.log('TranslationService: API error: $e', name: 'translation');
      return _simulateTranslation(hanzi, targetLanguage);
    }
  }

  // Simulated translations for development
  static Map<String, String> _simulateTranslation(String hanzi, AppLanguage? targetLanguage) {
    // Simple simulation for common characters
    Map<String, Map<String, String>> translations = {
      '我': {'pinyin': 'wǒ', 'en': 'I', 'ru': 'я'},
      '你': {'pinyin': 'nǐ', 'en': 'you', 'ru': 'ты'},
      '他': {'pinyin': 'tā', 'en': 'he', 'ru': 'он'},
      '是': {'pinyin': 'shì', 'en': 'is', 'ru': 'есть'},
      '好': {'pinyin': 'hǎo', 'en': 'good', 'ru': 'хорошо'},
      '中国': {'pinyin': 'zhōng guó', 'en': 'China', 'ru': 'Китай'},
      '学生': {'pinyin': 'xué shēng', 'en': 'student', 'ru': 'студент'},
      '老师': {'pinyin': 'lǎo shī', 'en': 'teacher', 'ru': 'учитель'},
      '朋友': {'pinyin': 'péng yǒu', 'en': 'friend', 'ru': 'друг'},
      '谢谢': {'pinyin': 'xiè xiè', 'en': 'thank you', 'ru': 'спасибо'},
    };

    final isRussian = targetLanguage == AppLanguage.russian;
    
    if (translations.containsKey(hanzi)) {
      final data = translations[hanzi]!;
      final translation = isRussian ? data['ru'] : data['en'];
      return {
        'pinyin': data['pinyin'] ?? '',
        'translation': translation ?? '',
      };
    }
    
    // Default fallback
    return {
      'pinyin': 'pinyin',
      'translation': isRussian ? 'перевод' : 'translation',
    };
  }

  // Batch translate multiple words
  static Future<List<Map<String, String>>> batchTranslate(
    List<String> hanziList, 
    {AppLanguage? targetLanguage}
  ) async {
    List<Map<String, String>> results = [];
    for (var hanzi in hanziList) {
      final translation = await translate(hanzi, targetLanguage: targetLanguage);
      results.add(translation);
    }
    return results;
  }
}
