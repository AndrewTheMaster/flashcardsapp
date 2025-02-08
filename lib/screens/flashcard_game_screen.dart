import 'package:flutter/material.dart';
import '../models/flashcard.dart';

class FlashcardGameScreen extends StatefulWidget {
  final List<Flashcard> flashcards;

  FlashcardGameScreen({required this.flashcards});

  @override
  _FlashcardGameScreenState createState() => _FlashcardGameScreenState();
}

class _FlashcardGameScreenState extends State<FlashcardGameScreen> {
  List<Flashcard> shuffledFlashcards = [];
  Flashcard? selectedCard;

  @override
  void initState() {
    super.initState();
    shuffledFlashcards = List.from(widget.flashcards)..shuffle();
  }

  void selectCard(Flashcard flashcard) {
    setState(() {
      if (selectedCard == null) {
        selectedCard = flashcard;
      } else {
        if (selectedCard!.translation == flashcard.translation || selectedCard!.character == flashcard.character) {
          shuffledFlashcards.remove(selectedCard);
          shuffledFlashcards.remove(flashcard);
        }
        selectedCard = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Flashcard Matching Game')),
      body: GridView.builder(
        padding: EdgeInsets.all(10),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: shuffledFlashcards.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => selectCard(shuffledFlashcards[index]),
            child: Card(
              child: Center(
                child: Text(
                  shuffledFlashcards[index].character,
                  style: TextStyle(fontSize: 24),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}