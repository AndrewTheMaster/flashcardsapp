import 'package:flutter/material.dart';
import '../services/translation_service.dart';
import 'dart:async';


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

  Future<void> _fetchTranslation() async {
    final text = _hanziController.text.trim();
    if (text.isEmpty) return;

    try {
      final result = await TranslationService.translate(text);
      setState(() {
        _pinyinController.text = result['pinyin']!;
        _translationController.text = result['translation']!;
        _suggestionMessage = "Предложен перевод (можно изменить)";
      });
    } catch (e) {
      setState(() {
        _suggestionMessage = "Ошибка при загрузке перевода";
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
          content: Text('Поля "Иероглиф" и "Перевод" обязательны для заполнения'),
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
    return Scaffold(
      appBar: AppBar(title: Text("Добавить/Изменить карточку")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _hanziController,
              decoration: InputDecoration(labelText: "Иероглиф"),
              onChanged: _onHanziChanged,
            ),
            TextField(
              controller: _pinyinController,
              decoration: InputDecoration(labelText: "Пиньинь"),
            ),
            TextField(
              controller: _translationController,
              decoration: InputDecoration(labelText: "Перевод"),
            ),
            if (_suggestionMessage != null)
              Text(
                _suggestionMessage!,
                style: TextStyle(color: Colors.grey),
              ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveOrUpdateFlashcard,
              child: Text("Сохранить"),
            ),
          ],
        ),
      ),
    );
  }
}