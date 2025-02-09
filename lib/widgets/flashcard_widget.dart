import 'package:flutter/material.dart';
import '../models/flashcard.dart';

class FlashcardWidget extends StatefulWidget {
  final Flashcard flashcard;
  final bool isFlipped;

  const FlashcardWidget({
    required this.flashcard,
    required this.isFlipped,
    Key? key,
  }) : super(key: key);

  @override
  _FlashcardWidgetState createState() => _FlashcardWidgetState();
}

class _FlashcardWidgetState extends State<FlashcardWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFlipped = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
    _isFlipped = widget.isFlipped;
    if (_isFlipped) {
      _controller.value = 1.0; // Если карточка должна быть перевернута, устанавливаем анимацию в конечное состояние
    }
  }

  @override
  void didUpdateWidget(FlashcardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFlipped != oldWidget.isFlipped) {
      _isFlipped = widget.isFlipped;
      if (_isFlipped) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  void _flipCard() {
    if (_isFlipped) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flipCard,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // Добавляем перспективу
              ..rotateY(_animation.value * 3.141592653589793), // Поворачиваем по оси Y
            alignment: Alignment.center,
            child: _isFlipped ? _buildBackCard() : _buildFrontCard(),
          );
        },
      ),
    );
  }

  Widget _buildFrontCard() {
    return Container(
      key: const ValueKey('front'),
      decoration: BoxDecoration(
        color: Colors.orangeAccent,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.flashcard.hanzi,
              style: const TextStyle(fontSize: 40, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              widget.flashcard.pinyin,
              style: const TextStyle(fontSize: 20, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackCard() {
    return Transform(
      transform: Matrix4.identity()
        ..rotateY(3.141592653589793), // Поворачиваем текст обратно на 180 градусов
      alignment: Alignment.center,
      child: Container(
        key: const ValueKey('back'),
        decoration: BoxDecoration(
          color: Colors.blueAccent,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            widget.flashcard.translation,
            style: const TextStyle(fontSize: 20, color: Colors.white),
          ),
        ),
      ),
    );
  }
}