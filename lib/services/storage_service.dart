import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/flashcard.dart';

class StorageService {
  static const String _key = 'flashcards';

  static Future<void> saveFlashcards(List<Flashcard> flashcards) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(flashcards.map((f) => f.toJson()).toList());
    await prefs.setString(_key, jsonString);
  }

  static Future<List<Flashcard>> loadFlashcards() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString == null) return [];
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => Flashcard.fromJson(json)).toList();
  }
}