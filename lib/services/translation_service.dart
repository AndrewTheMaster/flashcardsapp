import 'package:translator/translator.dart';

class TranslationService {
  static final GoogleTranslator translator = GoogleTranslator();

  static Future<Map<String, String>> translate(String text) async {
    try {
      final translation = await translator.translate(text, from: 'zh', to: 'en');
      final pinyin = await translator.translate(text, from: 'zh', to: 'zh-Latn');

      return {
        'pinyin': pinyin.text,
        'translation': translation.text,
      };
    } catch (e) {
      print("Translation Error: $e");
      throw Exception('Failed to load translation');
    }
  }
}
