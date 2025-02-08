class Flashcard {
  String character;
  String pinyin;
  String translation;

  Flashcard({required this.character, required this.pinyin, required this.translation});

  Map<String, dynamic> toJson() => {
    'character': character,
    'pinyin': pinyin,
    'translation': translation,
  };

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    return Flashcard(
      character: json['character'],
      pinyin: json['pinyin'],
      translation: json['translation'],
    );
  }
}
