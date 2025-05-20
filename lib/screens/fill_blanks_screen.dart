import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../models/flashcard_pack.dart';
import '../models/flashcard.dart';
import '../localization/app_localizations.dart';
import '../services/exercise_service_facade.dart';
import '../providers/settings_provider.dart';
import 'dart:developer' as developer;

class FillBlanksScreen extends StatefulWidget {
  final FlashcardPack? currentPack;
  final bool isDarkMode;

  const FillBlanksScreen({
    Key? key,
    this.currentPack,
    this.isDarkMode = false,
  }) : super(key: key);

  @override
  _FillBlanksScreenState createState() => _FillBlanksScreenState();
}

class _FillBlanksScreenState extends State<FillBlanksScreen> {
  String? currentSentence;
  String? hiddenWord;
  List<String> options = [];
  bool isCorrect = false;
  bool isChecked = false;
  String selectedOption = '';
  Flashcard? currentFlashcard;
  bool _isLoading = false;
  bool _isPreloading = false;
  String _statusMessage = '';
  bool _hasError = false;
  late ExerciseServiceFacade _exerciseService;
  Map<String, dynamic> _exerciseMetadata = {};
  double _generationProgress = 0.0;
  bool _showProgress = false;

  @override
  void initState() {
    super.initState();
    _exerciseService = ExerciseServiceFacade(Provider.of<SettingsProvider>(context, listen: false));
    _preloadExercises();
  }
  
  @override
  void dispose() {
    // Отменяем все активные запросы при закрытии экрана
    _exerciseService.cancelAllRequests();
    developer.log('FillBlanksScreen: dispose вызван, запросы отменены', name: 'fill_blanks_screen');
    super.dispose();
  }
  
  /// Предварительная загрузка упражнений в кэш
  void _preloadExercises() async {
    if (widget.currentPack == null || widget.currentPack!.cards.isEmpty) {
      developer.log('FillBlanksScreen: Текущий пак пуст или null', name: 'fill_blanks_screen');
      return;
    }
    
    if (!mounted) return; // Проверка перед обновлением состояния
    setState(() {
      _isPreloading = true;
    });
    
    try {
      // Выбираем карточки для предзагрузки (уменьшено до 5 штук для снижения нагрузки)
      final cardsToPreload = widget.currentPack!.cards.take(5).toList();
      
      // Запускаем предварительную загрузку
      await _exerciseService.prefetchExercises(cardsToPreload);
      
      // После предзагрузки, генерируем первое упражнение
      if (!mounted) return; // Проверка после асинхронного вызова
      _generateExercise();
    } catch (e) {
      developer.log('Ошибка при предзагрузке упражнений: $e', name: 'fill_blanks_screen');
      // Генерируем упражнение даже если предзагрузка не удалась
      if (!mounted) return; // Проверка после исключения
      _generateExercise();
    } finally {
      if (!mounted) return; // Проверка в finally
      setState(() {
        _isPreloading = false;
      });
    }
  }

  /// Обработчик прогресса генерации
  void _updateGenerationProgress(double progress) {
    if (!mounted) return;
    setState(() {
      _generationProgress = progress;
      _showProgress = true;
    });
  }

  void _generateExercise({bool forceRefresh = false, bool nextExercise = false}) async {
    if (widget.currentPack == null || widget.currentPack!.cards.isEmpty) {
      developer.log('FillBlanksScreen: Текущий пак пуст или null', name: 'fill_blanks_screen');
      return;
    }

    if (!mounted) return; // Проверка перед обновлением состояния
    setState(() {
      _isLoading = true;
      _statusMessage = '';
      _hasError = false;
      _showProgress = true;
      _generationProgress = 0.0;
    });

    try {
      // Если это переход к следующему упражнению для текущей карточки
      if (nextExercise && currentFlashcard != null) {
        // Получаем следующее упражнение для текущей карточки
        final exerciseData = await _exerciseService.getNextExercise(currentFlashcard!);
        
        // Проверяем, смонтирован ли виджет после асинхронного вызова
        if (!mounted) return;
        
        // Обновляем состояние
        setState(() {
          currentSentence = exerciseData['maskedText']?.replaceAll('[BLANK]', '____').replaceAll('[MASK]', '____');
          options = List<String>.from(exerciseData['options'] ?? []);
          hiddenWord = exerciseData['correctAnswer'] ?? currentFlashcard!.hanzi;
          isChecked = false;
          selectedOption = '';
          _isLoading = false;
          _exerciseMetadata = exerciseData;
          _showProgress = false;
        });
        
        developer.log(
          'FillBlanksScreen: Получено следующее упражнение: $currentSentence, правильный ответ: $hiddenWord', 
          name: 'fill_blanks_screen'
        );
        return;
      }

      final random = math.Random();
      List<Flashcard> cards = widget.currentPack!.cards;
      
      // Sort cards by spaced repetition priority
      // First prioritize cards that need review, then by repetition level (lowest first)
      cards.sort((a, b) {
        if (a.needsReview && !b.needsReview) return -1;
        if (!a.needsReview && b.needsReview) return 1;
        if (a.needsReview && b.needsReview) {
          return a.repetitionLevel.compareTo(b.repetitionLevel);
        }
        return 0;
      });
      
      // Pick first card that needs review, or random if all are reviewed
      Flashcard randomCard;
      List<Flashcard> cardsNeedingReview = cards.where((card) => card.needsReview).toList();
      
      if (cardsNeedingReview.isNotEmpty) {
        // Pick a card that needs review (with slight randomization if multiple)
        int randomIndex = cardsNeedingReview.length > 3 
            ? random.nextInt(3) // Pick from top 3 that need review
            : 0; // Just pick the first card if 3 or fewer
        randomCard = cardsNeedingReview[randomIndex];
      } else {
        // No cards need review, pick random
        int randomIndex = random.nextInt(cards.length);
        randomCard = cards[randomIndex];
      }
      
      currentFlashcard = randomCard;

      if (forceRefresh) {
        developer.log(
          'FillBlanksScreen: Запрошено принудительное обновление упражнения для "${randomCard.hanzi}"',
          name: 'fill_blanks_screen'
        );
      }

      // Получаем упражнение с пропусками от сервиса (с флагом forceRefresh)
      final exerciseData = await _exerciseService.generateFillBlanksExercise(
        randomCard, 
        forceRefresh: forceRefresh,
        onProgress: _updateGenerationProgress,
      );
      
      // Проверяем, смонтирован ли виджет после асинхронного вызова
      if (!mounted) return;
      
      // Обновляем состояние
      setState(() {
        currentSentence = exerciseData['maskedText']?.replaceAll('[BLANK]', '____').replaceAll('[MASK]', '____');
        options = List<String>.from(exerciseData['options'] ?? []);
        hiddenWord = exerciseData['correctAnswer'] ?? randomCard.hanzi;
        isChecked = false;
        selectedOption = '';
        _isLoading = false;
        _exerciseMetadata = exerciseData;
        _showProgress = false;
      });
      
      developer.log(
        'FillBlanksScreen: Сгенерировано упражнение: $currentSentence, правильный ответ: $hiddenWord', 
        name: 'fill_blanks_screen'
      );
    } catch (e) {
      if (!mounted) return; // Проверка перед обновлением состояния в блоке catch
      
      setState(() {
        _isLoading = false;
        _hasError = true;
        _statusMessage = e.toString();
        _showProgress = false;
        
        // Создаем простое упражнение при ошибке
        currentSentence = "这是 ____ 。";
        hiddenWord = currentFlashcard?.hanzi;
        options = [
          currentFlashcard?.hanzi ?? '', 
          '好', 
          '人', 
          '不'
        ];
        options.shuffle();
        isChecked = false;
        selectedOption = '';
      });
      
      developer.log(
        'FillBlanksScreen: Ошибка при генерации упражнения: $e', 
        name: 'fill_blanks_screen'
      );
    }
  }

  void _checkAnswer() {
    final bool isAnswerCorrect = selectedOption == hiddenWord;
    
    // Update spaced repetition data
    if (currentFlashcard != null) {
      currentFlashcard!.updateNextReviewDate(wasCorrect: isAnswerCorrect);
    }
    
    setState(() {
      isChecked = true;
      isCorrect = isAnswerCorrect;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Локализация и темная тема
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Получаем информацию о выбранном сервисе
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isUsingBertChineseWwm = settingsProvider.exerciseService.toString().contains('bertChineseWwm');
    final isOfflineMode = settingsProvider.offlineMode;
    final isDebugMode = settingsProvider.debugMode;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('fill_blanks'.tr(context)),
        actions: [
          // Кнопка перехода к следующему варианту упражнения
          IconButton(
            icon: Icon(Icons.rotate_right),
            tooltip: 'Следующий вариант упражнения',
            onPressed: _isLoading ? null : () => _generateExercise(nextExercise: true),
          ),
          // Кнопка обновления с сервера
          if (!isOfflineMode) IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'Обновить с сервера',
            onPressed: _isLoading ? null : () => _generateExercise(forceRefresh: true),
          ),
          // Индикатор сервиса
          Tooltip(
            message: isUsingBertChineseWwm 
                ? 'bert_chinese'.tr(context)
                : 'deepseek'.tr(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Icon(
                isOfflineMode 
                  ? Icons.dataset_outlined  // Mock/fallback icon for offline mode
                  : (isUsingBertChineseWwm ? Icons.computer : Icons.cloud),
                color: isOfflineMode ? Colors.amber : Colors.green,
              ),
            ),
          ),
        ],
      ),
      body: widget.currentPack == null || widget.currentPack!.cards.isEmpty
          ? Center(
              child: Text('no_cards_available'.tr(context)),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: _isPreloading
                ? _buildPreloadingIndicator()
                : (_isLoading 
                  ? _buildLoadingIndicator()
                  : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Отладочная информация - показываем только если включен режим отладки
                        if (!isDebugMode) Container(
                          padding: EdgeInsets.all(8),
                          margin: EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.yellow[100],
                            border: Border.all(color: Colors.amber),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${('correct_answer').tr(context)}: $hiddenWord",
                                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              if (currentFlashcard != null) Text(
                                "SRS Level: ${currentFlashcard!.repetitionLevel}, Next review: ${currentFlashcard!.nextReviewDate?.toString().substring(0, 10) ?? 'New'}",
                                style: TextStyle(color: Colors.black54, fontSize: 12),
                              ),
                            ],
                          )
                        ),
                        
                        // Статус сервера при ошибке
                        if (_hasError)
                          Container(
                            padding: EdgeInsets.all(8),
                            margin: EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.red[100],
                              border: Border.all(color: Colors.red),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Server Error', 
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red[900]),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  _statusMessage,
                                  style: TextStyle(color: Colors.red[900], fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        
                        // Информация об источнике упражнения - показываем только если включен режим отладки
                        if (!isDebugMode) Container(
                          padding: EdgeInsets.all(8),
                          margin: EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            border: Border.all(color: Colors.green),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Источник упражнения:", 
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                                  ),
                                  if (_getExerciseTotalCount() > 1)
                                    OutlinedButton.icon(
                                      icon: Icon(Icons.navigate_next, size: 18),
                                      label: Text(
                                        "Следующий вариант",
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                        minimumSize: Size(30, 24),
                                        foregroundColor: Colors.green[700],
                                        side: BorderSide(color: Colors.green),
                                      ),
                                      onPressed: () => _generateExercise(nextExercise: true),
                                    ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Text(
                                _getExerciseSource(),
                                style: TextStyle(color: Colors.black87, fontSize: 12),
                              ),
                              if (!isDebugMode && _hasValidationData()) ...[
                                SizedBox(height: 8),
                                _buildValidationInfo(),
                              ],
                            ],
                          ),
                        ),
                        
                        // Предложение с пропуском
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                currentSentence ?? "",
                                style: TextStyle(fontSize: 24),
                                textAlign: TextAlign.center,
                              ),
                              if (_exerciseMetadata['pinyin'] != null && _exerciseMetadata['pinyin'].toString().isNotEmpty) ...[
                                SizedBox(height: 8),
                                Text(
                                  _exerciseMetadata['pinyin'].toString().replaceAll("____", "____"),
                                  style: TextStyle(fontSize: 14, color: Colors.grey[600], fontStyle: FontStyle.italic),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                              if (_exerciseMetadata['translation'] != null && _exerciseMetadata['translation'].toString().isNotEmpty) ...[
                                SizedBox(height: 8),
                                Text(
                                  _exerciseMetadata['translation'].toString(),
                                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        ),
                        
                        SizedBox(height: 24),
                        
                        // Варианты ответов
                        ...options.map((option) => Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: OptionButton(
                            text: option,
                            isSelected: selectedOption == option,
                            isCorrect: isChecked && option == hiddenWord,
                            isWrong: isChecked && selectedOption == option && option != hiddenWord,
                            onTap: () {
                              if (!isChecked) {
                                setState(() {
                                  selectedOption = option;
                                });
                              }
                            },
                          ),
                        )),
                        
                        SizedBox(height: 24),
                        
                        // Кнопки управления
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            if (!isChecked)
                              ElevatedButton(
                                onPressed: selectedOption.isEmpty ? null : _checkAnswer,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  disabledBackgroundColor: Theme.of(context).disabledColor,
                                  disabledForegroundColor: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                                ),
                                child: Text('check'.tr(context)),
                              )
                            else
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_getExerciseTotalCount() > 1)
                                    ElevatedButton.icon(
                                      onPressed: () => _generateExercise(nextExercise: true),
                                      icon: Icon(Icons.rotate_right),
                                      label: Text('Следующий вариант'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      ),
                                    ),
                                  SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _generateExercise,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(context).colorScheme.primary,
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    ),
                                    child: Text('next'.tr(context)),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  )
                ),
            ),
    );
  }
  
  Widget _buildPreloadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Предзагрузка упражнений...',
            style: TextStyle(fontSize: 18),
          ),
          SizedBox(height: 8),
          Text(
            'Пожалуйста, подождите',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_showProgress && _generationProgress > 0.0) ...[
            CircularProgressIndicator(value: _generationProgress),
            SizedBox(height: 16),
            Text(
              '${(_generationProgress * 100).toStringAsFixed(0)}%', 
              style: TextStyle(fontSize: 16)
            ),
            SizedBox(height: 8),
            Text('Генерация упражнения...'),
          ] else ...[
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Генерация упражнения...'),
          ],
          if (_hasError) ...[
            SizedBox(height: 24),
            Text(
              'Ошибка: $_statusMessage',
              style: TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ]
        ],
      ),
    );
  }
  
  Widget _buildServerInfo() {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final isOfflineMode = settingsProvider.offlineMode;
    
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            'Информация о запросе:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isOfflineMode ? Icons.offline_bolt : Icons.online_prediction, size: 16),
              SizedBox(width: 4),
              Text(
                isOfflineMode ? 'Режим: Офлайн' : 'Режим: Онлайн',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            'Используется BERT валидация: ${settingsProvider.exerciseService.toString().contains('bertChineseWwm') ? 'Да' : 'Нет'}',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _getExerciseSource() {
    final source = _exerciseMetadata['source'] ?? 'Неизвестно';
    final cacheTotal = _exerciseMetadata['cache_total'] ?? 1;
    
    if (cacheTotal > 1) {
      final cacheIndex = _exerciseMetadata['cache_index'] ?? 0;
      return '$source (вариант ${cacheIndex + 1} из $cacheTotal)';
    }
    
    return source;
  }
  
  int _getExerciseTotalCount() {
    return _exerciseMetadata['cache_total'] ?? 1;
  }
  
  Widget _buildValidationInfo() {
    if (!_hasValidationData()) {
      return SizedBox.shrink();
    }
    
    final validation = _exerciseMetadata['validation'] ?? {};
    final isValid = _isValidationPassed();
    final confidence = validation['confidence'] ?? 0.0;
    final semanticScore = validation['semantic_score'] ?? 0.0;
    final distractorScore = validation['distractor_score'] ?? 0.0;
    final note = validation['note'];
    
    // Выбираем цвет индикатора на основе уверенности
    Color confidenceColor = Colors.green;
    if (confidence < 0.6) {
      confidenceColor = Colors.red;
    } else if (confidence < 0.8) {
      confidenceColor = Colors.orange;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: Colors.green[300]),
        SizedBox(height: 4),
        Row(
          children: [
            Icon(
              isValid ? Icons.check_circle : Icons.warning,
              color: isValid ? Colors.green[800] : Colors.red[800],
              size: 16,
            ),
            SizedBox(width: 4),
            Text(
              "Валидация BERT: ${isValid ? 'Пройдена' : 'Не пройдена'}",
              style: TextStyle(
                color: isValid ? Colors.green[800] : Colors.red[800],
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Уверенность:",
              style: TextStyle(color: Colors.black87, fontSize: 12),
            ),
            Text(
              "${(confidence * 100).toStringAsFixed(1)}%",
              style: TextStyle(
                color: confidenceColor,
                fontSize: 12, 
                fontWeight: FontWeight.bold
              ),
            ),
          ],
        ),
        SizedBox(height: 2),
        LinearProgressIndicator(
          value: confidence,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(confidenceColor),
          minHeight: 4,
        ),
        SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Семантика: ${(semanticScore * 100).toStringAsFixed(1)}%",
                    style: TextStyle(color: Colors.black87, fontSize: 11),
                  ),
                  SizedBox(height: 2),
                  LinearProgressIndicator(
                    value: semanticScore,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      semanticScore > 0.6 ? Colors.green : Colors.orange),
                    minHeight: 3,
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Дистракторы: ${(distractorScore * 100).toStringAsFixed(1)}%",
                    style: TextStyle(color: Colors.black87, fontSize: 11),
                  ),
                  SizedBox(height: 2),
                  LinearProgressIndicator(
                    value: distractorScore,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      distractorScore > 0.5 ? Colors.green : Colors.orange),
                    minHeight: 3,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (note != null && note.toString().isNotEmpty) ...[
          SizedBox(height: 4),
          Text(
            note.toString(),
            style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey[700]),
          ),
        ],
      ],
    );
  }
  
  bool _hasValidationData() {
    return _exerciseMetadata['validation'] != null;
  }
  
  bool _isValidationPassed() {
    return _exerciseMetadata['validation']?['is_valid'] ?? false;
  }
}

class OptionButton extends StatelessWidget {
  final String text;
  final bool isSelected;
  final bool isCorrect;
  final bool isWrong;
  final VoidCallback onTap;

  const OptionButton({
    Key? key,
    required this.text,
    this.isSelected = false,
    this.isCorrect = false,
    this.isWrong = false,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Определение цвета фона кнопки
    Color backgroundColor;
    if (isCorrect) {
      backgroundColor = Colors.green.withOpacity(0.2);
    } else if (isWrong) {
      backgroundColor = Colors.red.withOpacity(0.2);
    } else if (isSelected) {
      backgroundColor = Theme.of(context).colorScheme.primaryContainer;
    } else {
      backgroundColor = Theme.of(context).cardColor;
    }
    
    // Определение цвета границы
    Color borderColor;
    if (isCorrect) {
      borderColor = Colors.green;
    } else if (isWrong) {
      borderColor = Colors.red;
    } else if (isSelected) {
      borderColor = Theme.of(context).colorScheme.primary;
    } else {
      borderColor = Colors.grey.withOpacity(0.3);
    }
    
    // Определение иконки (если нужна)
    Widget? trailingIcon;
    if (isCorrect) {
      trailingIcon = Icon(Icons.check_circle, color: Colors.green);
    } else if (isWrong) {
      trailingIcon = Icon(Icons.cancel, color: Colors.red);
    }
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: isSelected || isCorrect || isWrong ? 2 : 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: isSelected || isCorrect ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (trailingIcon != null) trailingIcon,
          ],
        ),
      ),
    );
  }
} 