import 'package:translator/translator.dart';

class TranslationService {
  static final GoogleTranslator translator = GoogleTranslator();

  static Future<String> translate(String text, String targetLang) async {
    try {
      final translation = await translator.translate(text, to: targetLang);
      return translation.text;
    } catch (e) {
      print("Google Translate Error: $e");
      throw Exception('Failed to load translation');
    }
  }
}
