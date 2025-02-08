import 'package:flutter/material.dart';
import '../models/flashcard.dart';

class FlashcardGameScreen extends StatefulWidget {
  final List<Flashcard> flashcards;

  FlashcardGameScreen({required this.flashcards});

  @override
  _FlashcardGameScreenState createState() => _FlashcardGameScreenState();
}

class _FlashcardGameScreenState extends State<FlashcardGameScreen> {
  late List<_GameCard> gameCards;
  _GameCard? firstSelected;
  _GameCard? secondSelected;
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    _shuffleCards();
  }

  void _shuffleCards() {
    List<_GameCard> cards = [];
    for (var card in widget.flashcards) {
      cards.add(_GameCard(content: card.hanzi, id: card.hanzi));
      cards.add(_GameCard(content: card.translation, id: card.hanzi));
    }
    cards.shuffle();
    setState(() {
      gameCards = cards;
    });
  }

  void _selectCard(_GameCard card) {
    if (isProcessing || card.isMatched || card == firstSelected) return;

    setState(() {
      card.isFlipped = true;
      if (firstSelected == null) {
        firstSelected = card;
      } else {
        secondSelected = card;
        isProcessing = true;
        Future.delayed(Duration(seconds: 1), _checkMatch);
      }
    });
  }

  void _checkMatch() {
    if (firstSelected != null && secondSelected != null) {
      if (firstSelected!.id == secondSelected!.id) {
        setState(() {
          firstSelected!.isMatched = true;
          secondSelected!.isMatched = true;
        });
      } else {
        setState(() {
          firstSelected!.isFlipped = false;
          secondSelected!.isFlipped = false;
        });
      }
    }
    firstSelected = null;
    secondSelected = null;
    isProcessing = false;

    if (gameCards.every((card) => card.isMatched)) {
      _showVictoryDialog();
    }
  }

  void _showVictoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Поздравляем!"),
        content: Text("Вы нашли все пары."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _shuffleCards();
            },
            child: Text("Играть заново"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Игра с карточками')),
      body: GridView.builder(
        padding: EdgeInsets.all(10),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: gameCards.length,
        itemBuilder: (context, index) {
          _GameCard card = gameCards[index];
          return GestureDetector(
            onTap: () => _selectCard(card),
            child: Card(
              color: card.isMatched
                  ? Colors.transparent
                  : card.isFlipped
                  ? Colors.white
                  : Colors.grey,
              child: Center(
                child: card.isFlipped ? Text(card.content, style: TextStyle(fontSize: 20)) : null,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GameCard {
  final String content;
  final String id;
  bool isFlipped = false;
  bool isMatched = false;

  _GameCard({required this.content, required this.id});
}
