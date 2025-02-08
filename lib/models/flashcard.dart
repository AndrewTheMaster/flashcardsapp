class Flashcard {
  String hanzi;       // Иероглифы
  String pinyin;      // Пиньинь
  String translation; // Перевод

  Flashcard({
    required this.hanzi,
    required this.pinyin,
    required this.translation,
  });

  // Метод для преобразования в JSON
  Map<String, dynamic> toJson() {
    return {
      'hanzi': hanzi,
      'pinyin': pinyin,
      'translation': translation,
    };
  }

  // Метод для создания объекта Flashcard из JSON
  factory Flashcard.fromJson(Map<String, dynamic> json) {
    return Flashcard(
      hanzi: json['hanzi'],
      pinyin: json['pinyin'],
      translation: json['translation'],
    );
  }
}
