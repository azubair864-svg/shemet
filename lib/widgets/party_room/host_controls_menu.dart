import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../widgets/party_room/user_quick_profile_sheet.dart';
import '../../widgets/party_room/block_confirmation_dialog.dart';
import '../../services/notification_service.dart';

class HostControlsMenu extends StatelessWidget {
  final String roomId;
  final String roomName;
  final String targetUserId;
  final String targetUserName;
  final int? seatNumber;
  final bool isHost;
  final VoidCallback? onDismiss;

  const HostControlsMenu({
    super.key,
    required this.roomId,
    this.roomName = 'Party Room',
    required this.targetUserId,
    required this.targetUserName,
    this.seatNumber,
    this.isHost = false,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (!isHost) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF2D1B69),
            Color(0xFF1A0F3D),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Text(
                  'Manage: $targetUserName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                // View Profile button
                _buildControlButton(
                  context,
                  icon: Icons.person_outline,
                  label: 'View Profile',
                  color: Colors.blue,
                  onTap: () => _viewProfile(context),
                ),

                const SizedBox(height: 12),

                // Mute button
                _buildControlButton(
                  context,
                  icon: Icons.mic_off,
                  label: 'Mute',
                  color: Colors.orange,
                  onTap: () => _muteUser(context),
                ),

                const SizedBox(height: 12),

                // Kick button
                _buildControlButton(
                  context,
                  icon: Icons.exit_to_app,
                  label: 'Kick from Seat',
                  color: Colors.deepOrange,
                  onTap: () => _kickUser(context),
                ),

                const SizedBox(height: 12),

                // Block button
                _buildControlButton(
                  context,
                  icon: Icons.block,
                  label: 'Block User',
                  color: Colors.red,
                  onTap: () => _blockUser(context),
                ),

                if (seatNumber != null) ...[
                  const SizedBox(height: 12),

                  // Lock seat button
                  _buildControlButton(
                    context,
                    icon: Icons.lock_outline,
                    label: 'Lock Seat',
                    color: Colors.purple,
                    onTap: () => _lockSeat(context),
                  ),
                ],

                const SizedBox(height: 12),

                // Cancel button
                _buildControlButton(
                  context,
                  icon: Icons.close,
                  label: 'Cancel',
                  color: Colors.grey,
                  onTap: () {
                    Navigator.pop(context);
                    onDismiss?.call();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _viewProfile(BuildContext context) {
    Navigator.pop(context); // Close host menu first

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => UserQuickProfileSheet(
        userId: targetUserId,
        roomId: roomId,
        isHost: true,
        onBlock: () => _blockUser(context),
        onKick: () => _kickUser(context),
      ),
    );
  }

  Future<void> _muteUser(BuildContext context) async {
    final dbService = DatabaseService();

    // Show confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Mute User', style: TextStyle(color: Colors.white)),
        content: Text(
          'Mute $targetUserName in this room?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mute', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await dbService.muteUserInRoom(
        roomId: roomId,
        userId: targetUserId,
        isMuted: true,
        mutedBy: 'host',
      );

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'User muted' : 'Failed to mute user'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _kickUser(BuildContext context) async {
    final dbService = DatabaseService();
    final notificationService = NotificationService();

    // Show confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Kick User', style: TextStyle(color: Colors.white)),
        content: Text(
          'Remove $targetUserName from the room?',
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
        userId: targetUserId,
        kickedBy: 'host',
      );

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'User kicked' : 'Failed to kick user'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );

        // Send notification
        if (success) {
          await notificationService.sendKickedNotification(
            userId: targetUserId,
            roomName: roomName,
          );
        }
      }
    }
  }

  Future<void> _blockUser(BuildContext context) async {
    final dbService = DatabaseService();
    final notificationService = NotificationService();

    // Close current menu first
    Navigator.pop(context);

    // Show block confirmation dialog
    showBlockConfirmationDialog(
      context: context,
      userName: targetUserName,
      onConfirm: () async {
        final success = await dbService.blockUserFromRoom(
          roomId: roomId,
          userId: targetUserId,
          blockedBy: 'host',
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success ? 'User blocked' : 'Failed to block user'),
              backgroundColor: success ? Colors.red : Colors.grey,
            ),
          );

          // Send notification
          if (success) {
            await notificationService.sendBlockedNotification(
              userId: targetUserId,
              roomName: roomName,
            );
          }
        }
      },
    );
  }

  Future<void> _lockSeat(BuildContext context) async {
    if (seatNumber == null) return;

    final dbService = DatabaseService();

    final success = await dbService.toggleSeatLock(
      roomId: roomId,
      seatNumber: seatNumber!,
      isLocked: true,
    );

    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Seat locked' : 'Failed to lock seat'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }
}