import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/flashcard.dart';
import '../models/flashcard_pack.dart';
import '../services/storage_service.dart';

class CardsProvider with ChangeNotifier {
  Flashcard? currentFlashcard;
  List<Flashcard> dueCards = [];
  List<FlashcardPack> allPacks = [];
  bool isLoading = false;
  
  // Load all flashcard packs
  Future<void> loadAllPacks() async {
    isLoading = true;
    notifyListeners();
    
    try {
      allPacks = await StorageService.loadFlashcardPacks();
      await loadDueCards();
    } catch (e) {
      // Handle errors
      debugPrint('Error loading packs: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
  
  // Get cards due for review
  Future<void> loadDueCards() async {
    isLoading = true;
    notifyListeners();
    
    dueCards = [];
    
    // Go through all packs and collect due cards
    for (var pack in allPacks) {
      for (var card in pack.cards) {
        if (card.needsReview) {
          dueCards.add(card);
        }
      }
    }
    
    // Sort due cards by SRS level
    dueCards.sort((a, b) => a.repetitionLevel.compareTo(b.repetitionLevel));
    
    isLoading = false;
    notifyListeners();
  }
  
  // Get all cards from all packs
  List<Flashcard> getAllCards() {
    List<Flashcard> allCards = [];
    for (var pack in allPacks) {
      allCards.addAll(pack.cards);
    }
    return allCards;
  }
  
  // Get cards sorted by SRS level
  List<Flashcard> getCardsSortedBySrs() {
    List<Flashcard> allCards = getAllCards();
    allCards.sort((a, b) => a.repetitionLevel.compareTo(b.repetitionLevel));
    return allCards;
  }
  
  // Mark a card as reviewed
  void reviewCard(Flashcard card, bool wasCorrect) {
    card.updateNextReviewDate(wasCorrect: wasCorrect);
    // Save changes to storage
    _saveAllPacks();
    notifyListeners();
  }
  
  // Select a specific flashcard
  void selectFlashcard(Flashcard card) {
    currentFlashcard = card;
    notifyListeners();
  }
  
  // Save all packs to storage
  Future<void> _saveAllPacks() async {
    try {
      await StorageService.saveFlashcardPacks(allPacks);
    } catch (e) {
      debugPrint('Error saving packs: $e');
    }
  }
} 