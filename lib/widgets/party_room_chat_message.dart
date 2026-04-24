import 'package:flutter/material.dart';

class PartyRoomChatMessage extends StatelessWidget {
  final String messageType; // 'text', 'join', 'leave', 'gift', 'system'
  final String? senderName;
  final String? senderPhoto;
  final int? senderLevel;
  final String? messageText;
  final String? giftName;
  final int? giftValue;
  final bool isCurrentUser;

  const PartyRoomChatMessage({
    super.key,
    required this.messageType,
    this.senderName,
    this.senderPhoto,
    this.senderLevel,
    this.messageText,
    this.giftName,
    this.giftValue,
    this.isCurrentUser = false,
  });

  @override
  Widget build(BuildContext context) {
    switch (messageType) {
      case 'gift':
        return _buildGiftMessage();
      case 'join':
        return _buildJoinMessage();
      case 'leave':
        return _buildLeaveMessage();
      case 'system':
        return _buildSystemMessage();
      default:
        return _buildTextMessage();
    }
  }

  Widget _buildTextMessage() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User avatar (small)
          if (senderPhoto != null)
            Container(
              margin: const EdgeInsets.only(right: 6),
              child: CircleAvatar(
                radius: 12,
                backgroundColor: Colors.purple.shade300,
                backgroundImage: senderPhoto!.isNotEmpty
                    ? NetworkImage(senderPhoto!)
                    : null,
                child: senderPhoto!.isEmpty
                    ? const Icon(Icons.person, size: 12, color: Colors.white)
                    : null,
              ),
            ),

          // Message content
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  // Level badge
                  if (senderLevel != null)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF9B6FD7), Color(0xFFFF69B4)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Lv$senderLevel',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  // Username
                  TextSpan(
                    text: '$senderName ',
                    style: TextStyle(
                      color: isCurrentUser
                          ? const Color(0xFFFFD700)
                          : const Color(0xFF9B6FD7),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      shadows: const [
                        Shadow(
                          color: Colors.black45,
                          offset: Offset(0.5, 0.5),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),

                  // Message text
                  TextSpan(
                    text: messageText ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      shadows: [
                        Shadow(
                          color: Colors.black45,
                          offset: Offset(0.5, 0.5),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftMessage() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.pink.withOpacity(0.3),
            Colors.purple.withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.pink.withOpacity(0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withOpacity(0.3),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        children: [
          // User avatar
          if (senderPhoto != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: Colors.purple.shade300,
                backgroundImage: senderPhoto!.isNotEmpty
                    ? NetworkImage(senderPhoto!)
                    : null,
                child: senderPhoto!.isEmpty
                    ? const Icon(Icons.person, size: 14, color: Colors.white)
                    : null,
              ),
            ),

          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  // Level badge
                  if (senderLevel != null)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.pink,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Lv$senderLevel',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  // Username
                  TextSpan(
                    text: '$senderName ',
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),

                  // Gift text
                  const TextSpan(
                    text: 'sent ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),

                  // Gift name and value
                  TextSpan(
                    text: '$giftName',
                    style: const TextStyle(
                      color: Color(0xFFFF69B4),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),

                  if (giftValue != null)
                    TextSpan(
                      text: ' 💎$giftValue',
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Gift icon
          const Text('🎁', style: TextStyle(fontSize: 20)),
        ],
      ),
    );
  }

  Widget _buildJoinMessage() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // User avatar
          if (senderPhoto != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: CircleAvatar(
                radius: 12,
                backgroundColor: Colors.purple.shade300,
                backgroundImage: senderPhoto!.isNotEmpty
                    ? NetworkImage(senderPhoto!)
                    : null,
                child: senderPhoto!.isEmpty
                    ? const Icon(Icons.person, size: 12, color: Colors.white)
                    : null,
              ),
            ),

          // Level badge
          if (senderLevel != null)
            Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Lv$senderLevel',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: senderName ?? 'Someone',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  const TextSpan(
                    text: ' joined the room',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveMessage() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Text(
              '${senderName ?? 'Someone'} left the room',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemMessage() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.4), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.orange, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              messageText ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}