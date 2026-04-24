import 'package:cloud_firestore/cloud_firestore.dart';

class ChatPriceModel {
  final String userId;
  final bool isEnabled;
  final int pricePerMessage;
  final int freeMessagesCount;
  final int totalEarnings;
  final List<String> exemptUsers; // Users who can chat for free
  final Timestamp createdAt;
  final Timestamp updatedAt;

  ChatPriceModel({
    required this.userId,
    this.isEnabled = false,
    this.pricePerMessage = 10,
    this.freeMessagesCount = 3,
    this.totalEarnings = 0,
    this.exemptUsers = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatPriceModel.fromMap(Map<String, dynamic> map) {
    return ChatPriceModel(
      userId: map['userId'] ?? '',
      isEnabled: map['isEnabled'] ?? false,
      pricePerMessage: map['pricePerMessage'] ?? 10,
      freeMessagesCount: map['freeMessagesCount'] ?? 3,
      totalEarnings: map['totalEarnings'] ?? 0,
      exemptUsers: List<String>.from(map['exemptUsers'] ?? []),
      createdAt: map['createdAt'] ?? Timestamp.now(),
      updatedAt: map['updatedAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'isEnabled': isEnabled,
      'pricePerMessage': pricePerMessage,
      'freeMessagesCount': freeMessagesCount,
      'totalEarnings': totalEarnings,
      'exemptUsers': exemptUsers,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  ChatPriceModel copyWith({
    String? userId,
    bool? isEnabled,
    int? pricePerMessage,
    int? freeMessagesCount,
    int? totalEarnings,
    List<String>? exemptUsers,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return ChatPriceModel(
      userId: userId ?? this.userId,
      isEnabled: isEnabled ?? this.isEnabled,
      pricePerMessage: pricePerMessage ?? this.pricePerMessage,
      freeMessagesCount: freeMessagesCount ?? this.freeMessagesCount,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      exemptUsers: exemptUsers ?? this.exemptUsers,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ChatTransaction {
  final String id;
  final String chatId;
  final String senderId;
  final String receiverId;
  final int amount;
  final String messageId;
  final Timestamp createdAt;

  ChatTransaction({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.receiverId,
    required this.amount,
    required this.messageId,
    required this.createdAt,
  });

  factory ChatTransaction.fromMap(Map<String, dynamic> map, String id) {
    return ChatTransaction(
      id: id,
      chatId: map['chatId'] ?? '',
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      amount: map['amount'] ?? 0,
      messageId: map['messageId'] ?? '',
      createdAt: map['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'receiverId': receiverId,
      'amount': amount,
      'messageId': messageId,
      'createdAt': createdAt,
    };
  }
}