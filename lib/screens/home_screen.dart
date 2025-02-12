import 'package:flutter/material.dart';
import '../widgets/flashcard_widget.dart';
import '../models/flashcard.dart';
import '../screens/flashcard_editor_screen.dart';
import '../screens/flashcard_game_screen.dart';
import '../services/storage_service.dart';
import '../screens/sentence_completion_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Flashcard> flashcards = [];
  int currentIndex = 0;
  bool _isFlipped = false;

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

  void _nextCard() {
    if (flashcards.isEmpty) return;
    setState(() {
      currentIndex = (currentIndex + 1) % flashcards.length;
      _isFlipped = false; // Сбрасываем состояние переворота
    });
  }

  void _onCardFlipped() {
    // После переворота карточки ждем 2 секунды, возвращаем карточку в исходное состояние и переходим к следующей
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isFlipped = false; // Возвращаем карточку в исходное состояние
        });
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _nextCard(); // Переходим к следующей карточке
          }
        });
      }
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
        ),
      ),
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
      appBar: AppBar(title: const Text('Chinese Flashcards')),
      body: Center(
        child: flashcards.isNotEmpty
            ? FlashcardWidget(
          flashcard: flashcards[currentIndex],
          isFlipped: _isFlipped,
          onFlip: _onCardFlipped, // Передаем колбэк для обработки переворота
        )
            : const Text('Добавьте карточки в редакторе'),
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            ListTile(
              title: const Text('Редактировать карточки'),
              onTap: _editFlashcards,
            ),
            ListTile(
              title: const Text('Играть'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FlashcardGameScreen(flashcards: flashcards),
                ),
              ),
            ),
            ListTile(
              title: const Text('Заполни пропуски'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SentenceCompletionScreen(flashcards: flashcards),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}