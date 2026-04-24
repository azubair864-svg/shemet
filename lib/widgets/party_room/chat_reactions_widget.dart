import 'package:flutter/material.dart';

class ChatReactionsWidget extends StatelessWidget {
  final String messageId;
  final Map<String, int> reactions;
  final Function(String) onReact;

  const ChatReactionsWidget({
    super.key,
    required this.messageId,
    required this.reactions,
    required this.onReact,
  });

  @override
  Widget build(BuildContext context) {
    final availableReactions = ['❤️', '👍', '😂', '😮', '🔥'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Wrap(
        spacing: 6,
        children: [
          ...reactions.entries.map((entry) {
            return _buildReactionChip(entry.key, entry.value, true);
          }),
          GestureDetector(
            onTap: () => _showReactionPicker(context, availableReactions),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('➕', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactionChip(String emoji, int count, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? Colors.pink.withOpacity(0.2) : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? Colors.pink : Colors.white.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10)),
        ],
      ),
    );
  }

  void _showReactionPicker(BuildContext context, List<String> reactions) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        content: Wrap(
          spacing: 12,
          children: reactions.map((emoji) {
            return GestureDetector(
              onTap: () {
                onReact(emoji);
                Navigator.pop(context);
              },
              child: Text(emoji, style: const TextStyle(fontSize: 32)),
            );
          }).toList(),
        ),
      ),
    );
  }
}