import 'flashcard.dart';

class FlashcardPack {
  final String name;
  final List<Flashcard> cards;

  FlashcardPack({
    required this.name,
    required this.cards,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'cards': cards.map((card) => card.toJson()).toList(),
    };
  }

  factory FlashcardPack.fromJson(Map<String, dynamic> json) {
    return FlashcardPack(
      name: json['name'] as String,
      cards: (json['cards'] as List)
          .map((cardJson) => Flashcard.fromJson(cardJson as Map<String, dynamic>))
          .toList(),
    );
  }
} 