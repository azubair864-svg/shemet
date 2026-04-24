import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'database_service.dart';
import '../models/notification_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final DatabaseService _db = DatabaseService();
  
  StreamSubscription? _notificationSubscription;

  Future<void> initialize(BuildContext context, String userId) async {
    
    

    await _requestPermission();

    final token = await _fcm.getToken();
    

    if (token != null) {
      
      final success = await _db.updateUser(userId, {'fcmToken': token});
      
    } else {
      
    }

    // Foreground messages
    
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      
      
      
      
      
      _showNotification(context, message);
    });

    // Background tap
    
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      
      
      _handleNotificationTap(context, message);
    });

    
  }

  Future<void> _requestPermission() async {
    

    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    
    
    
    
  }

  void _showNotification(BuildContext context, RemoteMessage message) {
    

    if (message.notification != null) {
      final type = message.data['type'];
      // RELENTLESS FILTER: DO NOT show generic dialog for calls - GlobalCallListener handles them
      final typeStr = type?.toString().toLowerCase() ?? '';
      final titleStr = message.notification?.title?.toLowerCase() ?? '';
      final bodyStr = message.notification?.body?.toLowerCase() ?? '';

      if (typeStr.contains('call') || titleStr.contains('call') || bodyStr.contains('call')) {
        return;
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(message.notification!.title ?? 'Notification'),
          content: Text(message.notification!.body ?? ''),
          actions: [
            TextButton(
              onPressed: () {
                
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      
    }
  }

  void _handleNotificationTap(BuildContext context, RemoteMessage message) {
    

    final type = message.data['type'];
    

    if (type == 'chat') {
      
      Navigator.pushNamed(context, '/chat', arguments: message.data);
    } else if (type == 'match') {
      
      Navigator.pushNamed(context, '/messages');
    } else if (type == 'seat_approved') {
      
      final roomId = message.data['roomId'];
      if (roomId != null) {
        Navigator.pushNamed(context, '/party-room', arguments: {'roomId': roomId});
      }
    } else if (type == 'seat_rejected') {
      
      _showSimpleAlert(context, 'Seat Request', 'Your seat request was rejected');
    } else if (type == 'kicked') {
      
      _showSimpleAlert(context, 'Removed', 'You were removed from the party room');
    } else {
      
    }
  }

  void _showSimpleAlert(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ==================== NEW PARTY ROOM NOTIFICATION METHODS ====================

  /// Send notification when seat request is approved
  Future<void> sendSeatApprovedNotification({
    required String userId,
    required String roomId,
    required String roomName,
  }) async {
    try {
      await _db.sendUserNotification(
        userId: userId,
        title: 'Seat Approved! 🎉',
        body: 'Your request to join "$roomName" was approved',
        data: {
          'type': 'seat_approved',
          'roomId': roomId,
          'roomName': roomName,
        },
      );
      
    } catch (e) {
      
    }
  }

  /// Send notification when seat request is rejected
  Future<void> sendSeatRejectedNotification({
    required String userId,
    required String roomName,
  }) async {
    try {
      await _db.sendUserNotification(
        userId: userId,
        title: 'Seat Request Declined',
        body: 'Your request to join "$roomName" was declined',
        data: {
          'type': 'seat_rejected',
          'roomName': roomName,
        },
      );
      
    } catch (e) {
      
    }
  }

  /// Send notification when user is kicked
  Future<void> sendKickedNotification({
    required String userId,
    required String roomName,
  }) async {
    try {
      await _db.sendUserNotification(
        userId: userId,
        title: 'Removed from Room',
        body: 'You were removed from "$roomName"',
        data: {
          'type': 'kicked',
          'roomName': roomName,
        },
      );
      
    } catch (e) {
      
    }
  }

  /// Send notification when user is blocked
  Future<void> sendBlockedNotification({
    required String userId,
    required String roomName,
  }) async {
    try {
      await _db.sendUserNotification(
        userId: userId,
        title: 'Blocked from Room',
        body: 'You have been blocked from "$roomName"',
        data: {
          'type': 'blocked',
          'roomName': roomName,
        },
      );
      
    } catch (e) {
      
    }
  }

  /// Send notification for new gift received
  Future<void> sendGiftNotification({
    required String receiverId,
    required String senderName,
    required String giftName,
    required int giftValue,
  }) async {
    try {
      await _db.sendUserNotification(
        userId: receiverId,
        title: 'Gift Received! 🎁',
        body: '$senderName sent you $giftName ($giftValue💎)',
        data: {
          'type': 'gift',
          'senderName': senderName,
          'giftName': giftName,
          'giftValue': giftValue.toString(),
        },
      );
      
    } catch (e) {
      
    }
  }

  // ==================== GENERIC NOTIFICATION METHOD ====================

  /// Generic send notification method for all notification types
  /// Used by MomentService, MessageService, etc.
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    
    
    
    

    try {
      await _db.sendUserNotification(
        userId: userId,
        title: title,
        body: body,
        data: {
          'type': type,
          ...?data,
        },
      );
      
    } catch (e) {
      
    }
  }

  // ==================== MOMENT NOTIFICATION METHODS ====================

  /// Send notification when someone likes a moment
  Future<void> sendMomentLikeNotification({
    required String momentOwnerId,
    required String likerName,
    required String momentId,
    String? momentText,
  }) async {
    
    await sendNotification(
      userId: momentOwnerId,
      title: '$likerName liked your moment',
      body: momentText ?? 'Your moment',
      type: 'moment_like',
      data: {'momentId': momentId},
    );
  }

  /// Send notification when someone comments on a moment
  Future<void> sendMomentCommentNotification({
    required String momentOwnerId,
    required String commenterName,
    required String momentId,
    required String commentText,
  }) async {
    
    await sendNotification(
      userId: momentOwnerId,
      title: '$commenterName commented on your moment',
      body: commentText,
      type: 'moment_comment',
      data: {'momentId': momentId},
    );
  }

  /// Send notification when someone mentions you in a moment
  Future<void> sendMomentMentionNotification({
    required String mentionedUserId,
    required String mentionerName,
    required String momentId,
    String? momentText,
  }) async {
    
    await sendNotification(
      userId: mentionedUserId,
      title: '$mentionerName mentioned you',
      body: momentText ?? 'in a moment',
      type: 'moment_mention',
      data: {'momentId': momentId},
    );
  }

  // ==================== CALL NOTIFICATION METHODS ====================

  /// Send notification for incoming call
  Future<void> sendIncomingCallNotification({
    required String receiverId,
    required String callerName,
    required String callType,
    required String callId,
  }) async {
    
    await sendNotification(
      userId: receiverId,
      title: 'Incoming $callType call',
      body: '$callerName is calling you',
      type: 'incoming_call',
      data: {
        'callId': callId,
        'callType': callType,
        'callerName': callerName,
      },
    );
  }

  /// Send notification for missed call
  Future<void> sendMissedCallNotification({
    required String receiverId,
    required String callerName,
    required String callType,
  }) async {
    
    await sendNotification(
      userId: receiverId,
      title: 'Missed $callType call',
      body: 'You missed a call from $callerName',
      type: 'missed_call',
      data: {
        'callType': callType,
        'callerName': callerName,
      },
    );
  }

  // ==================== FOLLOW NOTIFICATION METHODS ====================

  /// Send notification when someone follows you
  Future<void> sendFollowNotification({
    required String followedUserId,
    required String followerName,
    required String followerId,
  }) async {
    
    await sendNotification(
      userId: followedUserId,
      title: 'New Follower',
      body: '$followerName started following you',
      type: 'follow',
      data: {'followerId': followerId},
    );
  }

  // ==================== MESSAGE NOTIFICATION METHODS ====================

  /// Send notification for new message
  Future<void> sendMessageNotification({
    required String receiverId,
    required String senderName,
    required String senderId,
    required String message,
    required String chatId,
  }) async {
    
    await sendNotification(
      userId: receiverId,
      title: senderName,
      body: message,
      type: 'chat',
      data: {
        'senderId': senderId,
        'chatId': chatId,
      },
    );
  }

  // ==================== LEADERBOARD NOTIFICATION METHODS ====================

  /// Send notification for leaderboard rank change
  Future<void> sendLeaderboardNotification({
    required String userId,
    required String leaderboardType,
    required int newRank,
    int? previousRank,
  }) async {
    

    String title;
    String body;

    if (newRank <= 3) {
      title = '🏆 Top 3 Achievement!';
      body = 'You\'re now #$newRank on the $leaderboardType leaderboard!';
    } else if (previousRank != null && newRank < previousRank) {
      title = '📈 Rank Up!';
      body = 'You moved from #$previousRank to #$newRank on $leaderboardType!';
    } else {
      title = '📊 Leaderboard Update';
      body = 'Your rank on $leaderboardType: #$newRank';
    }

    await sendNotification(
      userId: userId,
      title: title,
      body: body,
      type: 'leaderboard',
      data: {
        'leaderboardType': leaderboardType,
        'newRank': newRank,
        'previousRank': previousRank,
      },
    );
  }

  // ==================== IN-APP NOTIFICATION LISTENER ====================

  Stream<List<NotificationModel>> getNotificationStream(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationModel.fromFirestore(doc))
            .toList());
  }

  void startInAppNotificationListener(BuildContext context, String userId) {
    final startTime = DateTime.now();
    
    // CANCEL ANY PREVIOUS LISTENER to avoid duplicates
    _notificationSubscription?.cancel();
    
    _notificationSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('createdAt', isGreaterThan: startTime)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final notification = NotificationModel.fromFirestore(change.doc);
          
          // RELENTLESS FILTER: KILL ALL CALL NOTIFICATIONS
          final type = notification.type.toLowerCase();
          final title = notification.title.toLowerCase();
          final body = notification.body.toLowerCase();
          
          if (type.contains('call') || title.contains('call') || body.contains('call')) {
            debugPrint('[CRITICAL_FILTER] BLOCKED CALL SNACKBAR: $title | $type');
            continue;
          }

          if (!notification.read) {
            _showInAppSnackBar(context, notification);
          }
        }
      }
    });
  }

  void _showInAppSnackBar(BuildContext context, NotificationModel notification) {
    // FINAL SHIELD: Never show calls as SnackBars
    final title = notification.title.toLowerCase();
    final type = notification.type.toLowerCase();
    final body = notification.body.toLowerCase();
    
    if (title.contains('call') || type.contains('call') || body.contains('call')) {
      debugPrint('[FINAL_SHIELD] BLOCKED call SnackBar: $title');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF1A1033), Colors.blueGrey.shade900],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.notifications_active_rounded, color: Colors.amber, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notification.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(notification.body, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}