import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/flashcard.dart';

class CardsProvider with ChangeNotifier {
  Flashcard? currentFlashcard;
  List<Flashcard> dueCards = [];
  bool isLoading = false;
  
  // Get card due for review
  Future<void> loadDueCards() async {
    isLoading = true;
    notifyListeners();
    
    // In a real app, you would load this from storage
    dueCards = [];
    
    isLoading = false;
    notifyListeners();
  }
  
  // Mark a card as reviewed
  void reviewCard(Flashcard card, bool wasCorrect) {
    card.updateNextReviewDate(wasCorrect: wasCorrect);
    notifyListeners();
  }
  
  // Select a specific flashcard
  void selectFlashcard(Flashcard card) {
    currentFlashcard = card;
    notifyListeners();
  }
} 