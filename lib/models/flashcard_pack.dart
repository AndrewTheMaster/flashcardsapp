import 'flashcard.dart';

class FlashcardPack {
  String name;
  List<Flashcard> cards;

  FlashcardPack({required this.name, required this.cards});

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'cards': cards.map((card) => card.toJson()).toList(),
    };
  }

  factory FlashcardPack.fromJson(Map<String, dynamic> json) {
    return FlashcardPack(
      name: json['name'],
      cards: (json['cards'] as List).map((card) => Flashcard.fromJson(card)).toList(),
    );
  }
}
