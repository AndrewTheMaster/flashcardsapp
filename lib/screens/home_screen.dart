import 'package:flutter/material.dart';
import '../widgets/flashcard_widget.dart';
import '../models/flashcard.dart';
import '../models/flashcard_pack.dart';
import '../localization/app_localizations.dart';
import '../screens/flashcard_editor_screen.dart';
import '../screens/flashcard_game_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/srs_quiz_screen.dart';
import '../services/storage_service.dart';
import '../services/translation_service.dart';
import '../services/exercise_service_facade.dart';
import '../providers/settings_provider.dart';
import '../providers/cards_provider.dart';
import 'dart:async';
import 'fill_blanks_screen.dart';
import 'dart:developer' as developer;
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<FlashcardPack> flashcardPacks = [];
  int currentPackIndex = 0;
  int currentCardIndex = 0;
  bool _isFlipped = false;
  bool _packsExpanded = false;
  bool _showDueCardsOnly = false;
  List<Flashcard> _dueCards = [];
  bool _isLoadingExercises = false;
  late ExerciseServiceFacade _exerciseService;

  @override
  void initState() {
    super.initState();
    _loadFlashcardPacks();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _exerciseService = ExerciseServiceFacade(Provider.of<SettingsProvider>(context, listen: false));
  }

  Future<void> _loadFlashcardPacks() async {
    List<FlashcardPack> loadedPacks = await StorageService.loadFlashcardPacks();
    setState(() {
      flashcardPacks = loadedPacks;
      _updateDueCards();
    });
    
    // Sync with CardsProvider after loading packs
    _syncWithCardsProvider();
    
    // Закомментирован вызов предзагрузки упражнений на главном экране
    // Теперь предзагрузка будет происходить только при открытии FillBlanksScreen
    // _preloadExercises();
  }
  
  void _preloadExercises() async {
    // Проверяем, есть ли карточки для предзагрузки
    if (flashcardPacks.isEmpty) {
      return;
    }
    
    setState(() {
      _isLoadingExercises = true;
    });
    
    try {
      developer.log('HomeScreen: Начало предзагрузки упражнений', name: 'home_screen');
      
      // Собираем все карточки из всех паков
      List<Flashcard> allCards = [];
      for (var pack in flashcardPacks) {
        allCards.addAll(pack.cards);
      }
      
      // Предварительно загружаем упражнения для первых 20 карточек
      if (allCards.isNotEmpty) {
        final cardsToPreload = allCards.take(20).toList();
        await _exerciseService.prefetchExercises(cardsToPreload);
      }
      
      developer.log('HomeScreen: Предзагрузка упражнений завершена', name: 'home_screen');
    } catch (e) {
      developer.log('HomeScreen: Ошибка при предзагрузке упражнений: $e', name: 'home_screen');
    } finally {
      setState(() {
        _isLoadingExercises = false;
      });
    }
  }

  void _updateDueCards() {
    _dueCards = [];
    for (var pack in flashcardPacks) {
      for (var card in pack.cards) {
        if (card.needsReview) {
          _dueCards.add(card);
        }
      }
    }
    
    // Sort due cards by repetition level (lower levels first)
    _dueCards.sort((a, b) => a.repetitionLevel.compareTo(b.repetitionLevel));
  }

  void _saveFlashcardPacks() async {
    await StorageService.saveFlashcardPacks(flashcardPacks);
    _updateDueCards();
    
    // Sync with CardsProvider after saving packs
    _syncWithCardsProvider();
  }

  void _deletePack(int index) {
    setState(() {
      flashcardPacks.removeAt(index);
      if (currentPackIndex >= flashcardPacks.length) {
        currentPackIndex = flashcardPacks.isEmpty ? 0 : flashcardPacks.length - 1;
      }
      _updateDueCards();
    });
    _saveFlashcardPacks();
  }

  void _switchPack(int index) {
    setState(() {
      currentPackIndex = index;
      currentCardIndex = 0;
      _isFlipped = false;
    });
  }

  Future<List<Flashcard>> _fetchBulkTranslations(List<String> hanziList) async {
    List<Flashcard> flashcards = [];
    for (var hanzi in hanziList) {
      try {
        final result = await TranslationService.translateStatic(hanzi);
        flashcards.add(Flashcard(
          hanzi: hanzi.trim(),
          pinyin: result['pinyin'] ?? '',
          translation: result['translation'] ?? '',
        ));
      } catch (e) {
        flashcards.add(Flashcard(
          hanzi: hanzi.trim(),
          pinyin: '',
          translation: 'Ошибка перевода',
        ));
      }
    }
    return flashcards;
  }

  void _createNewPack() async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController bulkCardsController = TextEditingController();

    final newPackData = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('create_new_pack'.tr(context)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(hintText: 'enter_pack_name'.tr(context)),
              ),
              SizedBox(height: 10),
              TextField(
                controller: bulkCardsController,
                decoration: InputDecoration(
                  hintText: 'enter_characters'.tr(context),
                ),
                maxLines: 5,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('cancel'.tr(context)),
            ),
            TextButton(
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty) {
                  List<String> hanziList = bulkCardsController.text.trim().split('\n');
                  List<Flashcard> newCards = await _fetchBulkTranslations(hanziList);
                  Navigator.pop(context, {
                    'name': nameController.text.trim(),
                    'cards': newCards,
                  });
                }
              },
              child: Text('create'.tr(context)),
            ),
          ],
        );
      },
    );

    if (newPackData != null) {
      setState(() {
        flashcardPacks.add(FlashcardPack(name: newPackData['name'], cards: newPackData['cards']));
        currentPackIndex = flashcardPacks.length - 1;
        _updateDueCards();
      });
      _saveFlashcardPacks();
    }
  }

  void _nextCard() {
    if (_showDueCardsOnly) {
      // When showing only due cards
      if (_dueCards.isEmpty) return;
      
      // Move to next due card
      setState(() {
        currentCardIndex = (currentCardIndex + 1) % _dueCards.length;
        _isFlipped = false;
      });
    } else {
      // When showing all cards in current pack
      if (flashcardPacks.isEmpty || flashcardPacks[currentPackIndex].cards.isEmpty) return;
      setState(() {
        currentCardIndex = (currentCardIndex + 1) % flashcardPacks[currentPackIndex].cards.length;
        _isFlipped = false;
      });
    }
  }

  void _markCardReviewed(bool wasCorrect) {
    if (_showDueCardsOnly && _dueCards.isNotEmpty) {
      // Update the current due card
      Flashcard card = _dueCards[currentCardIndex];
      card.updateNextReviewDate(wasCorrect: wasCorrect);
      _saveFlashcardPacks();
      
      // If there are no more cards after update, switch to normal view
      setState(() {
        _updateDueCards();
        if (_dueCards.isEmpty) {
          _showDueCardsOnly = false;
        } else if (currentCardIndex >= _dueCards.length) {
          currentCardIndex = 0;
        }
        _isFlipped = false;
      });
    } else if (!_showDueCardsOnly && flashcardPacks.isNotEmpty && flashcardPacks[currentPackIndex].cards.isNotEmpty) {
      // Update current card in normal view
      Flashcard card = flashcardPacks[currentPackIndex].cards[currentCardIndex];
      card.updateNextReviewDate(wasCorrect: wasCorrect);
      _saveFlashcardPacks();
      _nextCard();
    }
  }

  // Add a method to sync flashcard packs with the CardsProvider
  void _syncWithCardsProvider() {
    final cardsProvider = Provider.of<CardsProvider>(context, listen: false);
    cardsProvider.allPacks = flashcardPacks;
    cardsProvider.loadDueCards();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Determine which card to show based on view mode
    Flashcard? currentCard;
    if (_showDueCardsOnly) {
      currentCard = _dueCards.isNotEmpty ? _dueCards[currentCardIndex] : null;
    } else {
      currentCard = flashcardPacks.isNotEmpty && flashcardPacks[currentPackIndex].cards.isNotEmpty 
          ? flashcardPacks[currentPackIndex].cards[currentCardIndex] 
          : null;
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text('app_title'.tr(context)),
        actions: [
          // Show badge with number of due cards
          _dueCards.isNotEmpty 
              ? Badge(
                  label: Text(_dueCards.length.toString()),
                  child: IconButton(
                    icon: Icon(Icons.notifications),
                    onPressed: () {
                      setState(() {
                        _showDueCardsOnly = !_showDueCardsOnly;
                        currentCardIndex = 0;
                        _isFlipped = false;
                      });
                    },
                  ),
                )
              : SizedBox.shrink(),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
              child: Text(
                'app_title'.tr(context),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.edit),
              title: Text('exercises'.tr(context)),
              onTap: () {
                developer.log('HomeScreen: Нажатие на пункт "Заполнить пропуски"', name: 'home_screen');
                
                Navigator.pop(context); // Закрываем drawer
                Navigator.push(
                  context, 
                  MaterialPageRoute(
                    builder: (context) {
                      final currentPack = flashcardPacks.isNotEmpty ? flashcardPacks[currentPackIndex] : null;
                      developer.log('HomeScreen: Открытие FillBlanksScreen с паком: ${currentPack?.name ?? "null"}', 
                          name: 'home_screen');
                      
                      return FillBlanksScreen(
                        currentPack: currentPack,
                        isDarkMode: isDark,
                      );
                    }
                  )
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.book),
              title: Text('flashcards'.tr(context)),
              onTap: () {
                Navigator.pop(context); // Просто закрываем боковое меню
              },
            ),
            ListTile(
              leading: Icon(Icons.edit_note),
              title: Text('edit_cards'.tr(context)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FlashcardEditorScreen(
                      onSave: (hanzi, pinyin, translation) {
                        if (flashcardPacks.isNotEmpty) {
                          setState(() {
                            flashcardPacks[currentPackIndex].cards.add(
                              Flashcard(hanzi: hanzi, pinyin: pinyin, translation: translation),
                            );
                          });
                          _saveFlashcardPacks();
                        }
                      },
                      onUpdate: (hanzi, pinyin, translation) {
                        if (flashcardPacks.isNotEmpty) {
                          final index = flashcardPacks[currentPackIndex].cards.indexWhere((card) => card.hanzi == hanzi);
                          if (index != -1) {
                            setState(() {
                              flashcardPacks[currentPackIndex].cards[index] = Flashcard(
                                hanzi: hanzi,
                                pinyin: pinyin,
                                translation: translation,
                              );
                            });
                            _saveFlashcardPacks();
                          }
                        }
                      },
                      existingCards: flashcardPacks.isNotEmpty 
                          ? flashcardPacks[currentPackIndex].cards.map((card) => card.toJson()).toList()
                          : [],
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.quiz),
              title: Text('srs_quiz'.tr(context)),
              onTap: () {
                Navigator.pop(context);
                // Initialize the cards provider before navigating to the screen
                final cardsProvider = Provider.of<CardsProvider>(context, listen: false);
                cardsProvider.allPacks = flashcardPacks;
                cardsProvider.loadDueCards();
                
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SrsQuizScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.games),
              title: Text('memory_game'.tr(context)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FlashcardGameScreen(flashcards: flashcardPacks.isNotEmpty 
                      ? flashcardPacks[currentPackIndex].cards
                      : []),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('settings'.tr(context)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SettingsScreen()),
                );
              },
            ),
          ],
        ),
      ),
      body: flashcardPacks.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  'welcome_message'.tr(context),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
                SizedBox(height: 20),
                Text(
                  '欢迎使用中文学习应用程序',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _createNewPack,
                  child: Text('create_new_pack'.tr(context)),
                ),
              ],
            ),
          )
        : Column(
            children: [
              // Title of current view
              Container(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _showDueCardsOnly
                        ? Text(
                            '${('cards_to_review').tr(context)} ${currentCardIndex + 1}/${_dueCards.length}',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          )
                        : Text(
                            '${currentPackIndex + 1}/${flashcardPacks.length}: ${flashcardPacks[currentPackIndex].name}',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                    IconButton(
                      icon: Icon(_packsExpanded ? Icons.arrow_drop_up : Icons.arrow_drop_down),
                      onPressed: () {
                        setState(() {
                          _packsExpanded = !_packsExpanded;
                        });
                      },
                    ),
                  ],
                ),
              ),
              
              // List of packs (shown if expanded)
              if (_packsExpanded && !_showDueCardsOnly)
                Container(
                  height: 200,
                  child: ListView.builder(
                    itemCount: flashcardPacks.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(flashcardPacks[index].name),
                        selected: index == currentPackIndex,
                        onTap: () => _switchPack(index),
                        trailing: IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () => _deletePack(index),
                        ),
                      );
                    },
                  ),
                ),
                
              // Flashcard
              Expanded(
                child: (_showDueCardsOnly && _dueCards.isEmpty) || 
                       (!_showDueCardsOnly && flashcardPacks[currentPackIndex].cards.isEmpty)
                  ? Center(
                      child: Text(_showDueCardsOnly 
                        ? 'No cards to review!' 
                        : 'no_cards_in_pack'.tr(context)),
                    )
                  : currentCard != null 
                    ? FlashcardWidget(
                        flashcard: currentCard,
                        isFlipped: _isFlipped,
                        onFlip: () {
                          setState(() {
                            _isFlipped = !_isFlipped;
                          });
                        },
                      )
                    : Center(
                        child: Text('No card to display'),
                      ),
              ),
              
              // SRS info for current card
              if (currentCard != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'SRS Level: ${currentCard.repetitionLevel}/5, Next review: ${currentCard.nextReviewDate?.toString().substring(0, 10) ?? 'New'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              
              // Control buttons
              Container(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (_isFlipped && currentCard != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: () => _markCardReviewed(false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? Colors.red : Colors.red.shade200,
                              foregroundColor: isDark ? Colors.white : Colors.red.shade900,
                            ),
                            child: Text('again_button'.tr(context)),
                          ),
                          ElevatedButton(
                            onPressed: () => _markCardReviewed(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? Colors.green : Colors.green.shade200,
                              foregroundColor: isDark ? Colors.white : Colors.green.shade900,
                            ),
                            child: Text('good_button'.tr(context)),
                          ),
                        ],
                      ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (!_showDueCardsOnly)
                          ElevatedButton(
                            onPressed: _createNewPack,
                            child: Text('new_pack'.tr(context)),
                          ),
                        ElevatedButton(
                          onPressed: (_showDueCardsOnly && _dueCards.isEmpty) || 
                                     (!_showDueCardsOnly && (flashcardPacks.isEmpty || flashcardPacks[currentPackIndex].cards.isEmpty)) 
                              ? null 
                              : _nextCard,
                          child: Text('next_card'.tr(context)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
    );
  }
}