import 'package:flutter/material.dart';
import '../models/flashcard.dart';

class FlashcardWidget extends StatelessWidget {
  final Flashcard flashcard;
  final VoidCallback onFlip;
  final bool showTranslation;

  FlashcardWidget({required this.flashcard, required this.onFlip, required this.showTranslation});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onFlip,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 250,
          height: 150,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!showTranslation) ...[
                Text(
                  flashcard.character,
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  flashcard.pinyin,
                  style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic),
                ),
              ] else ...[
                Text(
                  flashcard.translation,
                  style: TextStyle(fontSize: 24),
                  textAlign: TextAlign.center,
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}