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
    final pinyinElement = document.querySelector('.py');
    final pinyin = pinyinElement?.text.split('<img')[0].trim() ?? '';

    final translationElement = document.querySelector('.ru');
    final translation = _extractFirstTranslation(translationElement);

    return {'pinyin': pinyin, 'translation': translation};
  }

  static String _extractFirstTranslation(Element? translationElement) {
    if (translationElement == null) return '';

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
  }
}
