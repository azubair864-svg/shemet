import 'package:cloud_firestore/cloud_firestore.dart';

/// Match Model - Represents a match between two users
class MatchModel {
  final String id;
  final String user1Id;
  final String user2Id;
  final List<String> users;
  final DateTime matchedAt;
  final DateTime? lastMessageAt;
  final int unreadCount1;
  final int unreadCount2;

  MatchModel({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    required this.users,
    required this.matchedAt,
    this.lastMessageAt,
    this.unreadCount1 = 0,
    this.unreadCount2 = 0,
  });

  // From Firestore
  factory MatchModel.fromMap(Map<String, dynamic> map, String documentId) {
    return MatchModel(
      id: documentId,
      user1Id: map['user1Id'] ?? '',
      user2Id: map['user2Id'] ?? '',
      users: List<String>.from(map['users'] ?? []),
      matchedAt: (map['matchedAt'] as Timestamp).toDate(),
      lastMessageAt: map['lastMessageAt'] != null
          ? (map['lastMessageAt'] as Timestamp).toDate()
          : null,
      unreadCount1: map['unreadCount1'] ?? 0,
      unreadCount2: map['unreadCount2'] ?? 0,
    );
  }

  // To Firestore
  Map<String, dynamic> toMap() {
    return {
      'user1Id': user1Id,
      'user2Id': user2Id,
      'users': users,
      'matchedAt': Timestamp.fromDate(matchedAt),
      'lastMessageAt': lastMessageAt != null
          ? Timestamp.fromDate(lastMessageAt!)
          : null,
      'unreadCount1': unreadCount1,
      'unreadCount2': unreadCount2,
    };
  }

  // Get other user ID
  String getOtherUserId(String currentUserId) {
    return users.firstWhere((id) => id != currentUserId);
  }

  // Copy with
  MatchModel copyWith({
    String? id,
    String? user1Id,
    String? user2Id,
    List<String>? users,
    DateTime? matchedAt,
    DateTime? lastMessageAt,
    int? unreadCount1,
    int? unreadCount2,
  }) {
    return MatchModel(
      id: id ?? this.id,
      user1Id: user1Id ?? this.user1Id,
      user2Id: user2Id ?? this.user2Id,
      users: users ?? this.users,
      matchedAt: matchedAt ?? this.matchedAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount1: unreadCount1 ?? this.unreadCount1,
      unreadCount2: unreadCount2 ?? this.unreadCount2,
    );
  }
}

/// Like Model - Represents a like action
class LikeModel {
  final String id;
  final String fromUserId;
  final String toUserId;
  final DateTime timestamp;

  LikeModel({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.timestamp,
  });

  // From Firestore
  factory LikeModel.fromMap(Map<String, dynamic> map, String documentId) {
    return LikeModel(
      id: documentId,
      fromUserId: map['fromUserId'] ?? '',
      toUserId: map['toUserId'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }

  // To Firestore
  Map<String, dynamic> toMap() {
    return {
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

/// Pass Model - Represents a pass action
class PassModel {
  final String id;
  final String fromUserId;
  final String toUserId;
  final DateTime timestamp;

  PassModel({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.timestamp,
  });

  // From Firestore
  factory PassModel.fromMap(Map<String, dynamic> map, String documentId) {
    return PassModel(
      id: documentId,
      fromUserId: map['fromUserId'] ?? '',
      toUserId: map['toUserId'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }

  // To Firestore
  Map<String, dynamic> toMap() {
    return {
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
