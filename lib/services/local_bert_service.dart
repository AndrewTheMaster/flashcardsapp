import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class LocalBertService {
  Interpreter? _interpreter;
  Map<String, int>? _vocabMap;
  
  Future<void> loadModel() async {
    // Загрузка модели из assets
    final modelFile = await _getModelFile('assets/models/chinese_bert_model.tflite');
    
    // Установка потоков и ускорителей
    final options = InterpreterOptions()
      ..threads = 4
      ..useNnApiForAndroid = true;  // Использование Neural API на Android
    
    _interpreter = await Interpreter.fromFile(modelFile, options: options);
    
    // Загрузка словаря
    final vocabStr = await rootBundle.loadString('assets/models/vocab.txt');
    _vocabMap = {};
    
    final vocabLines = vocabStr.split('\n');
    for (var i = 0; i < vocabLines.length; i++) {
      final token = vocabLines[i].trim();
      if (token.isNotEmpty) {
        _vocabMap![token] = i;
      }
    }
  }
  
  Future<File> _getModelFile(String assetPath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final file = File('${appDir.path}/chinese_bert_model.tflite');
    
    if (!await file.exists()) {
      final byteData = await rootBundle.load(assetPath);
      await file.writeAsBytes(byteData.buffer.asUint8List());
    }
    
    return file;
  }
  
  List<String> tokenize(String text) {
    // Простая токенизация по символам для китайского
    return text.split('');
  }
  
  Future<Map<String, dynamic>> createFillInBlanks(String text, int numBlanks, int difficulty) async {
    if (_interpreter == null) await loadModel();
    
    // Токенизация текста
    final tokens = tokenize(text);
    
    // Создаем входные данные для модели
    final inputIds = tokens.map((token) => 
        _vocabMap!.containsKey(token) ? _vocabMap![token]! : _vocabMap!['[UNK]']!).toList();
    
    // Добавляем [CLS] и [SEP]
    inputIds.insert(0, _vocabMap!['[CLS]']!);
    inputIds.add(_vocabMap!['[SEP]']!);
    
    // Подготовка буферов для TFLite
    final inputBuffers = [
      [inputIds], // input_ids
      [[1] * inputIds.length], // attention_mask
      [[0] * inputIds.length], // token_type_ids
    ];
    
    final outputBuffer = [
      List<List<double>>.filled(1, List<double>.filled(inputIds.length, 0))
    ];
    
    // Вызов модели
    _interpreter!.run(inputBuffers, outputBuffer);
    
    // Результаты прогнозов для маскированных позиций
    final predictions = outputBuffer[0][0];
    
    // Выбор токенов для маскирования на основе сложности
    // Для простоты выберем случайные токены
    final maskedIndices = _selectTokensForMasking(tokens, numBlanks, difficulty);
    
    // Создание маскированного текста
    final maskedTokens = List<String>.from(tokens);
    final answers = <String>[];
    
    for (final index in maskedIndices) {
      answers.add(tokens[index]);
      maskedTokens[index] = '[MASK]';
    }
    
    return {
      'masked_text': maskedTokens.join(''),
      'original_text': text,
      'answers': answers,
    };
  }
  
  List<int> _selectTokensForMasking(List<String> tokens, int numBlanks, int difficulty) {
    // Здесь должна быть логика выбора токенов на основе сложности
    // Для примера используем случайный выбор
    final candidates = <int>[];
    
    for (var i = 0; i < tokens.length; i++) {
      if (tokens[i].trim().isNotEmpty) {
        candidates.add(i);
      }
    }
    
    candidates.shuffle();
    
    // Ограничиваем количество масок
    final numMasks = numBlanks.clamp(1, candidates.length);
    return candidates.sublist(0, numMasks);
  }
  
  void dispose() {
    _interpreter?.close();
  }
} 