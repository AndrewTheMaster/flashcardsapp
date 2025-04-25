class Flashcard {
  final String hanzi;
  final String pinyin;
  final String translation;
  
  // Spaced repetition system fields
  DateTime? lastReviewed;
  int repetitionLevel; // 0-5, where 0 = new card, 5 = well known
  DateTime? nextReviewDate;

  Flashcard({
    required this.hanzi,
    required this.pinyin,
    required this.translation,
    this.lastReviewed,
    this.repetitionLevel = 0,
    this.nextReviewDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'hanzi': hanzi,
      'pinyin': pinyin,
      'translation': translation,
      'lastReviewed': lastReviewed?.toIso8601String(),
      'repetitionLevel': repetitionLevel,
      'nextReviewDate': nextReviewDate?.toIso8601String(),
    };
  }

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    return Flashcard(
      hanzi: json['hanzi'] as String,
      pinyin: json['pinyin'] as String,
      translation: json['translation'] as String,
      lastReviewed: json['lastReviewed'] != null ? DateTime.parse(json['lastReviewed'] as String) : null,
      repetitionLevel: json['repetitionLevel'] as int? ?? 0,
      nextReviewDate: json['nextReviewDate'] != null ? DateTime.parse(json['nextReviewDate'] as String) : null,
    );
  }
  
  // Calculate next review date based on repetition level
  void updateNextReviewDate({bool wasCorrect = true}) {
    lastReviewed = DateTime.now();
    
    // If correct answer, increase repetition level (max 5)
    if (wasCorrect && repetitionLevel < 5) {
      repetitionLevel++;
    } 
    // If incorrect, decrease repetition level (min 0)
    else if (!wasCorrect && repetitionLevel > 0) {
      repetitionLevel--;
    }
    
    // Calculate days until next review based on repetition level
    int daysUntilNextReview;
    switch (repetitionLevel) {
      case 0: daysUntilNextReview = 1; break;  // New card - review tomorrow
      case 1: daysUntilNextReview = 2; break;  // Review in 2 days
      case 2: daysUntilNextReview = 4; break;  // Review in 4 days
      case 3: daysUntilNextReview = 7; break;  // Review in 1 week
      case 4: daysUntilNextReview = 14; break; // Review in 2 weeks
      case 5: daysUntilNextReview = 30; break; // Review in 1 month
      default: daysUntilNextReview = 1;
    }
    
    nextReviewDate = DateTime.now().add(Duration(days: daysUntilNextReview));
  }
  
  // Check if card needs to be reviewed today
  bool get needsReview {
    if (nextReviewDate == null) return true; // New card
    final now = DateTime.now();
    return now.isAfter(nextReviewDate!);
  }
} 