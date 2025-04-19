import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../models/flashcard.dart';
import '../models/sentence_template.dart';
import '../models/exercise_data.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class SentenceGeneratorService {
  // Кэш для предложений и их шаблонов
  final Map<String, List<SentenceTemplate>> _sentenceTemplates = {};
  
  // Модель для определения сложности предложения
  late final Interpreter _difficultyClassifier;
  
  Future<void> initialize() async {
    await _loadSentenceTemplates();
  }

  Future<void> _loadSentenceTemplates() async {
    try {
      final String data = await rootBundle.loadString('assets/sentence_templates.json');
      final Map<String, dynamic> jsonData = json.decode(data);
      
      jsonData.forEach((category, templates) {
        _sentenceTemplates[category] = (templates as List)
            .map((template) => SentenceTemplate.fromJson(template))
            .toList();
      });
    } catch (e) {
      print('Error loading templates: $e');
      // Создаем базовые шаблоны если файл не найден
      _sentenceTemplates['basic'] = [
        SentenceTemplate(
          original: "我想学习____和____。",
          slots: ["中文", "英语"],
          difficulty: 1,
          category: "study",
        ),
      ];
    }
  }

  Future<List<SentenceTemplate>> getSuitableTemplates(
    List<Flashcard> cards,
    int difficultyLevel,
  ) async {
    final templates = <SentenceTemplate>[];
    
    for (var categoryTemplates in _sentenceTemplates.values) {
      templates.addAll(
        categoryTemplates.where((template) {
          if (template.difficulty > difficultyLevel) return false;
          
          final availableWords = cards.map((c) => c.hanzi).toSet();
          return template.slots.any((slot) => availableWords.contains(slot));
        }),
      );
    }
    
    return templates;
  }

  Future<ExerciseData> generateExercise(
    List<Flashcard> cards,
    int difficultyLevel,
    ExerciseType type,
  ) async {
    final templates = await getSuitableTemplates(cards, difficultyLevel);
    if (templates.isEmpty) {
      throw Exception('Нет подходящих шаблонов для данных карточек');
    }

    switch (type) {
      case ExerciseType.singleSentence:
        return _generateSingleSentenceExercise(templates, cards);
      case ExerciseType.multiSentence:
        return _generateSingleSentenceExercise(templates, cards); // Временно используем тот же генератор
      case ExerciseType.dialogue:
        return _generateSingleSentenceExercise(templates, cards); // Временно используем тот же генератор
    }
  }

  ExerciseData _generateSingleSentenceExercise(
    List<SentenceTemplate> templates,
    List<Flashcard> cards,
  ) {
    final template = templates[Random().nextInt(templates.length)];
    final availableWords = cards.map((c) => c.hanzi).toSet();
    
    final slots = template.slots.where((slot) => availableWords.contains(slot)).toList();
    final wordsToReplace = slots.take(2).toList();
    
    String question = template.original;
    final answers = <String, String>{};
    
    for (var word in wordsToReplace) {
      final index = question.indexOf(word);
      question = question.replaceFirst(word, '_____');
      answers[index.toString()] = word;
    }
    
    return ExerciseData(
      question: question,
      answers: answers,
      options: cards.map((c) => c.hanzi).toList()..shuffle(),
    );
  }

  Future<String> generateSentence(List<Flashcard> flashcards) async {
    // Your implementation
    return "This is a generated sentence using your flashcards";
  }

  void dispose() {
    // Clean up resources
    _difficultyClassifier.close();
    // Add any other cleanup needed
  }
} 