import 'package:flutter/material.dart';

class PartyRoomChatMessageRich extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isCurrentUser;

  const PartyRoomChatMessageRich({
    super.key,
    required this.message,
    this.isCurrentUser = false,
  });

  @override
  Widget build(BuildContext context) {
    final messageType = message['type'] ?? 'text';
    final senderName = message['senderName'] ?? 'User';
    final senderLevel = message['senderLevel'] ?? 1;
    final text = message['text'] ?? '';

    // Gift message format
    if (messageType == 'gift') {
      return _buildGiftMessage(
        senderName: senderName,
        senderLevel: senderLevel,
        giftName: message['giftName'] ?? 'Gift',
        giftQuantity: message['giftQuantity'] ?? 1,
        recipientName: message['recipientName'] ?? 'User',
      );
    }

    // Regular text message
    return _buildTextMessage(
      senderName: senderName,
      senderLevel: senderLevel,
      text: text,
    );
  }

  Widget _buildGiftMessage({
    required String senderName,
    required int senderLevel,
    required String giftName,
    required int giftQuantity,
    required String recipientName,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 12,
            height: 1.4,
          ),
          children: [
            // Level badge
            WidgetSpan(
              child: _buildLevelBadge(senderLevel),
              alignment: PlaceholderAlignment.middle,
            ),
            const WidgetSpan(
              child: SizedBox(width: 4),
            ),

            // Sender name
            TextSpan(
              text: senderName,
              style: TextStyle(
                color: _getLevelColor(senderLevel),
                fontWeight: FontWeight.bold,
                shadows: const [
                  Shadow(
                    color: Colors.black54,
                    offset: Offset(1, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),

            // "sent"
            TextSpan(
              text: ' sent ',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),

            // Gift quantity and name
            TextSpan(
              text: '$giftQuantity $giftName',
              style: const TextStyle(
                color: Color(0xFFFFD700),
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Colors.black54,
                    offset: Offset(1, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),

            // "to"
            TextSpan(
              text: ' to ',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),

            // Recipient name
            TextSpan(
              text: recipientName,
              style: const TextStyle(
                color: Colors.lightBlueAccent,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Colors.black54,
                    offset: Offset(1, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),

            // Emoji decoration
            const TextSpan(
              text: ' ✨',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextMessage({
    required String senderName,
    required int senderLevel,
    required String text,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 12,
            height: 1.3,
          ),
          children: [
            // Level badge
            WidgetSpan(
              child: _buildLevelBadge(senderLevel),
              alignment: PlaceholderAlignment.middle,
            ),
            const WidgetSpan(
              child: SizedBox(width: 4),
            ),

            // Sender name
            TextSpan(
              text: '$senderName: ',
              style: TextStyle(
                color: _getLevelColor(senderLevel),
                fontWeight: FontWeight.bold,
                shadows: const [
                  Shadow(
                    color: Colors.black54,
                    offset: Offset(1, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),

            // Message text
            TextSpan(
              text: text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelBadge(int level) {
    final isVip = level >= 10;
    final icon = isVip ? '👑' : '🔴';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isVip
              ? [const Color(0xFFFFD700), const Color(0xFFFFA500)]
              : [const Color(0xFFFF69B4), const Color(0xFFFF1493)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            icon,
            style: const TextStyle(fontSize: 10),
          ),
          const SizedBox(width: 2),
          Text(
            'Lv$level',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getLevelColor(int level) {
    if (level >= 20) return const Color(0xFFFF00FF); // Magenta
    if (level >= 15) return const Color(0xFFFFD700); // Gold
    if (level >= 10) return const Color(0xFF00FFFF); // Cyan
    if (level >= 5) return const Color(0xFF00FF00); // Green
    return const Color(0xFFFFFFFF); // White
  }
}