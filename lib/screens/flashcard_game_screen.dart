import 'package:flutter/material.dart';
import '../models/flashcard.dart';
import '../localization/app_localizations.dart';

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
    // Limit to 4 flashcards (8 cards total) to fit on one screen
    final maxFlashcards = 4;
    List<Flashcard> gameFlashcards = widget.flashcards;

    // Sort flashcards based on spaced repetition system - prioritize cards that need review
    gameFlashcards.sort((a, b) {
      // If a card needs review and the other doesn't, prioritize the one that needs review
      if (a.needsReview && !b.needsReview) return -1;
      if (!a.needsReview && b.needsReview) return 1;
      
      // If both need review, prioritize the one with lower repetition level
      if (a.needsReview && b.needsReview) {
        return a.repetitionLevel.compareTo(b.repetitionLevel);
      }
      
      // If neither needs review, just keep the order
      return 0;
    });
    
    // Take only up to maxFlashcards cards
    if (gameFlashcards.length > maxFlashcards) {
      gameFlashcards = gameFlashcards.sublist(0, maxFlashcards);
    }
    
    for (var flashcard in gameFlashcards) {
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
          // Match found - update spaced repetition for this card
          _firstSelected!.flashcard.updateNextReviewDate(wasCorrect: true);
          
          // Remove cards
          _firstSelected!.isMatched = true;
          _secondSelected!.isMatched = true;
          _firstSelected = null;
          _secondSelected = null;
        } else {
          // Incorrect pair - update spaced repetition as incorrect
          if (_firstSelected!.flashcard == _secondSelected!.flashcard) {
            _firstSelected!.flashcard.updateNextReviewDate(wasCorrect: false);
          }
          
          // Flip back after 1 second
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    bool isGameWon = _cards.every((card) => card.isMatched);

    if (isGameWon && _cards.isNotEmpty) {
      Future.delayed(Duration(milliseconds: 500), () {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('victory'.tr(context)),
            content: Text('found_all_pairs'.tr(context)),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _setupGame();
                },
                child: Text('play_again'.tr(context)),
              ),
            ],
          ),
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('memory_game'.tr(context)),
      ),
      body: widget.flashcards.isEmpty
          ? Center(
              child: Text('no_cards_available'.tr(context)),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    'find_matching_pairs'.tr(context),
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      padding: EdgeInsets.all(10),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.7,
                      ),
                      itemCount: _cards.length,
                      itemBuilder: (context, index) {
                        _GameCard card = _cards[index];
                        bool isFlipped = card == _firstSelected || card == _secondSelected || card.isMatched;
                        
                        // Define colors based on card state and theme
                        Color cardColor;
                        if (card.isMatched) {
                          // For matched cards, use a color that blends with background
                          cardColor = isDarkMode 
                              ? Colors.green.withOpacity(0.2)  // Dark theme (existing)
                              : Colors.green.shade50;          // Light theme (more subtle)
                        } else if (isFlipped) {
                          // Flipped card
                          cardColor = isDarkMode 
                              ? Colors.blue.shade800 
                              : Colors.white;
                        } else {
                          // Default card back
                          cardColor = isDarkMode 
                              ? Colors.grey.shade700 
                              : Colors.blue.shade200;
                        }
                        
                        Color borderColor = card.isMatched 
                            ? Colors.green
                            : (isFlipped ? Colors.blue : Colors.grey);
                        
                        Color textColor = card.isMatched
                            ? Colors.green.shade800
                            : (isDarkMode ? Colors.white : Colors.black87);
                
                        return GestureDetector(
                          onTap: () => _selectCard(index),
                          child: Card(
                            color: cardColor,
                            elevation: isFlipped ? 4 : 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: borderColor, width: isFlipped ? 2 : 1),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: isFlipped
                                  ? Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          card.isTranslation ? card.flashcard.translation : card.flashcard.hanzi,
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        if (!card.isTranslation)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 8.0),
                                            child: Text(
                                              card.flashcard.pinyin,
                                              style: TextStyle(
                                                fontSize: 16, 
                                                color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                      ],
                                    )
                                  : Icon(
                                      Icons.help_outline, 
                                      size: 32, 
                                      color: isDarkMode ? Colors.grey[300] : Colors.white,
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
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
