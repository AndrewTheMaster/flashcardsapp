class Flashcard {
  String hanzi;
  String pinyin;
  String translation;
  DateTime lastReviewed;
  int repetitionLevel;
  bool needsReview;
  DateTime? nextReviewDate;

  Flashcard({
    required this.hanzi,
    required this.pinyin,
    required this.translation,
    DateTime? lastReviewed,
    this.repetitionLevel = 0,
    this.needsReview = true,
    this.nextReviewDate,
  }) : lastReviewed = lastReviewed ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'hanzi': hanzi,
      'pinyin': pinyin,
      'translation': translation,
      'lastReviewed': lastReviewed.toIso8601String(),
      'repetitionLevel': repetitionLevel,
      'needsReview': needsReview,
      'nextReviewDate': nextReviewDate?.toIso8601String(),
    };
  }

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    return Flashcard(
      hanzi: json['hanzi'] ?? '',
      pinyin: json['pinyin'] ?? '',
      translation: json['translation'] ?? '',
      lastReviewed: json['lastReviewed'] != null
          ? DateTime.parse(json['lastReviewed'])
          : null,
      repetitionLevel: json['repetitionLevel'] ?? 0,
      needsReview: json['needsReview'] ?? true,
      nextReviewDate: json['nextReviewDate'] != null
          ? DateTime.parse(json['nextReviewDate'])
          : null,
    );
  }

  // Simplified spaced repetition algorithm
  void updateNextReviewDate({required bool wasCorrect}) {
    lastReviewed = DateTime.now();
    
    if (wasCorrect) {
      repetitionLevel++;
    } else {
      repetitionLevel = repetitionLevel > 0 ? repetitionLevel - 1 : 0;
    }
    
    // Calculate next review date based on repetition level
    if (repetitionLevel == 0) {
      // If level is 0, needs review immediately
      needsReview = true;
      nextReviewDate = DateTime.now();
    } else {
      // Exponential spacing: 1 day, 3 days, 7 days, 14 days, 30 days, 60 days, etc.
      int daysToAdd = repetitionLevel == 1 ? 1 : (1 << (repetitionLevel - 1));
      if (daysToAdd > 60) daysToAdd = 60; // Cap at 60 days
      
      nextReviewDate = DateTime.now().add(Duration(days: daysToAdd));
      needsReview = false;
    }
  }
} 