import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String chatId;
  final List<String> participants;
  final String? lastMessage;
  final Timestamp? lastMessageAt;
  final Timestamp createdAt;
  final Map<String, int> unreadCount;
  final Map<String, dynamic>? lastMessageData;

  ChatModel({
    required this.chatId,
    required this.participants,
    this.lastMessage,
    this.lastMessageAt,
    required this.createdAt,
    required this.unreadCount,
    this.lastMessageData,
  });

  // From Firestore
  factory ChatModel.fromMap(Map<String, dynamic> map, String chatId) {
    return ChatModel(
      chatId: chatId,
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage'],
      lastMessageAt: map['lastMessageAt'],
      createdAt: map['createdAt'] ?? Timestamp.now(),
      unreadCount: Map<String, int>.from(map['unreadCount'] ?? {}),
      lastMessageData: map['lastMessageData'],
    );
  }

  // To Firestore
  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageAt': lastMessageAt,
      'createdAt': createdAt,
      'unreadCount': unreadCount,
      'lastMessageData': lastMessageData,
    };
  }

  // Get other user ID
  String getOtherUserId(String currentUserId) {
    return participants.firstWhere((id) => id != currentUserId);
  }

  // Get unread count for current user
  int getUnreadCount(String userId) {
    return unreadCount[userId] ?? 0;
  }
}