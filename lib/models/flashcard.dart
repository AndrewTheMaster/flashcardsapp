class Flashcard {
  final String hanzi;
  final String pinyin;
  final String translation;

  Flashcard({
    required this.hanzi,
    required this.pinyin,
    required this.translation,
  });

  Map<String, dynamic> toJson() {
    return {
      'hanzi': hanzi,
      'pinyin': pinyin,
      'translation': translation,
    };
  }

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    return Flashcard(
      hanzi: json['hanzi'] as String,
      pinyin: json['pinyin'] as String,
      translation: json['translation'] as String,
    );
  }
} 