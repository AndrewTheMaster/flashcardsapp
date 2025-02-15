import 'package:flutter/material.dart';
import '../widgets/flashcard_widget.dart';
import '../models/flashcard.dart';
import '../models/flashcard_pack.dart';
import '../screens/flashcard_editor_screen.dart';
import '../screens/flashcard_game_screen.dart';
import '../services/storage_service.dart';
import '../screens/sentence_completion_screen.dart';

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

  void _createNewPack() async {
    final newPackName = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text('Создать новый пак'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: 'Введите название пака'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.pop(context, controller.text.trim());
                }
              },
              child: Text('Создать'),
            ),
          ],
        );
      },
    );

    if (newPackName != null) {
      setState(() {
        flashcardPacks.add(FlashcardPack(name: newPackName, cards: []));
        currentPackIndex = flashcardPacks.length - 1;
      });
      _saveFlashcardPacks();
    }
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
