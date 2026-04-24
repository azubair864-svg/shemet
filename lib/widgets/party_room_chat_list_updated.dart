import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PartyRoomChatListUpdated extends StatelessWidget {
  final String roomId;
  final String currentUserId;
  final bool isVisible;
  final bool isHost;
  final VoidCallback? onReviewRequest;

  const PartyRoomChatListUpdated({
    super.key,
    required this.roomId,
    required this.currentUserId,
    this.isVisible = true,
    this.isHost = false,
    this.onReviewRequest,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 180,
      margin: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('party_rooms')
            .doc(roomId)
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .limit(20)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            );
          }

          final messages = snapshot.data!.docs;

          if (messages.isEmpty) {
            return Center(
              child: Text(
                'No messages yet',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            );
          }

          return ListView.builder(
            reverse: true,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final messageData = messages[index].data() as Map<String, dynamic>;
              final senderName = messageData['senderName'] ?? 'User';
              final text = messageData['text'] ?? '';
              final type = messageData['type'] ?? 'text';

              if (type == 'system' || type == 'seat_request') {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: type == 'seat_request' 
                          ? Colors.pink.withOpacity(0.15)
                          : Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: type == 'seat_request'
                          ? Border.all(color: Colors.pink.withOpacity(0.3), width: 0.5)
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Expanded(
                          child: Text(
                            text,
                            style: TextStyle(
                              color: type == 'seat_request' ? Colors.pinkAccent : Colors.white.withOpacity(0.8),
                              fontSize: 12,
                              fontWeight: type == 'seat_request' ? FontWeight.bold : FontWeight.normal,
                              fontStyle: type == 'system' ? FontStyle.italic : FontStyle.normal,
                            ),
                          ),
                        ),
                        if (type == 'seat_request' && isHost)
                          GestureDetector(
                            onTap: onReviewRequest,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Colors.pink, Colors.purple]),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const Text(
                                'Review',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$senderName: ',
                        style: const TextStyle(
                          color: Color(0xFFFF69B4),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      TextSpan(
                        text: text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}