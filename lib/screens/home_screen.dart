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

  int currentIndex = 0;
  bool showTranslation = false;

  void nextCard() {
    setState(() {
      currentIndex = (currentIndex + 1) % flashcards.length;
      showTranslation = false;
    });
  }

  void flipCard() {
    setState(() {
      showTranslation = !showTranslation;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chinese Flashcards')),
      body: Center(
        child: flashcards.isNotEmpty
            ? FlashcardWidget(
          flashcard: flashcards[currentIndex],
          onFlip: flipCard,
          showTranslation: showTranslation,
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
              title: Text('Edit Flashcards'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => FlashcardEditorScreen(flashcards: flashcards)),
              ),
            ),
            ListTile(
              title: Text('Play Game'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => FlashcardGameScreen(flashcards: flashcards)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
