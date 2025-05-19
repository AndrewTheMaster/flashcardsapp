import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/flashcard.dart';
import '../providers/cards_provider.dart';
import '../localization/app_localizations.dart';
import '../providers/settings_provider.dart';

class SrsQuizScreen extends StatefulWidget {
  const SrsQuizScreen({Key? key}) : super(key: key);

  @override
  _SrsQuizScreenState createState() => _SrsQuizScreenState();
}

class _SrsQuizScreenState extends State<SrsQuizScreen> {
  final TextEditingController _answerController = TextEditingController();
  bool _showCharacterFirst = true; // Toggle between showing character or translation
  bool _checked = false;
  bool _isCorrect = false;
  Flashcard? _currentCard;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Delay to ensure widget is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCards();
    });
  }

  Future<void> _initializeCards() async {
    setState(() {
      _isLoading = true;
    });
    
    final cardsProvider = Provider.of<CardsProvider>(context, listen: false);
    
    // Ensure packs are loaded
    if (cardsProvider.allPacks.isEmpty) {
      await cardsProvider.loadAllPacks();
    }
    
    _loadNextCard();
    
    setState(() {
      _isLoading = false;
    });
  }

  void _loadNextCard() {
    final cardsProvider = Provider.of<CardsProvider>(context, listen: false);
    
    setState(() {
      _checked = false;
      _isCorrect = false;
      _answerController.clear();
      
      // Get all available cards from provider
      List<Flashcard> allCards = [];
      
      // First try to get due cards
      if (cardsProvider.dueCards.isNotEmpty) {
        allCards = List.from(cardsProvider.dueCards);
      } else {
        // If no due cards, get all cards sorted by SRS level
        allCards = cardsProvider.getCardsSortedBySrs();
      }
      
      // Set current card to the one with lowest SRS level
      if (allCards.isNotEmpty) {
        _currentCard = allCards.first;
      } else {
        _currentCard = null;
      }
    });
  }

  void _checkAnswer() {
    if (_currentCard == null) return;
    
    String correctAnswer = _showCharacterFirst 
        ? _currentCard!.translation 
        : _currentCard!.hanzi;
    
    bool isCorrect = _answerController.text.trim().toLowerCase() == 
        correctAnswer.toLowerCase();
    
    setState(() {
      _checked = true;
      _isCorrect = isCorrect;
    });
    
    // Update SRS based on correctness
    final cardsProvider = Provider.of<CardsProvider>(context, listen: false);
    cardsProvider.reviewCard(_currentCard!, _isCorrect);
  }

  void _toggleMode() {
    setState(() {
      _showCharacterFirst = !_showCharacterFirst;
      _checked = false;
      _isCorrect = false;
      _answerController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('srs_quiz'.tr(context)),
        actions: [
          Row(
            children: [
              Text(_showCharacterFirst 
                ? 'character_first'.tr(context) 
                : 'translation_first'.tr(context),
                style: TextStyle(fontSize: 14),
              ),
              Switch(
                value: _showCharacterFirst,
                onChanged: (value) => _toggleMode(),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading 
          ? Center(child: CircularProgressIndicator())
          : _currentCard == null
              ? Center(child: Text('no_cards_available'.tr(context)))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Display either character or translation
                      Text(
                        _showCharacterFirst ? _currentCard!.hanzi : _currentCard!.translation,
                        style: Theme.of(context).textTheme.displayLarge,
                        textAlign: TextAlign.center,
                      ),
                      
                      if (_showCharacterFirst && _currentCard!.pinyin.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            _currentCard!.pinyin,
                            style: TextStyle(
                              fontSize: 18,
                              fontStyle: FontStyle.italic,
                              color: isDark ? Colors.grey[300] : Colors.grey[700],
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 40),
                      
                      // Input field for answer
                      TextField(
                        controller: _answerController,
                        decoration: InputDecoration(
                          hintText: _showCharacterFirst 
                              ? 'type_translation'.tr(context) 
                              : 'type_character'.tr(context),
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: isDark ? Colors.grey[800] : Colors.grey[200],
                        ),
                        enabled: !_checked,
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Show feedback when checked
                      if (_checked)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _isCorrect ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Text(
                                _isCorrect 
                                    ? 'correct'.tr(context) 
                                    : 'incorrect'.tr(context),
                                style: TextStyle(
                                  color: _isCorrect ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'correct_answer'.tr(context) + ': ' + 
                                (_showCharacterFirst ? _currentCard!.translation : _currentCard!.hanzi),
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      
                      const Spacer(),
                      
                      // Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: _checked 
                                ? _loadNextCard 
                                : _checkAnswer,
                            child: Text(_checked 
                                ? 'next'.tr(context)
                                : 'check'.tr(context)),
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size(150, 50),
                            ),
                          ),
                        ],
                      ),
                      
                      // SRS info
                      const SizedBox(height: 30),
                      Text(
                        'SRS Level: ${_currentCard!.repetitionLevel}',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }
  
  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }
} 