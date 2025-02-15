import 'package:flutter/material.dart';
import '../widgets/flashcard_widget.dart';
import '../models/flashcard.dart';
import '../models/flashcard_pack.dart';
import '../screens/flashcard_editor_screen.dart';
import '../screens/flashcard_game_screen.dart';
import '../services/storage_service.dart';
import '../services/translation_service.dart';
import '../screens/sentence_completion_screen.dart';
import 'dart:async';

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
    final currentPack = flashcardPacks.isNotEmpty ? flashcardPacks[currentPackIndex] : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(currentPack != null ? currentPack.name : 'Chinese Flashcards'),
      ),
      body: Center(
        child: currentPack != null && currentPack.cards.isNotEmpty
            ? FlashcardWidget(
          flashcard: currentPack.cards[currentCardIndex],
          isFlipped: _isFlipped,
          onFlip: () {
            setState(() {
              _isFlipped = !_isFlipped;
            });
            // После переворота ждем 2 секунды и переключаем на следующую карточку
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                _nextCard();
              }
            });
          },
        )
            : const Text('Добавьте карточки в редакторе'),
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            ListTile(
              title: Text('Паки карточек'),
              trailing: IconButton(
                icon: Icon(_packsExpanded ? Icons.expand_less : Icons.expand_more),
                onPressed: () {
                  setState(() {
                    _packsExpanded = !_packsExpanded;
                  });
                },
              ),
            ),
            if (_packsExpanded)
              ...flashcardPacks.asMap().entries.map((entry) {
                final index = entry.key;
                final pack = entry.value;
                return ListTile(
                  title: Text(pack.name),
                  selected: index == currentPackIndex,
                  onTap: () => _switchPack(index),
                  trailing: IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => _deletePack(index),
                  ),
                );
              }).toList(),
            const Divider(),
            ListTile(
              title: const Text('Создать новый пак'),
              onTap: _createNewPack,
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
                  builder: (context) => FlashcardGameScreen(flashcards: currentPack?.cards ?? []),
                ),
              ),
            ),
            ListTile(
              title: const Text('Заполни пропуски'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SentenceCompletionScreen(flashcards: currentPack?.cards ?? []),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}