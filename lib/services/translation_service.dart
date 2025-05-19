import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';
import 'dart:developer' as developer;
import 'dart:convert';
import '../models/settings_model.dart';
import '../providers/settings_provider.dart';

class TranslationService {
  final SettingsProvider settingsProvider;

  TranslationService({required this.settingsProvider});
  
  Future<Map<String, String>> translate(String hanzi) async {
    // Выбираем сервис перевода в зависимости от настроек
    if (settingsProvider.translationService == TranslationServiceType.bkrsParser) {
      return await _translateWithBkrs(hanzi);
    } else {
      return await _translateWithHelsinki(hanzi);
    }
  }

  // Static wrapper around instance method for compatibility
  static Future<Map<String, String>> translateStatic(String hanzi) async {
    // This is a simple implementation for backward compatibility that uses BKRS
    try {
      final url = Uri.parse('https://bkrs.info/slovo.php?ch=$hanzi');
      final response = await http.get(url).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        
        final pinyinElement = document.querySelector('.py');
        final pinyin = pinyinElement?.text.split('<img')[0].trim() ?? '';

        final translationElement = document.querySelector('.ru');
        String translation = '';
        
        if (translationElement != null) {
          // Simple extraction of the first translation
          translation = translationElement.text.trim();
          if (translation.contains('1)')) {
            final startIndex = translation.indexOf('1)') + 2;
            final endIndex = translation.indexOf('2)', startIndex);
            translation = endIndex != -1 
                ? translation.substring(startIndex, endIndex).trim() 
                : translation.substring(startIndex).trim();
          }
        }

        return {
          'hanzi': hanzi,
          'pinyin': pinyin,
          'translation': translation,
        };
      } else {
        throw Exception('Error loading data: ${response.statusCode}');
      }
    } catch (e) {
      return {
        'hanzi': hanzi,
        'pinyin': '',
        'translation': 'Translation error',
      };
    }
  }

  Future<Map<String, String>> _translateWithBkrs(String hanzi) async {
    try {
      developer.log('TranslationService: Запрос перевода через БКРС для "$hanzi"', name: 'translation_service');
      
      final url = Uri.parse('https://bkrs.info/slovo.php?ch=$hanzi');
      final response = await http.get(url).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        final result = _extractData(document);
        
        // Добавляем оригинальный символ и пустой английский перевод
        result['hanzi'] = hanzi;
        // Если нет английского перевода, используем русский как запасной вариант
        result['englishTranslation'] = result['translation'] ?? '';
        
        developer.log('TranslationService: Получен перевод для "$hanzi"', name: 'translation_service');
        return result;
      } else {
        developer.log(
          'TranslationService: Ошибка при загрузке данных: ${response.statusCode}', 
          name: 'translation_service'
        );
        throw Exception('Ошибка при загрузке данных: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('TranslationService: Ошибка перевода БКРС: $e', name: 'translation_service');
      // Возвращаем исходный символ при ошибке
      return {
        'hanzi': hanzi,
        'pinyin': '',
        'translation': '',
        'englishTranslation': '',
      };
    }
  }
  
  Future<Map<String, String>> _translateWithHelsinki(String hanzi) async {
    try {
      // Получаем адрес сервера из настроек
      final serverAddress = settingsProvider.serverAddress ?? "http://localhost:8000";
      final url = Uri.parse('$serverAddress/translate');
      
      developer.log('TranslationService: Запрос перевода через Helsinki-NLP для "$hanzi"', 
          name: 'translation_service');
      
      // Формируем языки перевода в зависимости от выбранного в приложении
      String targetLang = 'ru';
      if (settingsProvider.language == AppLanguage.english) {
        targetLang = 'en';
      }
      
      // Отправляем запрос на сервер
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'text': hanzi,
          'source_lang': 'zh',
          'target_lang': targetLang,
          'need_pinyin': true,
          'use_helsinki': true // Включаем использование Helsinki-NLP
        })
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        // Формируем результат
        final Map<String, String> result = {
          'hanzi': hanzi,
          'pinyin': data['pinyin'] ?? '',
        };
        
        // В зависимости от языка берем нужный перевод
        if (targetLang == 'ru') {
          result['translation'] = data['russian'] ?? '';
          final englishTrans = data['english'];
          result['englishTranslation'] = englishTrans != null ? englishTrans : result['translation'];
        } else {
          final englishTrans = data['english'] ?? '';
          result['englishTranslation'] = englishTrans;
          result['translation'] = englishTrans; // Используем английский как перевод
        }
        
        developer.log('TranslationService: Получен перевод через Helsinki-NLP', name: 'translation_service');
        return result;
      } else {
        throw Exception('Ошибка сервера: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      developer.log('TranslationService: Ошибка перевода Helsinki-NLP: $e', name: 'translation_service');
      
      // Пробуем запасной вариант через БКРС при ошибке серверного перевода
      developer.log('TranslationService: Пробуем запасной вариант через БКРС', name: 'translation_service');
      return await _translateWithBkrs(hanzi);
    }
  }

  Map<String, String> _extractData(Document document) {
    try {
      final pinyinElement = document.querySelector('.py');
      final pinyin = pinyinElement?.text.split('<img')[0].trim() ?? '';

      final translationElement = document.querySelector('.ru');
      final translation = _extractFirstTranslation(translationElement);

      return {'pinyin': pinyin, 'translation': translation};
    } catch (e) {
      developer.log('TranslationService: Ошибка извлечения данных: $e', name: 'translation_service');
      return {'pinyin': '', 'translation': ''};
    }
  }

  String _extractFirstTranslation(Element? translationElement) {
    if (translationElement == null) return '';

    try {
      // Удаляем примеры в <div class="m2"> и всё после "2)"
      translationElement.querySelectorAll('.m2').forEach((e) => e.remove());

      final translationText = translationElement.text.trim();
      final index2 = translationText.indexOf('2)');
      final cleanedText = index2 != -1 ? translationText.substring(0, index2).trim() : translationText;

      if (cleanedText.contains('1)')) {
        final startIndex = cleanedText.indexOf('1)') + 2;
        final commaIndex = cleanedText.indexOf(',', startIndex);
        if (commaIndex == -1) {
          return cleanedText.substring(startIndex).trim();
        }
        return cleanedText.substring(startIndex, commaIndex).trim();
      } else {
        final commaIndex = cleanedText.indexOf(',');
        if (commaIndex == -1) {
          return cleanedText.trim();
        }
        return cleanedText.substring(0, commaIndex).trim();
      }
    } catch (e) {
      developer.log('TranslationService: Ошибка извлечения перевода: $e', name: 'translation_service');
      return '';
    }
  }
}
