import 'package:flutter/material.dart';
import '../services/database_service.dart';
import 'party_room_chat_message.dart';

class PartyRoomChatList extends StatefulWidget {
  final String roomId;
  final String currentUserId;
  final bool isVisible;

  const PartyRoomChatList({
    super.key,
    required this.roomId,
    required this.currentUserId,
    this.isVisible = true,
  });

  @override
  State<PartyRoomChatList> createState() => _PartyRoomChatListState();
}

class _PartyRoomChatListState extends State<PartyRoomChatList> {
  final ScrollController _scrollController = ScrollController();
  final DatabaseService _databaseService = DatabaseService();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 180,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.6),
            Colors.black.withOpacity(0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _databaseService.getPartyRoomMessages(widget.roomId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: Text(
                'Loading messages...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 11,
                ),
              ),
            );
          }

          final messages = snapshot.data!;

          if (messages.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    color: Colors.white.withOpacity(0.3),
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No messages yet',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Be the first to say something!',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            );
          }

          // Auto-scroll to bottom when new message arrives
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });

          // Reverse to show latest at bottom
          final reversedMessages = messages.reversed.toList();

          return ListView.builder(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            itemCount: reversedMessages.length,
            itemBuilder: (context, index) {
              final message = reversedMessages[index];
              return _buildMessageWidget(message);
            },
          );
        },
      ),
    );
  }

  Widget _buildMessageWidget(Map<String, dynamic> message) {
    final messageType = message['type'] ?? 'text';
    final senderId = message['senderId'] as String?;
    final senderName = message['senderName'] as String?;
    final senderPhoto = message['senderPhoto'] as String?;
    final senderLevel = message['senderLevel'] as int?;
    final text = message['text'] as String?;
    final giftName = message['giftName'] as String?;
    final giftValue = message['giftValue'] as int?;

    return PartyRoomChatMessage(
      messageType: messageType,
      senderName: senderName,
      senderPhoto: senderPhoto,
      senderLevel: senderLevel,
      messageText: text,
      giftName: giftName,
      giftValue: giftValue,
      isCurrentUser: senderId == widget.currentUserId,
    );
  }
}