import 'package:flutter/material.dart';
import '../models/flashcard.dart';
import '../services/translation_service.dart';
import '../services/storage_service.dart';

class FlashcardEditorScreen extends StatefulWidget {
  final List<Flashcard> flashcards;

  FlashcardEditorScreen({required this.flashcards});

  @override
  _FlashcardEditorScreenState createState() => _FlashcardEditorScreenState();
}

class _FlashcardEditorScreenState extends State<FlashcardEditorScreen> {
  final TextEditingController characterController = TextEditingController();
  final TextEditingController pinyinController = TextEditingController();
  final TextEditingController translationController = TextEditingController();

  void addFlashcard() async {
    String translation = await TranslationService.translate(characterController.text, 'en');
    setState(() {
      widget.flashcards.add(Flashcard(
        character: characterController.text,
        pinyin: pinyinController.text,
        translation: translation,
      ));
    });
    await StorageService.saveFlashcards(widget.flashcards);
    characterController.clear();
    pinyinController.clear();
    translationController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit Flashcards')),
      body: Column(
        children: [
          TextField(controller: characterController, decoration: InputDecoration(labelText: 'Character')),
          TextField(controller: pinyinController, decoration: InputDecoration(labelText: 'Pinyin')),
          ElevatedButton(onPressed: addFlashcard, child: Text('Add Flashcard')),
        ],
      ),
    );
  }
}