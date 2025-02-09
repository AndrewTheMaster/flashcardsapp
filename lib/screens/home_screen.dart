import 'package:flutter/material.dart';
import '../widgets/flashcard_widget.dart';
import '../models/flashcard.dart';
import '../screens/flashcard_editor_screen.dart';
import '../screens/flashcard_game_screen.dart';
import '../services/storage_service.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Flashcard> flashcards = [];
  int currentIndex = 0;
  bool isFlipped = false; // Начальное состояние переворота

  @override
  void initState() {
    super.initState();
    _loadFlashcards();
  }

  Future<void> _loadFlashcards() async {
    List<Flashcard> loadedFlashcards = await StorageService.loadFlashcards();
    setState(() {
      flashcards = loadedFlashcards;
    });
  }

  void _saveFlashcards() async {
    await StorageService.saveFlashcards(flashcards);
  }

  void nextCard() {
    if (flashcards.isEmpty) return;
    setState(() {
      currentIndex = (currentIndex + 1) % flashcards.length;
      isFlipped = false; // Сбрасываем состояние переворота при переходе на следующую карточку
    });
  }

  void _editFlashcards() async {
    final updatedFlashcards = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => FlashcardEditorScreen(
            onSave: (hanzi, pinyin, translation) {
              setState(() {
                flashcards.add(Flashcard(hanzi: hanzi, pinyin: pinyin, translation: translation));
              });
              _saveFlashcards();
            },
          )),
    );

    if (updatedFlashcards != null) {
      setState(() {
        flashcards = updatedFlashcards;
      });
      _saveFlashcards();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chinese Flashcards')),
      body: Center(
        child: flashcards.isNotEmpty
            ? FlashcardWidget(
          flashcard: flashcards[currentIndex],
          isFlipped: isFlipped, // Передаем состояние переворота
        )
            : Text('Добавьте карточки в редакторе'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: nextCard,
        child: Icon(Icons.arrow_forward),
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            ListTile(
              title: Text('Редактировать карточки'),
              onTap: _editFlashcards,
            ),
            ListTile(
              title: Text('Играть'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FlashcardGameScreen(flashcards: flashcards),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
