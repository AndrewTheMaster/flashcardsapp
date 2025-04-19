import 'package:flutter/material.dart';
import '../services/local_bert_service.dart';

class ExerciseScreen extends StatefulWidget {
  @override
  _ExerciseScreenState createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  final LocalBertService _bertService = LocalBertService();
  bool _isLoading = false;
  String _maskedText = '';
  List<String> _answers = [];
  TextEditingController _textController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _initBertModel();
  }
  
  Future<void> _initBertModel() async {
    setState(() => _isLoading = true);
    try {
      await _bertService.loadModel();
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _generateExercise() async {
    if (_textController.text.isEmpty) return;
    
    setState(() => _isLoading = true);
    
    try {
      final result = await _bertService.createFillInBlanks(
        _textController.text, 
        3, // количество пропусков
        2  // средний уровень сложности
      );
      
      setState(() {
        _maskedText = result['masked_text'];
        _answers = List<String>.from(result['answers']);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'))
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Упражнение с пропусками'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                labelText: 'Введите китайский текст',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _generateExercise,
              child: _isLoading 
                ? CircularProgressIndicator(color: Colors.white)
                : Text('Сгенерировать упражнение'),
            ),
            SizedBox(height: 24),
            if (_maskedText.isNotEmpty) ...[
              Text(
                'Текст с пропусками:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                _maskedText.replaceAll('[MASK]', '_____'),
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 16),
              Text(
                'Ответы:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _answers.map((answer) => 
                  Chip(label: Text(answer))
                ).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _bertService.dispose();
    _textController.dispose();
    super.dispose();
  }
} 