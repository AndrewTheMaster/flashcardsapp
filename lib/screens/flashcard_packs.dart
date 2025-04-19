import '../services/translation_service.dart';
import '../models/flashcard_pack.dart';
import '../models/flashcard.dart';
Future<void> _bulkAddFlashcards(String text) async {
  List<String> hanziList = text.split('\n').where((s) => s.trim().isNotEmpty).toList();

  for (String hanzi in hanziList) {
    final result = await TranslationService.translate(hanzi);
    _flashcardPack.cards.add(
      Flashcard(hanzi: hanzi, pinyin: result['pinyin']!, translation: result['translation']!),
    );
  }
  setState(() {});
}
