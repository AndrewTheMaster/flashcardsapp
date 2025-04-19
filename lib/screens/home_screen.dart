import 'package:flutter/material.dart';
import '../widgets/flashcard_widget.dart';
import '../models/flashcard.dart';
import '../models/flashcard_pack.dart';
import '../screens/flashcard_editor_screen.dart';
import '../screens/flashcard_game_screen.dart';
import '../services/storage_service.dart';
import '../services/translation_service.dart';
import 'dart:async';
import 'fill_blanks_screen.dart';
import 'dart:developer' as developer;

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

  @override
  void initState() {
    super.initState();
    _loadFlashcardPacks();
  }

  Future<void> _loadFlashcardPacks() async {
    List<FlashcardPack> loadedPacks = await StorageService.loadFlashcardPacks();
    setState(() {
      flashcardPacks = loadedPacks;
    });
  }

  void _saveFlashcardPacks() async {
    await StorageService.saveFlashcardPacks(flashcardPacks);
  }

  void _deletePack(int index) {
    setState(() {
      flashcardPacks.removeAt(index);
      if (currentPackIndex >= flashcardPacks.length) {
        currentPackIndex = flashcardPacks.isEmpty ? 0 : flashcardPacks.length - 1;
      }
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
        final result = await TranslationService.translate(hanzi);
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
          title: Text('Создать новый пак'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(hintText: 'Введите название пака'),
              ),
              SizedBox(height: 10),
              TextField(
                controller: bulkCardsController,
                decoration: InputDecoration(
                  hintText: 'Введите иероглифы (по одному в строке)',
                ),
                maxLines: 5,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Отмена'),
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
              child: Text('Создать'),
            ),
          ],
        );
      },
    );

    if (newPackData != null) {
      setState(() {
        flashcardPacks.add(FlashcardPack(name: newPackData['name'], cards: newPackData['cards']));
        currentPackIndex = flashcardPacks.length - 1;
      });
      _saveFlashcardPacks();
    }
  }

  void _nextCard() {
    if (flashcardPacks.isEmpty || flashcardPacks[currentPackIndex].cards.isEmpty) return;
    setState(() {
      currentCardIndex = (currentCardIndex + 1) % flashcardPacks[currentPackIndex].cards.length;
      _isFlipped = false; // Сбрасываем состояние переворота
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Изучение китайского'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Меню',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.edit),
              title: Text('Заполнить пропуски'),
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
                      );
                    }
                  )
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.book),
              title: Text('Карточки'),
              onTap: () {
                Navigator.pop(context); // Просто закрываем боковое меню
              },
            ),
            ListTile(
              title: const Text('Редактировать карточки'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FlashcardEditorScreen(
                    onSave: (hanzi, pinyin, translation) {
                      setState(() {
                        flashcardPacks[currentPackIndex].cards.add(
                          Flashcard(hanzi: hanzi, pinyin: pinyin, translation: translation),
                        );
                      });
                      _saveFlashcardPacks();
                    },
                    onUpdate: (hanzi, pinyin, translation) {
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
                    },
                    existingCards: flashcardPacks[currentPackIndex].cards.map((card) => card.toJson()).toList(),
                  ),
                ),
              ),
            ),
            ListTile(
              title: const Text('Играть'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FlashcardGameScreen(flashcards: flashcardPacks[currentPackIndex].cards),
                ),
              ),
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
                  'Добро пожаловать в приложение для изучения китайского языка',
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
                  child: Text('Создать новый пак'),
                ),
              ],
            ),
          )
        : Column(
            children: [
              // Заголовок текущего пака
              Container(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
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
              
              // Список паков (отображается, если раскрыт)
              if (_packsExpanded)
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
                
              // Карточки
              Expanded(
                child: flashcardPacks[currentPackIndex].cards.isEmpty
                  ? Center(
                      child: Text('В этом паке нет карточек'),
                    )
                  : FlashcardWidget(
                      flashcard: flashcardPacks[currentPackIndex].cards[currentCardIndex],
                      isFlipped: _isFlipped,
                      onFlip: () {
                        setState(() {
                          _isFlipped = !_isFlipped;
                        });
                      },
                    ),
              ),
              
              // Кнопки управления
              Container(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _createNewPack,
                      child: Text('Новый пак'),
                    ),
                    ElevatedButton(
                      onPressed: flashcardPacks[currentPackIndex].cards.isEmpty ? null : _nextCard,
                      child: Text('Следующая'),
                    ),
                  ],
                ),
              ),
            ],
          ),
    );
  }
}