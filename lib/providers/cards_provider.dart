import 'package:flutter/foundation.dart';
import '../models/flashcard.dart';
import '../services/bert_api.dart';

class CardModel {
  final String maskedText;
  final String originalText;
  final Map<String, dynamic> answers;
  final String difficulty;

  CardModel({
    required this.maskedText,
    required this.originalText,
    required this.answers,
    required this.difficulty,
  });

  factory CardModel.fromJson(Map<String, dynamic> json) {
    return CardModel(
      maskedText: json['masked_text'] ?? '',
      originalText: json['original_text'] ?? '',
      answers: json['answers'] ?? {},
      difficulty: json['difficulty'] ?? 'medium',
    );
  }
}

class CardsProvider with ChangeNotifier {
  final BertApi _api = BertApi();
  List<CardModel> _cards = [];
  bool _isLoading = false;
  String _error = '';
  int _currentCardIndex = 0;
  Map<String, String> _userAnswers = {};
  bool _showResults = false;
  String _difficulty = 'medium';
  String _category = 'all';

  // Геттеры
  List<CardModel> get cards => _cards;
  bool get isLoading => _isLoading;
  String get error => _error;
  int get currentCardIndex => _currentCardIndex;
  Map<String, String> get userAnswers => _userAnswers;
  bool get showResults => _showResults;
  String get difficulty => _difficulty;
  String get category => _category;
  CardModel? get currentCard => 
      _cards.isNotEmpty && _currentCardIndex < _cards.length 
          ? _cards[_currentCardIndex] 
          : null;

  // Сеттеры
  void setDifficulty(String difficulty) {
    _difficulty = difficulty;
    notifyListeners();
  }

  void setCategory(String category) {
    _category = category;
    notifyListeners();
  }

  void setAnswer(String key, String answer) {
    _userAnswers[key] = answer;
    notifyListeners();
  }

  void nextCard() {
    if (_currentCardIndex < _cards.length - 1) {
      _currentCardIndex++;
      notifyListeners();
    }
  }

  void prevCard() {
    if (_currentCardIndex > 0) {
      _currentCardIndex--;
      notifyListeners();
    }
  }

  void showResultsToggle() {
    _showResults = !_showResults;
    notifyListeners();
  }

  // Загрузка карточек
  Future<void> loadCards() async {
    _isLoading = true;
    _error = '';
    _showResults = false;
    _userAnswers = {};
    _currentCardIndex = 0;
    notifyListeners();

    try {
      final response = await _api.generateCards(
        category: _category,
        difficulty: _difficulty,
        numCards: 5,
      );

      if (response.containsKey('cards') && response['cards'] is List) {
        _cards = (response['cards'] as List)
            .map((card) => CardModel.fromJson(card))
            .toList();
      } else {
        _error = 'Неверный формат ответа от сервера';
      }
    } catch (e) {
      _error = 'Ошибка загрузки карточек: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Перезагрузка карточек
  void resetCards() {
    _cards = [];
    _userAnswers = {};
    _showResults = false;
    _currentCardIndex = 0;
    notifyListeners();
  }
} 