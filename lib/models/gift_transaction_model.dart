import 'package:cloud_firestore/cloud_firestore.dart';

class GiftTransactionModel {
  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final String? senderPhoto;
  final String receiverId;
  final String receiverName;
  final String? receiverPhoto;
  final String giftId;
  final String giftName;
  final String giftEmoji;
  final int giftValue; // in diamonds
  final int comboCount; // 1x, 2x, 3x etc
  final DateTime timestamp;

  GiftTransactionModel({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    this.senderPhoto,
    required this.receiverId,
    required this.receiverName,
    this.receiverPhoto,
    required this.giftId,
    required this.giftName,
    required this.giftEmoji,
    required this.giftValue,
    this.comboCount = 1,
    required this.timestamp,
  });

  factory GiftTransactionModel.fromMap(Map<String, dynamic> map, String id) {
    return GiftTransactionModel(
      id: id,
      roomId: map['roomId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      senderPhoto: map['senderPhoto'],
      receiverId: map['receiverId'] ?? '',
      receiverName: map['receiverName'] ?? '',
      receiverPhoto: map['receiverPhoto'],
      giftId: map['giftId'] ?? '',
      giftName: map['giftName'] ?? '',
      giftEmoji: map['giftEmoji'] ?? '🎁',
      giftValue: map['giftValue'] ?? 0,
      comboCount: map['comboCount'] ?? 1,
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'senderId': senderId,
      'senderName': senderName,
      'senderPhoto': senderPhoto,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverPhoto': receiverPhoto,
      'giftId': giftId,
      'giftName': giftName,
      'giftEmoji': giftEmoji,
      'giftValue': giftValue,
      'comboCount': comboCount,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  int get totalValue => giftValue * comboCount;
}