import 'package:flutter/material.dart';
import '../services/translation_service.dart';

class FlashcardEditorScreen extends StatefulWidget {
  final Function(String, String, String) onSave;
  final String? initialHanzi;
  final String? initialPinyin;
  final String? initialTranslation;

  const FlashcardEditorScreen({
    required this.onSave,
    this.initialHanzi,
    this.initialPinyin,
    this.initialTranslation,
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

  @override
  void initState() {
    super.initState();
    if (widget.initialHanzi != null) {
      _hanziController.text = widget.initialHanzi!;
      _pinyinController.text = widget.initialPinyin!;
      _translationController.text = widget.initialTranslation!;
    }
  }

  Future<void> _fetchTranslation() async {
    String text = _hanziController.text.trim();
    if (text.isEmpty) return;

    final result = await TranslationService.translate(text);
    setState(() {
      _pinyinController.text = result['pinyin']!;
      _translationController.text = result['translation']!;
      _suggestionMessage = "Предложен перевод (можно изменить)";
    });
  }

  void _saveFlashcard() {
    widget.onSave(
      _hanziController.text.trim(),
      _pinyinController.text.trim(),
      _translationController.text.trim(),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Добавить карточку")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _hanziController, decoration: InputDecoration(labelText: "Иероглиф"), onChanged: (_) => _fetchTranslation()),
            TextField(controller: _pinyinController, decoration: InputDecoration(labelText: "Пиньинь")),
            TextField(controller: _translationController, decoration: InputDecoration(labelText: "Перевод")),
            if (_suggestionMessage != null) Text(_suggestionMessage!, style: TextStyle(color: Colors.grey)),
            SizedBox(height: 20),
            ElevatedButton(onPressed: _saveFlashcard, child: Text("Сохранить"))
          ],
        ),
      ),
    );
  }
}
