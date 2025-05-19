import 'package:flutter/material.dart';
import '../services/translation_service.dart';
import '../localization/app_localizations.dart';
import 'dart:async';
import '../providers/settings_provider.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:developer' as developer;


class FlashcardEditorScreen extends StatefulWidget {
  final Function(String, String, String) onSave;
  final Function(String, String, String) onUpdate;
  final List<Map<String, dynamic>> existingCards;

  const FlashcardEditorScreen({
    required this.onSave,
    required this.onUpdate,
    required this.existingCards,
    Key? key,
  }) : super(key: key);

  @override
  _FlashcardEditorScreenState createState() => _FlashcardEditorScreenState();
}

class _FlashcardEditorScreenState extends State<FlashcardEditorScreen> {
  final _hanziController = TextEditingController();
  final _pinyinController = TextEditingController();
  final _translationController = TextEditingController();
  String? _suggestionMessage;
  Timer? _debounceTimer;
  bool _isTranslating = false;

  @override
  void dispose() {
    _hanziController.dispose();
    _pinyinController.dispose();
    _translationController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onHanziChanged(String text) {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer?.cancel();
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _fetchTranslation();
    });
  }
  
  // Добавляем обработку изменений в поле перевода
  void _onTranslationChanged(String text) {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer?.cancel();
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _reverseTranslate(text);
    });
  }

  Future<void> _fetchTranslation() async {
    final text = _hanziController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isTranslating = true;
    });

    try {
      final result = await TranslationService.translateStatic(text);
      setState(() {
        _pinyinController.text = result['pinyin'] ?? '';
        _translationController.text = result['translation'] ?? '';
        _suggestionMessage = 'suggested_translation'.tr(context);
        _isTranslating = false;
      });
    } catch (e) {
      setState(() {
        _suggestionMessage = 'translation_error'.tr(context);
        _isTranslating = false;
      });
    }
  }
  
  // Добавляем метод для обратного перевода
  Future<void> _reverseTranslate(String text) async {
    if (text.isEmpty) return;
    
    setState(() {
      _isTranslating = true;
    });
    
    try {
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      final serverUrl = settingsProvider.serverAddress;
      
      // Если сервер не указан или режим офлайн, используем локальный словарь
      if (serverUrl == null || serverUrl.isEmpty || settingsProvider.offlineMode) {
        // Простой локальный словарь
        final Map<String, Map<String, String>> dictionary = {
          'мясо': {'hanzi': '肉', 'pinyin': 'ròu'},
          'рис': {'hanzi': '米饭', 'pinyin': 'mǐfàn'},
          'говядина': {'hanzi': '牛肉', 'pinyin': 'niúròu'},
          'баранина': {'hanzi': '羊肉', 'pinyin': 'yángròu'},
          'sheepmeat': {'hanzi': '羊肉', 'pinyin': 'yángròu'},
          'вода': {'hanzi': '水', 'pinyin': 'shuǐ'},
          'суп': {'hanzi': '汤', 'pinyin': 'tāng'},
          'есть суп': {'hanzi': '喝汤', 'pinyin': 'hē tāng'},
        };
        
        final lowerText = text.toLowerCase().trim();
        if (dictionary.containsKey(lowerText)) {
          setState(() {
            _hanziController.text = dictionary[lowerText]!['hanzi']!;
            _pinyinController.text = dictionary[lowerText]!['pinyin']!;
            _suggestionMessage = 'found_in_dictionary'.tr(context);
            _isTranslating = false;
          });
          return;
        }
        
        // Не нашли в словаре
        setState(() {
          _suggestionMessage = 'no_reverse_translation'.tr(context);
          _isTranslating = false;
        });
        return;
      }
      
      // Запрос к серверу
      final url = Uri.parse('$serverUrl/reverse-translate');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'text': text,
          'language': 'ru'
        }),
      ).timeout(Duration(seconds: 10));
      
      // Явно декодируем ответ с UTF-8
      final responseBody = utf8.decode(response.bodyBytes);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        
        if (data['hanzi'] != null && data['hanzi'].toString().isNotEmpty) {
          setState(() {
            _hanziController.text = data['hanzi'] ?? '';
            _pinyinController.text = data['pinyin'] ?? '';
            _suggestionMessage = 'reverse_translation_success'.tr(context);
            _isTranslating = false;
          });
          
          developer.log(
            'FlashcardEditor: Получен обратный перевод: "${text}" -> "${data['hanzi']}" (${data['pinyin']})',
            name: 'flashcard_editor'
          );
        } else {
          setState(() {
            _suggestionMessage = 'no_reverse_translation'.tr(context);
            _isTranslating = false;
          });
        }
      } else {
        setState(() {
          _suggestionMessage = 'reverse_translation_error'.tr(context);
          _isTranslating = false;
        });
      }
    } catch (e) {
      developer.log('FlashcardEditor: Ошибка обратного перевода: $e', name: 'flashcard_editor');
      setState(() {
        _suggestionMessage = 'reverse_translation_error'.tr(context);
        _isTranslating = false;
      });
    }
  }

  void _saveOrUpdateFlashcard() {
    final hanzi = _hanziController.text.trim();
    final pinyin = _pinyinController.text.trim();
    final translation = _translationController.text.trim();

    // Проверяем, заполнены ли обязательные поля
    if (hanzi.isEmpty || translation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('required_fields_error'.tr(context)),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Проверяем, существует ли карточка с таким иероглифом
    final existingCard = widget.existingCards.firstWhere(
          (card) => card['hanzi'] == hanzi,
      orElse: () => {},
    );

    if (existingCard.isNotEmpty) {
      // Если карточка существует, обновляем её
      widget.onUpdate(hanzi, pinyin, translation);
    } else {
      // Если карточки нет, создаём новую
      widget.onSave(hanzi, pinyin, translation);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(title: Text('edit_flashcard'.tr(context))),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _hanziController,
              decoration: InputDecoration(
                labelText: 'hanzi'.tr(context),
                labelStyle: TextStyle(color: isDarkMode ? Colors.white70 : null),
                border: OutlineInputBorder(),
              ),
              onChanged: _onHanziChanged,
            ),
            SizedBox(height: 16),
            TextField(
              controller: _pinyinController,
              decoration: InputDecoration(
                labelText: 'pinyin'.tr(context),
                labelStyle: TextStyle(color: isDarkMode ? Colors.white70 : null),
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _translationController,
              decoration: InputDecoration(
                labelText: 'translation'.tr(context),
                labelStyle: TextStyle(color: isDarkMode ? Colors.white70 : null),
                border: OutlineInputBorder(),
                helperText: 'Type translation to find Chinese'.tr(context),
              ),
              onChanged: _onTranslationChanged,
            ),
            if (_suggestionMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _suggestionMessage!,
                  style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                ),
              ),
            if (_isTranslating)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveOrUpdateFlashcard,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text('save'.tr(context)),
            ),
          ],
        ),
      ),
    );
  }
}