import 'package:flutter/material.dart';

class MessageReactionPicker extends StatelessWidget {
  final Function(String emoji) onReactionSelected;

  const MessageReactionPicker({
    super.key,
    required this.onReactionSelected,
  });

  static final List<String> _reactions = [
    '❤️', '😂', '😮', '😢', '😡', '👍', '👎', '🔥',
  ];

  static void show({
    required BuildContext context,
    required Function(String emoji) onReactionSelected,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => MessageReactionPicker(
        onReactionSelected: (emoji) {
          Navigator.pop(context);
          onReactionSelected(emoji);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned(
              bottom: 100,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: _reactions
                        .map((emoji) => _buildReactionButton(emoji))
                        .toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReactionButton(String emoji) {
    return GestureDetector(
      onTap: () => onReactionSelected(emoji),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            emoji,
            style: const TextStyle(fontSize: 28),
          ),
        ),
      ),
    );
  }
}