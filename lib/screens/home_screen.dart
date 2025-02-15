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
  List<FlashcardPack> flashcardPacks = []; // Список паков карточек
  int currentPackIndex = 0; // Индекс текущего пака
  int currentCardIndex = 0; // Индекс текущей карточки
  bool _isFlipped = false;

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

  void _nextCard() {
    if (flashcardPacks.isEmpty || flashcardPacks[currentPackIndex].cards.isEmpty) return;
    setState(() {
      currentCardIndex = (currentCardIndex + 1) % flashcardPacks[currentPackIndex].cards.length;
      _isFlipped = false; // Сбрасываем состояние переворота
    });
  }

  void _onCardFlipped() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isFlipped = false; // Возвращаем карточку в исходное состояние
        });
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _nextCard(); // Переходим к следующей карточке
          }
        });
      }
    });
  }

  void _editFlashcards() async {
    final updatedFlashcards = await Navigator.push(
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
    );

    if (updatedFlashcards != null) {
      setState(() {
        flashcardPacks[currentPackIndex].cards = updatedFlashcards;
      });
      _saveFlashcardPacks();
    }
  }

  void _switchPack(int index) {
    setState(() {
      currentPackIndex = index;
      currentCardIndex = 0; // Сбрасываем индекс карточки при переключении пака
      _isFlipped = false; // Сбрасываем состояние переворота
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
        currentPackIndex = flashcardPacks.length - 1; // Переключаемся на новый пак
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
          onFlip: _onCardFlipped,
        )
            : const Text('Добавьте карточки в редакторе'),
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            // Пункт меню для переключения между паками
            ...flashcardPacks.asMap().entries.map((entry) {
              final index = entry.key;
              final pack = entry.value;
              return ListTile(
                title: Text(pack.name),
                selected: index == currentPackIndex,
                onTap: () => _switchPack(index),
              );
            }).toList(),
            const Divider(),
            ListTile(
              title: const Text('Создать новый пак'),
              onTap: _createNewPack,
            ),
            ListTile(
              title: const Text('Редактировать карточки'),
              onTap: _editFlashcards,
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