import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/flashcard_pack.dart';

/// Service for storing and retrieving flashcard data
class StorageService {
  static const String FLASHCARDS_KEY = 'flashcards';

  /// Save flashcard packs to SharedPreferences
  static Future<void> saveFlashcardPacks(List<FlashcardPack> packs) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(packs.map((pack) => pack.toJson()).toList());
    await prefs.setString(FLASHCARDS_KEY, jsonString);
  }

  /// Load flashcard packs from SharedPreferences
  static Future<List<FlashcardPack>> loadFlashcardPacks() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(FLASHCARDS_KEY);
    if (jsonString == null) return [];
    
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => FlashcardPack.fromJson(json)).toList();
  }
}