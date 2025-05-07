import 'flashcard.dart';

class FlashcardPack {
  String name;
  List<Flashcard> cards;
  DateTime dateCreated;

  FlashcardPack({
    required this.name,
    required this.cards,
    DateTime? dateCreated,
  }) : dateCreated = dateCreated ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'cards': cards.map((card) => card.toJson()).toList(),
      'dateCreated': dateCreated.toIso8601String(),
    };
  }

  factory FlashcardPack.fromJson(Map<String, dynamic> json) {
    List<dynamic> cardsList = json['cards'] ?? [];
    List<Flashcard> cards = cardsList
        .map((cardJson) => Flashcard.fromJson(cardJson))
        .toList();

    return FlashcardPack(
      name: json['name'] ?? 'Unnamed Pack',
      cards: cards,
      dateCreated: json['dateCreated'] != null
          ? DateTime.parse(json['dateCreated'])
          : null,
    );
  }
} 