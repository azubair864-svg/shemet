import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/database_service.dart';
import '../../widgets/party_room/user_quick_profile_sheet.dart';
import '../../widgets/party_room/block_confirmation_dialog.dart';
import '../../services/notification_service.dart';

class ParticipantListSheet extends StatelessWidget {
  final String roomId;
  final String roomName;
  final String currentUserId;
  final bool isHost;

  const ParticipantListSheet({
    super.key,
    required this.roomId,
    this.roomName = 'Party Room',
    required this.currentUserId,
    required this.isHost,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF2D1B69),
            Color(0xFF1A0F3D),
          ],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Participants',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Participant list
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: DatabaseService().getRoomParticipantsStream(roomId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.pink),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      'No participants',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }

                final participants = snapshot.data!;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: participants.length,
                  itemBuilder: (context, index) {
                    final participant = participants[index];
                    return _buildParticipantItem(context, participant);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantItem(
      BuildContext context,
      Map<String, dynamic> participant,
      ) {
    final userId = participant['userId'] ?? participant['uid'];
    final name = participant['name'] ?? 'Unknown';
    final photoUrl = participant['photoURL'] ?? participant['photos']?[0];
    final level = participant['level'] ?? 0;
    final isVip = participant['isVip'] ?? false;
    final isOnline = participant['isOnline'] ?? false;
    final isCurrentUser = userId == currentUserId;

    return GestureDetector(
      onTap: () => _showQuickProfile(context, userId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isVip
                ? Colors.amber.withOpacity(0.3)
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isVip ? Colors.amber : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundImage: photoUrl != null
                        ? CachedNetworkImageProvider(photoUrl)
                        : null,
                    backgroundColor: Colors.grey[800],
                    child: photoUrl == null
                        ? Text(
                      name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                        : null,
                  ),
                ),

                // Online indicator
                if (isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 12),

            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.pink.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'You',
                            style: TextStyle(
                              color: Colors.pink,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Lv$level',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isVip) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.amber, width: 1),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('💎', style: TextStyle(fontSize: 8)),
                              SizedBox(width: 2),
                              Text(
                                'VIP',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Quick actions (for host only)
            if (isHost && !isCurrentUser)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // View profile button
                  IconButton(
                    icon: const Icon(Icons.person, color: Colors.blue, size: 20),
                    onPressed: () => _showQuickProfile(context, userId),
                    tooltip: 'View Profile',
                  ),

                  // More options
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                    color: Colors.grey[850],
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'mute',
                        child: Row(
                          children: [
                            Icon(Icons.mic_off, color: Colors.orange, size: 18),
                            SizedBox(width: 8),
                            Text('Mute', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'kick',
                        child: Row(
                          children: [
                            Icon(Icons.exit_to_app, color: Colors.deepOrange, size: 18),
                            SizedBox(width: 8),
                            Text('Kick', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'block',
                        child: Row(
                          children: [
                            Icon(Icons.block, color: Colors.red, size: 18),
                            SizedBox(width: 8),
                            Text('Block', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) => _handleAction(context, value, userId, name),
                  ),
                ],
              )
            else if (!isCurrentUser)
              IconButton(
                icon: const Icon(Icons.person, color: Colors.white54, size: 20),
                onPressed: () => _showQuickProfile(context, userId),
                tooltip: 'View Profile',
              ),
          ],
        ),
      ),
    );
  }

  void _showQuickProfile(BuildContext context, String userId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => UserQuickProfileSheet(
        userId: userId,
        roomId: roomId,
        isHost: isHost,
        onBlock: () => _handleAction(context, 'block', userId, ''),
        onKick: () => _handleAction(context, 'kick', userId, ''),
      ),
    );
  }

  Future<void> _handleAction(
      BuildContext context,
      String action,
      String userId,
      String userName,
      ) async {
    final dbService = DatabaseService();
    final notificationService = NotificationService();

    if (action == 'mute') {
      await dbService.muteUserInRoom(
        roomId: roomId,
        userId: userId,
        isMuted: true,
        mutedBy: currentUserId,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User muted'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else if (action == 'kick') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Kick User', style: TextStyle(color: Colors.white)),
          content: Text(
            'Remove ${userName.isNotEmpty ? userName : 'this user'} from the room?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Kick', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        final success = await dbService.kickUserFromRoom(
          roomId: roomId,
          userId: userId,
          kickedBy: currentUserId,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success ? 'User kicked' : 'Failed to kick'),
              backgroundColor: success ? Colors.green : Colors.red,
            ),
          );

          // Send notification
          if (success) {
            await notificationService.sendKickedNotification(
              userId: userId,
              roomName: roomName,
            );
          }
        }
      }
    } else if (action == 'block') {
      // Get user name if not provided
      if (userName.isEmpty) {
        final userDoc = await dbService.getUserById(userId);
        userName = userDoc?.name ?? 'User';
      }

      if (context.mounted) {
        showBlockConfirmationDialog(
          context: context,
          userName: userName,
          onConfirm: () async {
            final success = await dbService.blockUserFromRoom(
              roomId: roomId,
              userId: userId,
              blockedBy: currentUserId,
            );

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(success ? 'User blocked' : 'Failed to block'),
                  backgroundColor: success ? Colors.red : Colors.grey,
                ),
              );

              // Send notification
              if (success) {
                await notificationService.sendBlockedNotification(
                  userId: userId,
                  roomName: roomName,
                );
              }
            }
          },
        );
      }
    }
  }
}