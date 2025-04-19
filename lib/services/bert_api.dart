import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;

class BertApi {
  // Для локального подключения с реального устройства:
  static const String baseUrl = 'http://192.168.1.100:8000/api';
  // или для эмулятора Android:
  // static const String baseUrl = 'http://10.0.2.2:8000/api';

  // Заглушка метода для генерации предложений из карточек
  Future<Map<String, dynamic>> generateFromCards({
    required List<Map<String, dynamic>> cards,
    String difficulty = 'medium',
    int numSentences = 5,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/generate-from-cards'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'cards': cards,
          'difficulty': difficulty,
          'num_sentences': numSentences,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['detail'] ?? 'Ошибка при генерации предложений');
      }
    } catch (e) {
      developer.log('Ошибка API: $e', name: 'bert_api');
      // В случае ошибки возвращаем моковые данные
      return {
        'sentences': [
          {
            'masked_text': '我喜欢学习[MASK]语。',
            'original_text': '我喜欢学习中文语。',
            'answers': {'2': '中文'},
            'difficulty': 'medium'
          },
          // Другие моковые предложения...
        ]
      };
    }
  }

  // Проверка здоровья сервера
  Future<bool> checkServerHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      return response.statusCode == 200;
    } catch (e) {
      print('Ошибка при проверке сервера: $e');
      return false;
    }
  }

  // Генерация текста с пропусками
  Future<Map<String, dynamic>> generateBlanks({
    required String text,
    String difficulty = 'medium',
    int numBlanks = 3,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/generate-blanks'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'difficulty': difficulty,
          'num_blanks': numBlanks,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['detail'] ?? 'Ошибка при генерации текста с пропусками');
      }
    } catch (e) {
      print('API ошибка (generateBlanks): $e');
      rethrow;
    }
  }

  // Генерация карточек
  Future<Map<String, dynamic>> generateCards({
    String category = 'all',
    String difficulty = 'medium',
    int numCards = 5,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/generate-cards'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'category': category,
          'difficulty': difficulty,
          'num_cards': numCards,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['detail'] ?? 'Ошибка при генерации карточек');
      }
    } catch (e) {
      print('API ошибка (generateCards): $e');
      rethrow;
    }
  }
} 