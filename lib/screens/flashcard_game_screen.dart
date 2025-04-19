import 'package:flutter/material.dart';
import '../models/flashcard.dart';

class FlashcardGameScreen extends StatefulWidget {
  final List<Flashcard> flashcards;

  FlashcardGameScreen({required this.flashcards});

  @override
  _FlashcardGameScreenState createState() => _FlashcardGameScreenState();
}

class _FlashcardGameScreenState extends State<FlashcardGameScreen> {
  List<_GameCard> _cards = [];
  _GameCard? _firstSelected;
  _GameCard? _secondSelected;

  @override
  void initState() {
    super.initState();
    _setupGame();
  }

  void _setupGame() {
    List<_GameCard> tempCards = [];
    for (var flashcard in widget.flashcards) {
      tempCards.add(_GameCard(flashcard, isTranslation: false));
      tempCards.add(_GameCard(flashcard, isTranslation: true));
    }
    tempCards.shuffle();
    setState(() {
      _cards = tempCards;
    });
  }

  void _selectCard(int index) {
    if (_cards[index].isMatched || _firstSelected == _cards[index]) return;

    setState(() {
      if (_firstSelected == null) {
        _firstSelected = _cards[index];
      } else {
        _secondSelected = _cards[index];

        if (_firstSelected!.flashcard == _secondSelected!.flashcard &&
            _firstSelected!.isTranslation != _secondSelected!.isTranslation) {
          // Совпадение найдено — убираем карточки
          _firstSelected!.isMatched = true;
          _secondSelected!.isMatched = true;
          _firstSelected = null;
          _secondSelected = null;
        } else {
          // Неправильная пара — переворачиваем обратно через 1 секунду
          Future.delayed(Duration(seconds: 1), () {
            setState(() {
              _firstSelected = null;
              _secondSelected = null;
            });
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isGameWon = _cards.every((card) => card.isMatched);

    if (isGameWon) {
      Future.delayed(Duration(milliseconds: 500), () {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text("Победа!"),
            content: Text("Вы нашли все пары!"),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _setupGame();
                },
                child: Text("Играть снова"),
              ),
            ],
          ),
        );
      });
    }

    return Scaffold(
      appBar: AppBar(title: Text('Игра на совпадение')),
      body: GridView.builder(
        padding: EdgeInsets.all(10),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: _cards.length,
        itemBuilder: (context, index) {
          _GameCard card = _cards[index];
          bool isFlipped = card == _firstSelected || card == _secondSelected || card.isMatched;

          return GestureDetector(
            onTap: () => _selectCard(index),
            child: Card(
              color: isFlipped ? Colors.white : Colors.grey,
              child: Center(
                child: isFlipped
                    ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      card.isTranslation ? card.flashcard.translation : card.flashcard.hanzi,
                      style: TextStyle(fontSize: 20),
                    ),
                    if (!card.isTranslation)
                      Text(
                        card.flashcard.pinyin,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                  ],
                )
                    : Icon(Icons.help_outline, size: 32, color: Colors.white),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GameCard {
  final Flashcard flashcard;
  final bool isTranslation;
  bool isMatched = false;

  _GameCard(this.flashcard, {required this.isTranslation});
}
