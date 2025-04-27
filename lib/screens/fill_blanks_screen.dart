import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/flashcard_pack.dart';
import '../models/flashcard.dart';
import '../localization/app_localizations.dart';
import '../services/model_service_provider.dart';
import 'dart:developer' as developer;

class FillBlanksScreen extends StatefulWidget {
  final FlashcardPack? currentPack;
  final bool isDarkMode;

  const FillBlanksScreen({
    Key? key,
    this.currentPack,
    this.isDarkMode = false,
  }) : super(key: key);

  @override
  _FillBlanksScreenState createState() => _FillBlanksScreenState();
}

class _FillBlanksScreenState extends State<FillBlanksScreen> {
  String? currentSentence;
  String? hiddenWord;
  List<String> options = [];
  bool isCorrect = false;
  bool isChecked = false;
  String selectedOption = '';
  Flashcard? currentFlashcard;
  
  // Track if model is initialized
  bool _isModelInitialized = false;
  bool _isLoading = true;
  
  // List of generated exercises
  List<Map<String, String>> _exercises = [];
  int _currentExerciseIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeModel();
  }
  
  Future<void> _initializeModel() async {
    setState(() {
      _isLoading = true;
    });
    
    // Initialize the model service
    _isModelInitialized = await ModelServiceProvider.initialize();
    
    if (_isModelInitialized) {
      developer.log('FillBlanksScreen: Model initialized successfully', name: 'fill_blanks_screen');
      developer.log('FillBlanksScreen: Using ${ModelServiceProvider.getCurrentImplementation()} implementation', name: 'fill_blanks_screen');
      await _generateExerciseBatch();
    } else {
      developer.log('FillBlanksScreen: Failed to initialize model', name: 'fill_blanks_screen');
      // Fallback to old method if model initialization fails
      _generateExercise();
    }
    
    setState(() {
      _isLoading = false;
    });
  }
  
  Future<void> _generateExerciseBatch() async {
    if (widget.currentPack == null || widget.currentPack!.cards.isEmpty) {
      developer.log('FillBlanksScreen: Current pack is empty or null', name: 'fill_blanks_screen');
      return;
    }
    
    try {
      // Generate a batch of exercises (5 at a time)
      _exercises = await ModelServiceProvider.generateExerciseBatch(
        widget.currentPack!.cards, 
        5
      );
      
      if (_exercises.isNotEmpty) {
        _currentExerciseIndex = 0;
        _loadCurrentExercise();
      } else {
        // Fallback to old method if no exercises generated
        _generateExercise();
      }
    } catch (e) {
      developer.log('FillBlanksScreen: Error generating exercise batch: $e', name: 'fill_blanks_screen');
      // Fallback to old method if error
      _generateExercise();
    }
  }
  
  void _loadCurrentExercise() {
    if (_exercises.isEmpty || _currentExerciseIndex >= _exercises.length) {
      _generateExercise(); // Fallback to old method
      return;
    }
    
    final exercise = _exercises[_currentExerciseIndex];
    
    // Find the card that matches this exercise
    final targetHanzi = exercise['answer'] ?? '';
    currentFlashcard = widget.currentPack!.cards.firstWhere(
      (card) => card.hanzi == targetHanzi,
      orElse: () => widget.currentPack!.cards.first,
    );
    
    // Set up the current exercise
    currentSentence = exercise['sentence'];
    hiddenWord = exercise['answer'];
    
    // Generate options (correct answer + random distractors)
    _generateOptions(currentFlashcard!);
    
    setState(() {
      isChecked = false;
      selectedOption = '';
    });
  }

  void _generateExercise() {
    if (widget.currentPack == null || widget.currentPack!.cards.isEmpty) {
      developer.log('FillBlanksScreen: Current pack is empty or null', name: 'fill_blanks_screen');
      return;
    }

    final random = math.Random();
    List<Flashcard> cards = widget.currentPack!.cards;
    
    // Sort cards by spaced repetition priority
    // First prioritize cards that need review, then by repetition level (lowest first)
    cards.sort((a, b) {
      if (a.needsReview && !b.needsReview) return -1;
      if (!a.needsReview && b.needsReview) return 1;
      if (a.needsReview && b.needsReview) {
        return a.repetitionLevel.compareTo(b.repetitionLevel);
      }
      return 0;
    });
    
    // Pick first card that needs review, or random if all are reviewed
    Flashcard randomCard;
    List<Flashcard> cardsNeedingReview = cards.where((card) => card.needsReview).toList();
    
    if (cardsNeedingReview.isNotEmpty) {
      // Pick a card that needs review (with slight randomization if multiple)
      int randomIndex = cardsNeedingReview.length > 3 
          ? random.nextInt(3) // Pick from top 3 that need review
          : 0; // Just pick the first card if 3 or fewer
      randomCard = cardsNeedingReview[randomIndex];
    } else {
      // No cards need review, pick random
      int randomIndex = random.nextInt(cards.length);
      randomCard = cards[randomIndex];
    }
    
    currentFlashcard = randomCard;
    final hanzi = randomCard.hanzi;
    hiddenWord = hanzi;
    
    // If model is initialized, use it to generate a sentence
    if (_isModelInitialized) {
      ModelServiceProvider.generateSentenceWithBlank(randomCard).then((generatedSentence) {
        setState(() {
          currentSentence = generatedSentence;
        });
      }).catchError((e) {
        // Fallback to simple template if error
        setState(() {
          currentSentence = "这是 ____ 。";
        });
      });
    } else {
      // Fallback to simple template if model not initialized
      currentSentence = "这是 ____ 。";
    }
    
    // Generate options
    _generateOptions(randomCard);
    
    setState(() {
      isChecked = false;
      selectedOption = '';
    });
    
    developer.log('FillBlanksScreen: Generated exercise: $currentSentence, correct answer: $hiddenWord', 
        name: 'fill_blanks_screen');
  }
  
  void _generateOptions(Flashcard card) {
    final random = math.Random();
    final List<Flashcard> cards = widget.currentPack!.cards;
    
    // Start with the correct answer
    options = [card.hanzi];
    
    // Add more options from other cards
    while (options.length < 4 && options.length < cards.length) {
      final otherCard = cards[random.nextInt(cards.length)];
      if (otherCard.hanzi != card.hanzi && !options.contains(otherCard.hanzi)) {
        options.add(otherCard.hanzi);
      }
    }
    
    // Shuffle options
    options.shuffle();
  }

  void _checkAnswer() {
    final bool isAnswerCorrect = selectedOption == hiddenWord;
    
    // Update spaced repetition data
    if (currentFlashcard != null) {
      currentFlashcard!.updateNextReviewDate(wasCorrect: isAnswerCorrect);
    }
    
    setState(() {
      isChecked = true;
      isCorrect = isAnswerCorrect;
    });
  }
  
  void _nextExercise() {
    if (_isModelInitialized && _exercises.isNotEmpty) {
      // Move to next exercise in batch
      _currentExerciseIndex++;
      
      // If we've gone through all exercises, generate a new batch
      if (_currentExerciseIndex >= _exercises.length) {
        _generateExerciseBatch();
      } else {
        _loadCurrentExercise();
      }
    } else {
      // Fall back to old method
      _generateExercise();
    }
  }

  @override
  Widget build(BuildContext context) {
    final debugTextColor = Colors.black;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('fill_blanks'.tr(context)),
      ),
      body: _isLoading
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Initializing...'),
              ],
            ),
          )
        : widget.currentPack == null || widget.currentPack!.cards.isEmpty
          ? Center(
              child: Text('no_cards_available'.tr(context)),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Debug information
                  Container(
                    padding: EdgeInsets.all(8),
                    margin: EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.yellow[100],
                      border: Border.all(color: Colors.amber),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "${('correct_answer').tr(context)}: $hiddenWord",
                      style: TextStyle(color: debugTextColor),
                    ),
                  ),
                  
                  // Show spaced repetition info for debugging
                  if (currentFlashcard != null)
                    Container(
                      padding: EdgeInsets.all(8),
                      margin: EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        border: Border.all(color: Colors.blue),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "SRS Level: ${currentFlashcard!.repetitionLevel}, Next review: ${currentFlashcard!.nextReviewDate?.toString().substring(0, 10) ?? 'New'}",
                        style: TextStyle(color: debugTextColor),
                      ),
                    ),
                  
                  // Sentence with blank
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      currentSentence ?? "",
                      style: TextStyle(fontSize: 24),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  SizedBox(height: 32),
                  
                  // Options
                  ...options.map((option) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: OptionButton(
                      text: option,
                      isSelected: selectedOption == option,
                      isCorrect: isChecked && option == hiddenWord,
                      isWrong: isChecked && selectedOption == option && option != hiddenWord,
                      onTap: () {
                        if (!isChecked) {
                          setState(() {
                            selectedOption = option;
                          });
                        }
                      },
                    ),
                  )),
                  
                  Spacer(),
                  
                  // Control buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (!isChecked)
                        ElevatedButton(
                          onPressed: selectedOption.isEmpty ? null : _checkAnswer,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            disabledBackgroundColor: Theme.of(context).disabledColor,
                            disabledForegroundColor: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                          ),
                          child: Text('check'.tr(context)),
                        )
                      else
                        ElevatedButton(
                          onPressed: _nextExercise,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: Text('next'.tr(context)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

class OptionButton extends StatelessWidget {
  final String text;
  final bool isSelected;
  final bool isCorrect;
  final bool isWrong;
  final VoidCallback onTap;

  const OptionButton({
    Key? key,
    required this.text,
    this.isSelected = false,
    this.isCorrect = false,
    this.isWrong = false,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Define colors based on state
    Color backgroundColor;
    Color textColor;
    Color borderColor;
    
    if (isCorrect) {
      backgroundColor = Colors.green.shade100;
      textColor = Colors.green.shade800;
      borderColor = Colors.green.shade500;
    } else if (isWrong) {
      backgroundColor = Colors.red.shade100;
      textColor = Colors.red.shade800;
      borderColor = Colors.red.shade500;
    } else if (isSelected) {
      backgroundColor = Theme.of(context).primaryColor.withOpacity(0.2);
      textColor = isDarkMode ? Colors.white : Theme.of(context).primaryColor;
      borderColor = Theme.of(context).primaryColor;
    } else {
      backgroundColor = isDarkMode ? Theme.of(context).cardColor : Colors.white;
      textColor = isDarkMode ? Colors.white : Colors.black;
      borderColor = Colors.grey.shade300;
    }
    
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: textColor,
            fontWeight: isSelected || isCorrect || isWrong ? FontWeight.bold : FontWeight.normal,
            fontSize: 18,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
} 