import 'package:flutter/material.dart';
import '../models/flashcard.dart';
import 'dart:math';
import '../screens/sentence_completion_screen.dart';

class SentenceCompletionScreen extends StatefulWidget {
  final List<Flashcard> flashcards;

  const SentenceCompletionScreen({required this.flashcards, Key? key}) : super(key: key);

  @override
  _SentenceCompletionScreenState createState() => _SentenceCompletionScreenState();
}

class _SentenceCompletionScreenState extends State<SentenceCompletionScreen> {
  List<Flashcard> selectedFlashcards = [];
  String generatedSentence = "";
  List<String> missingWords = [];
  Map<int, String> userAnswers = {};

  @override
  void initState() {
    super.initState();
    _generateSentence();
  }

  void _generateSentence() {
    if (widget.flashcards.length < 5) return;

    selectedFlashcards = (widget.flashcards..shuffle()).take(5).toList();

    generatedSentence = "";
    missingWords = [];
    userAnswers.clear();

    for (var i = 0; i < selectedFlashcards.length; i++) {
      if (i % 2 == 0) {
        missingWords.add(selectedFlashcards[i].hanzi);
        generatedSentence += " ____ ";
      } else {
        generatedSentence += "${selectedFlashcards[i].translation} ";
      }
    }

    setState(() {});
  }

  void _checkAnswers() {
    bool allCorrect = true;
    for (int i = 0; i < missingWords.length; i++) {
      if (userAnswers[i] != missingWords[i]) {
        allCorrect = false;
        break;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(allCorrect ? "Правильно!" : "Ошибка, попробуйте снова."),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Заполни пропуски')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(generatedSentence, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            for (int i = 0; i < missingWords.length; i++)
              DropdownButton<String>(
                hint: const Text("Выберите слово"),
                value: userAnswers[i],
                items: selectedFlashcards.map((card) {
                  return DropdownMenuItem(
                    value: card.hanzi,
                    child: Text(card.hanzi),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    userAnswers[i] = value!;
                  });
                },
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _checkAnswers,
              child: const Text("Проверить"),
            ),
          ],
        ),
      ),
    );
  }
}
