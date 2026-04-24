import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MessageOptionsMenu extends StatelessWidget {
  final String messageId;
  final String messageText;
  final bool isMe;
  final VoidCallback? onReply;
  final VoidCallback? onForward;
  final VoidCallback? onDelete;
  final VoidCallback? onReact;

  const MessageOptionsMenu({
    super.key,
    required this.messageId,
    required this.messageText,
    this.isMe = false,
    this.onReply,
    this.onForward,
    this.onDelete,
    this.onReact,
  });

  static void show({
    required BuildContext context,
    required String messageId,
    required String messageText,
    bool isMe = false,
    VoidCallback? onReply,
    VoidCallback? onForward,
    VoidCallback? onDelete,
    VoidCallback? onReact,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => MessageOptionsMenu(
        messageId: messageId,
        messageText: messageText,
        isMe: isMe,
        onReply: onReply,
        onForward: onForward,
        onDelete: onDelete,
        onReact: onReact,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // React
            ListTile(
              leading: const Icon(Icons.add_reaction_outlined, color: Colors.orange),
              title: const Text('React'),
              onTap: () {
                Navigator.pop(context);
                onReact?.call();
              },
            ),

            // Reply
            ListTile(
              leading: const Icon(Icons.reply, color: Colors.blue),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                onReply?.call();
              },
            ),

            // Forward
            ListTile(
              leading: const Icon(Icons.forward, color: Colors.green),
              title: const Text('Forward'),
              onTap: () {
                Navigator.pop(context);
                onForward?.call();
              },
            ),

            // Copy
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.grey),
              title: const Text('Copy Text'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: messageText));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Text copied')),
                );
              },
            ),

            // Delete (only for own messages)
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete'),
                onTap: () {
                  Navigator.pop(context);
                  onDelete?.call();
                },
              ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}