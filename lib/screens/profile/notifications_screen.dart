import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/notification_model.dart';
import '../../core/constants/app_colors.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final notifications = snapshot.data!.docs
              .map((doc) => NotificationModel.fromFirestore(doc))
              .toList();

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: notifications.length,
            separatorBuilder: (context, index) => const Divider(color: Colors.white10),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _buildNotificationTile(context, notification);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded, size: 80, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 20),
          const Text('No notifications yet', style: TextStyle(color: Colors.white70, fontSize: 18)),
          const SizedBox(height: 8),
          Text('Stay tuned for follows, gifts, and more!', 
            style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildNotificationTile(BuildContext context, NotificationModel notification) {
    IconData icon;
    Color iconColor;

    switch (notification.type) {
      case 'follow':
        icon = Icons.person_add_rounded;
        iconColor = Colors.blueAccent;
        break;
      case 'gift':
        icon = Icons.card_giftcard_rounded;
        iconColor = Colors.amber;
        break;
      case 'chat':
        icon = Icons.chat_bubble_rounded;
        iconColor = Colors.greenAccent;
        break;
      case 'incoming_call':
        icon = Icons.call_received_rounded;
        iconColor = Colors.purpleAccent;
        break;
      default:
        icon = Icons.notifications_rounded;
        iconColor = AppColors.primary;
    }

    return Container(
      decoration: BoxDecoration(
        color: notification.read ? Colors.transparent : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            color: Colors.white,
            fontWeight: notification.read ? FontWeight.normal : FontWeight.bold,
            fontSize: 15,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(notification.body, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
            const SizedBox(height: 8),
            Text(
              _formatTimestamp(notification.createdAt),
              style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 11),
            ),
          ],
        ),
        onTap: () {
          // Mark as read
          FirebaseFirestore.instance
              .collection('users')
              .doc(FirebaseAuth.instance.currentUser?.uid)
              .collection('notifications')
              .doc(notification.id)
              .update({'read': true});
          
          // Handle tap based on type
          _handleTap(context, notification);
        },
      ),
    );
  }

  void _handleTap(BuildContext context, NotificationModel notification) {
    final type = notification.type;
    final data = notification.data;

    if (type == 'follow') {
       // Deep link to follower list or specific profile
       final followerId = data['followerId'];
       if (followerId != null) {
         // Navigator.pushNamed(context, '/user_profile_detail', arguments: ...); 
         // For now, just go to followers list
         Navigator.pushNamed(context, '/followers');
       }
    } else if (type == 'chat') {
       final chatId = data['chatId'];
       if (chatId != null) {
          // Logic to open chat screen if we have the full user model
          // For simplicity, we just navigate to messages list
          Navigator.pushNamed(context, '/messages');
       }
    }
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
