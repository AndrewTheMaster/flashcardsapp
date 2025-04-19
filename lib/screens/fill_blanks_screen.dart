import 'package:flutter/material.dart';
import '../services/bert_api.dart';
import '../models/flashcard.dart';
import '../models/flashcard_pack.dart';
import 'dart:developer' as developer;

class FillBlanksScreen extends StatefulWidget {
  final FlashcardPack? currentPack; // Принимаем текущий пак
  
  const FillBlanksScreen({Key? key, this.currentPack}) : super(key: key);
  
  @override
  _FillBlanksScreenState createState() => _FillBlanksScreenState();
}

class _FillBlanksScreenState extends State<FillBlanksScreen> {
  final BertApi _api = BertApi();
  List<dynamic> _sentences = [];
  bool _isLoading = false;
  String _error = '';
  int _currentIndex = 0;
  Map<String, String> _userAnswers = {};
  bool _showResults = false;
  final String _difficulty = 'medium'; // Фиксированная средняя сложность
  int _numCards = 5; // Сколько карточек использовать
  
  @override
  void initState() {
    super.initState();
    developer.log('FillBlanksScreen: initState вызван', name: 'fill_blanks');
    _loadSentences();
  }
  
  Future<void> _loadSentences() async {
    developer.log('FillBlanksScreen: _loadSentences вызван', name: 'fill_blanks');
    
    setState(() {
      _isLoading = true;
      _error = '';
    });
    
    try {
      developer.log('FillBlanksScreen: Текущий пак: ${widget.currentPack != null ? widget.currentPack!.cards.length : 'null'} карточек', 
          name: 'fill_blanks');
      
      if (widget.currentPack == null || widget.currentPack!.cards.isEmpty) {
        setState(() {
          _error = 'Нет доступных карточек в текущем паке';
          _isLoading = false;
        });
        developer.log('FillBlanksScreen: Ошибка - нет карточек', name: 'fill_blanks');
        return;
      }
      
      final availableCards = List<Flashcard>.from(widget.currentPack!.cards);
      availableCards.shuffle();
      final selectedCards = availableCards.take(_numCards).toList();
      
      developer.log('FillBlanksScreen: Выбрано ${selectedCards.length} карточек', name: 'fill_blanks');
      
      final cardMaps = selectedCards.map((card) => {
        'hanzi': card.hanzi,
        'pinyin': card.pinyin,
        'translation': card.translation,
      }).toList();
      
      // Отладочный ответ для проверки отображения
      final mockResponse = {
        'sentences': [
          {
            'masked_text': '我喜欢学习[MASK]语。',
            'original_text': '我喜欢学习中文语。',
            'answers': {'2': '中文'},
            'difficulty': 'medium'
          },
          {
            'masked_text': '今天[MASK]很好。',
            'original_text': '今天天气很好。',
            'answers': {'1': '天气'},
            'difficulty': 'medium'
          },
          {
            'masked_text': '我的[MASK]叫小明。',
            'original_text': '我的朋友叫小明。',
            'answers': {'1': '朋友'},
            'difficulty': 'medium'
          }
        ]
      };
      
      developer.log('FillBlanksScreen: Получены предложения: ${mockResponse['sentences']?.length}', 
          name: 'fill_blanks');
      
      setState(() {
        _sentences = mockResponse['sentences'] ?? [];
        _currentIndex = 0;
        _isLoading = false;
      });
      
      if (_sentences.isNotEmpty) {
        developer.log('FillBlanksScreen: Первое предложение: ${_sentences[0]}', 
            name: 'fill_blanks');
      }
      
    } catch (e) {
      developer.log('FillBlanksScreen: Ошибка при загрузке: $e', name: 'fill_blanks');
      setState(() {
        _error = 'Ошибка при генерации предложений: $e';
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    developer.log('FillBlanksScreen: build вызван, состояние: isLoading=$_isLoading, error=${_error.isEmpty ? "нет" : "есть"}, sentences=${_sentences.length}', 
        name: 'fill_blanks');
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Заполни пропуски'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadSentences,
            tooltip: 'Обновить предложения',
          ),
        ],
      ),
      body: _isLoading 
        ? _buildLoadingView()
        : _error.isNotEmpty
          ? _buildErrorView()
          : _sentences.isEmpty
            ? _buildEmptyView()
            : _buildSentenceView(),
    );
  }
  
  Widget _buildLoadingView() {
    developer.log('FillBlanksScreen: отображение загрузки', name: 'fill_blanks');
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Загрузка предложений...'),
        ],
      ),
    );
  }
  
  Widget _buildErrorView() {
    developer.log('FillBlanksScreen: отображение ошибки: $_error', name: 'fill_blanks');
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red),
          SizedBox(height: 16),
          Text(_error, textAlign: TextAlign.center),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadSentences,
            child: Text('Попробовать снова'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyView() {
    developer.log('FillBlanksScreen: отображение пустого экрана', name: 'fill_blanks');
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Нет доступных предложений'),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadSentences,
            child: Text('Загрузить предложения'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSentenceView() {
    developer.log('FillBlanksScreen: отображение предложения ${_currentIndex + 1}/${_sentences.length}', 
        name: 'fill_blanks');
    
    final currentSentence = _sentences[_currentIndex];
    final maskedText = currentSentence['masked_text'] ?? '';
    final originalText = currentSentence['original_text'] ?? '';
    
    developer.log('FillBlanksScreen: maskedText="$maskedText", originalText="$originalText"', 
        name: 'fill_blanks');
    
    final parts = maskedText.split('[MASK]');
    
    developer.log('FillBlanksScreen: разделено на ${parts.length} частей', name: 'fill_blanks');
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Предложение ${_currentIndex + 1} из ${_sentences.length}',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ),
        
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  color: Colors.amber[100],
                  child: Text('Отладка: maskedText="$maskedText"'),
                ),
                
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Wrap(
                      alignment: WrapAlignment.start,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: List.generate(parts.length * 2 - 1, (index) {
                        developer.log('FillBlanksScreen: создание элемента $index', name: 'fill_blanks');
                        
                        if (index % 2 == 0) {
                          final textPart = parts[index ~/ 2];
                          developer.log('FillBlanksScreen: текстовая часть [$index]: "$textPart"', 
                              name: 'fill_blanks');
                          
                          return Text(
                            textPart,
                            style: TextStyle(fontSize: 18),
                          );
                        } else {
                          final blankIndex = index ~/ 2;
                          final answerKey = '${_currentIndex}-$blankIndex';
                          
                          developer.log('FillBlanksScreen: поле ввода [$index], ключ: $answerKey', 
                              name: 'fill_blanks');
                          
                          return Container(
                            width: 80,
                            margin: EdgeInsets.symmetric(horizontal: 4),
                            child: TextField(
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 18),
                              decoration: InputDecoration(
                                hintText: '填空',
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.blue),
                                ),
                              ),
                              enabled: !_showResults,
                              controller: TextEditingController(
                                text: _userAnswers[answerKey] ?? '',
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _userAnswers[answerKey] = value;
                                });
                              },
                            ),
                          );
                        }
                      }),
                    ),
                  ),
                ),
                
                if (_showResults)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Card(
                      color: Colors.green[50],
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Правильные ответы:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            SizedBox(height: 8),
                            Text(
                              originalText,
                              style: TextStyle(fontSize: 18),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _currentIndex > 0 ? () {
                  setState(() {
                    _currentIndex--;
                  });
                } : null,
                child: Text('← Назад'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _showResults ? Colors.orange : Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () {
                  setState(() {
                    _showResults = !_showResults;
                  });
                },
                child: Text(
                  _showResults ? 'Новые предложения' : 'Проверить',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: _currentIndex < _sentences.length - 1 ? () {
                  setState(() {
                    _currentIndex++;
                  });
                } : null,
                child: Text('Вперед →'),
              ),
            ],
          ),
        ),
      ],
    );
  }
} 