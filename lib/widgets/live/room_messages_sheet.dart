import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/database_service.dart';
import '../../models/user_model.dart';
import '../../core/constants/app_colors.dart';

class RoomMessagesSheet extends StatefulWidget {
  const RoomMessagesSheet({super.key});

  @override
  State<RoomMessagesSheet> createState() => _RoomMessagesSheetState();
}

class _RoomMessagesSheetState extends State<RoomMessagesSheet> {
  final DatabaseService _databaseService = DatabaseService();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Stack(
            children: [
              // 1. Glass Background
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF1A1033).withOpacity(0.95), // Deep Purple
                          const Color(0xFF000000).withOpacity(0.98),
                        ],
                      ),
                      border: Border(
                        top: BorderSide(color: Colors.white.withOpacity(0.1), width: 0.5),
                      ),
                    ),
                  ),
                ),
              ),

              // 2. Content
              Column(
                children: [
                  // Handle Bar
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Text(
                          'Messages',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        // Mark all read button (Optional, static for now)
                         Icon(Icons.done_all, color: Colors.white.withOpacity(0.5), size: 20),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white10, height: 1),

                  // Chat List
                  Expanded(
                    child: StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _databaseService.getUserChats(_currentUserId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white70)),
                          );
                        }

                        final chats = snapshot.data ?? [];

                        if (chats.isEmpty) {
                          return _buildEmptyState();
                        }

                        return ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: chats.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final chat = chats[index];
                            return _buildChatTile(chat);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.message_outlined, size: 48, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildChatTile(Map<String, dynamic> chat) {
    final chatId = chat['chatId'] as String;
    final participants = List<String>.from(chat['participants'] ?? []);
    final otherUserId = participants.firstWhere((id) => id != _currentUserId, orElse: () => '');
    if (otherUserId.isEmpty) return const SizedBox.shrink();

    final lastMessage = chat['lastMessage'] as String?;
    final lastMessageAt = chat['lastMessageAt'];
    final unreadCount = (chat['unreadCount'] as Map<String, dynamic>?)?[_currentUserId] ?? 0;

    return FutureBuilder<UserModel?>(
      future: _databaseService.getUserById(otherUserId),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) return const SizedBox.shrink();
        final otherUser = userSnapshot.data!;

        return GestureDetector(
          onTap: () {
            // Close sheet and navigate to chat, OR open chat overlay?
            // Standard behavior: Navigate to chat screen.
            Navigator.pop(context); // Close sheet
            Navigator.pushNamed(context, '/chat', arguments: {'chatId': chatId, 'otherUser': otherUser});
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
            ),
            child: Row(
              children: [
                // Avatar
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      backgroundImage: otherUser.photos.isNotEmpty ? CachedNetworkImageProvider(otherUser.photos[0]) : null,
                      child: otherUser.photos.isEmpty ? Text(otherUser.name[0].toUpperCase(), style: const TextStyle(color: Colors.white)) : null,
                    ),
                    if (otherUser.isOnline)
                      Positioned(bottom: 0, right: 0, child: Container(width: 10, height: 10, decoration: BoxDecoration(color: const Color(0xFF00E676), shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 2)))),
                  ],
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        otherUser.name,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lastMessage ?? 'No messages',
                        style: TextStyle(
                          color: unreadCount > 0 ? Colors.white : Colors.white60,
                          fontSize: 13,
                          fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.w400,
                        ),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Meta
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (lastMessageAt != null)
                      Text(_formatTime(lastMessageAt), style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                    if (unreadCount > 0) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final DateTime dateTime = timestamp.toDate();
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      if (difference.inDays == 0) {
        return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${dateTime.day}/${dateTime.month}';
      }
    } catch (e) {
      return '';
    }
  }
}
