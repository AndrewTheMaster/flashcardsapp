import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';

class TranslationService {
  static Future<Map<String, String>> translate(String hanzi) async {
    final url = Uri.parse('https://bkrs.info/slovo.php?ch=$hanzi');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final document = parser.parse(response.body);
      return _extractData(document);
    } else {
      throw Exception('Ошибка при загрузке данных');
    }
  }

  static Map<String, String> _extractData(Document document) {
    // Извлекаем пиньинь из элемента с классом "py"
    final pinyinElement = document.querySelector('.py');
    final pinyin = pinyinElement?.text.split('<img')[0].trim() ?? '';

    // Извлекаем перевод из элемента с классом "ru"
    final translationElement = document.querySelector('.ru');
    final translation = _extractFirstTranslation(translationElement?.text ?? '');

    return {'pinyin': pinyin, 'translation': translation};
  }

  static String _extractFirstTranslation(String translationText) {
    // Проверяем, есть ли в тексте "1)"
    if (translationText.contains('1)')) {
      // Убираем "1)" и берём текст до первой запятой
      final startIndex = translationText.indexOf('1)') + 2; // +2, чтобы пропустить "1)"
      final commaIndex = translationText.indexOf(',', startIndex);
      if (commaIndex == -1) {
        // Если запятой нет, возвращаем весь текст после "1)"
        return translationText.substring(startIndex).trim();
      }
      return translationText.substring(startIndex, commaIndex).trim();
    } else {
      // Если "1)" нет, возвращаем весь текст до первой запятой
      final commaIndex = translationText.indexOf(',');
      if (commaIndex == -1) {
        // Если запятой нет, возвращаем весь текст
        return translationText.trim();
      }
      return translationText.substring(0, commaIndex).trim();
    }
  }
}