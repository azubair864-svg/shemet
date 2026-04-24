import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PartyRoomLeftSidebar extends StatelessWidget {
  final String roomId;

  const PartyRoomLeftSidebar({
    super.key,
    required this.roomId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('party_rooms')
            .doc(roomId)
            .collection('recent_gifts')
            .orderBy('timestamp', descending: true)
            .limit(3)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const SizedBox.shrink();
          }

          final recentGifts = snapshot.data!.docs;

          return ListView.builder(
            itemCount: recentGifts.length,
            itemBuilder: (context, index) {
              final gift = recentGifts[index].data() as Map<String, dynamic>;
              return _buildGifterItem(gift);
            },
          );
        },
      ),
    );
  }

  Widget _buildGifterItem(Map<String, dynamic> gift) {
    final senderName = gift['senderName'] ?? 'User';
    final senderAvatar = gift['senderAvatar'] ?? '';
    final giftEmoji = gift['giftEmoji'] ?? '🎁';
    final recipientName = gift['recipientName'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar with glow effect
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.pink.withValues(alpha: 0.5),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: Colors.purple.shade300,
              backgroundImage:
              senderAvatar.isNotEmpty ? NetworkImage(senderAvatar) : null,
              child: senderAvatar.isEmpty
                  ? const Icon(Icons.person, color: Colors.white, size: 24)
                  : null,
            ),
          ),

          const SizedBox(height: 4),

          // Name (truncated)
          Text(
            senderName.length > 8
                ? '${senderName.substring(0, 8)}...'
                : senderName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(
                  color: Colors.black54,
                  offset: Offset(1, 1),
                  blurRadius: 2,
                ),
              ],
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 2),

          // Gift emoji badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.pink.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.pink.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(giftEmoji, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 2),
                const Text(
                  '🎁',
                  style: TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),

          const SizedBox(height: 2),

          // "to" text
          if (recipientName.isNotEmpty)
            Text(
              'to',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 8,
              ),
            ),

          // Recipient (truncated)
          if (recipientName.isNotEmpty)
            Text(
              recipientName.length > 8
                  ? '${recipientName.substring(0, 6)}...'
                  : recipientName,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}