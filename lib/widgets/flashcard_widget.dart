import 'package:flutter/material.dart';

class FlashcardWidget extends StatefulWidget {
  final String frontText;
  final String backText;

  const FlashcardWidget({required this.frontText, required this.backText, Key? key}) : super(key: key);

  @override
  _FlashcardWidgetState createState() => _FlashcardWidgetState();
}

class _FlashcardWidgetState extends State<FlashcardWidget> {
  bool _isFlipped = false;

  void _flipCard() {
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flipCard,
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: 500),
        transitionBuilder: (widget, animation) {
          final rotateAnim = Tween(begin: 0.0, end: 1.0).animate(animation);
          return AnimatedBuilder(
            animation: rotateAnim,
            builder: (context, child) {
              final angle = rotateAnim.value * 3.141592653589793;
              return Transform(
                transform: Matrix4.rotationY(angle),
                alignment: Alignment.center,
                child: widget,
              );
            },
          );
        },
        child: _isFlipped
            ? _buildCard(widget.backText, Colors.blueAccent)
            : _buildCard(widget.frontText, Colors.orangeAccent),
      ),
    );
  }

  Widget _buildCard(String text, Color color) {
    return Container(
      key: ValueKey(text),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      padding: EdgeInsets.all(16),
      child: Text(text, style: TextStyle(fontSize: 20, color: Colors.white)),
    );
  }
}
