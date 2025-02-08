import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(ChineseFlashcardsApp());
}

class ChineseFlashcardsApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chinese Flashcards',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomeScreen(),
    );
  }
}
