import 'package:flutter/material.dart';
import '../models/flashcard.dart';
import '../services/sentence_generator_service.dart';
import '../models/exercise_data.dart';

class SentenceExerciseScreen extends StatefulWidget {
  final List<Flashcard> flashcards;
  final int difficultyLevel;
  final ExerciseType type;

  const SentenceExerciseScreen({
    required this.flashcards,
    this.difficultyLevel = 1,
    this.type = ExerciseType.singleSentence,
    Key? key,
  }) : super(key: key);

  @override
  State<SentenceExerciseScreen> createState() => _SentenceExerciseScreenState();
}

class _SentenceExerciseScreenState extends State<SentenceExerciseScreen> {
  final SentenceGeneratorService _generator = SentenceGeneratorService();
  late ExerciseData _currentExercise;
  final Map<String, String> _userAnswers = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeExercise();
  }

  Future<void> _initializeExercise() async {
    setState(() => _isLoading = true);
    
    try {
      await _generator.initialize();
      await _generateNewExercise();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateNewExercise() async {
    final exercise = await _generator.generateExercise(
      widget.flashcards,
      widget.difficultyLevel,
      widget.type,
    );
    
    if (mounted) {
      setState(() {
        _currentExercise = exercise;
        _userAnswers.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Упражнение')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Заполните пропуски')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              _currentExercise.question,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _currentExercise.answers.keys.map((position) {
                return DropdownButton<String>(
                  hint: Text('Пропуск ${int.parse(position) + 1}'),
                  value: _userAnswers[position],
                  items: _currentExercise.options.map((word) {
                    return DropdownMenuItem(
                      value: word,
                      child: Text(word),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _userAnswers[position] = value;
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _checkAnswers,
              child: const Text('Проверить'),
            ),
          ],
        ),
      ),
    );
  }

  void _checkAnswers() {
    if (_userAnswers.length != _currentExercise.answers.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заполните все пропуски'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    bool allCorrect = true;
    final wrongAnswers = <String>[];

    for (var entry in _currentExercise.answers.entries) {
      if (_userAnswers[entry.key] != entry.value) {
        allCorrect = false;
        wrongAnswers.add(entry.value);
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(allCorrect ? 'Поздравляем!' : 'Попробуйте еще раз'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(allCorrect 
              ? 'Все ответы верны!' 
              : 'Правильные ответы:\n${wrongAnswers.join(", ")}'
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (allCorrect) {
                _generateNewExercise();
              }
            },
            child: Text(allCorrect ? 'Следующее задание' : 'OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
} 