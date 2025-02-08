import 'flashcard.dart';

class FlashcardPack {
  String name; // Название пака
  List<Flashcard> flashcards; // Список карточек

  FlashcardPack({
    required this.name,
    required this.flashcards,
  });

  // Метод для преобразования в JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'flashcards': flashcards.map((f) => f.toJson()).toList(),
    };
  }

  // Метод для создания объекта FlashcardPack из JSON
  factory FlashcardPack.fromJson(Map<String, dynamic> json) {
    return FlashcardPack(
      name: json['name'],
      flashcards: (json['flashcards'] as List<dynamic>)
          .map((f) => Flashcard.fromJson(f))
          .toList(),
    );
  }
}
