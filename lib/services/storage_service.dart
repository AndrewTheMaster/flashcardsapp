import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/flashcard_pack.dart';

class StorageService {
  static const String _key = 'flashcardPacks';

  static Future<void> saveFlashcardPacks(List<FlashcardPack> packs) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(packs.map((pack) => pack.toJson()).toList());
    await prefs.setString(_key, jsonString);
  }

  static Future<List<FlashcardPack>> loadFlashcardPacks() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString == null) return [];
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => FlashcardPack.fromJson(json)).toList();
  }
}