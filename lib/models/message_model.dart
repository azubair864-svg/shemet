import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final String? senderPhoto;
  final String text;
  final MessageType type;
  final String? imageUrl;
  final String? voiceUrl;
  final int? voiceDuration;
  final String? giftId;
  final String? giftName;
  final String? giftEmoji;
  final int? giftValue;
  final Map<String, String>? reactions; // userId: emoji
  final bool isRead;
  final bool isDelivered;
  final Timestamp createdAt;
  final Timestamp? readAt;
  final String? replyToId;
  final String? replyToText;
  final bool isForwarded;
  final bool isDeleted;

  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    this.senderPhoto,
    required this.text,
    required this.type,
    this.imageUrl,
    this.voiceUrl,
    this.voiceDuration,
    this.giftId,
    this.giftName,
    this.giftEmoji,
    this.giftValue,
    this.reactions,
    this.isRead = false,
    this.isDelivered = false,
    required this.createdAt,
    this.readAt,
    this.replyToId,
    this.replyToText,
    this.isForwarded = false,
    this.isDeleted = false,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    return MessageModel(
      id: id,
      chatId: map['chatId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      senderPhoto: map['senderPhoto'],
      text: map['text'] ?? '',
      type: MessageType.values.firstWhere(
            (e) => e.name == (map['type'] ?? 'text'),
        orElse: () => MessageType.text,
      ),
      imageUrl: map['imageUrl'],
      voiceUrl: map['voiceUrl'],
      voiceDuration: map['voiceDuration'],
      giftId: map['giftId'],
      giftName: map['giftName'],
      giftEmoji: map['giftEmoji'],
      giftValue: map['giftValue'],
      reactions: map['reactions'] != null
          ? Map<String, String>.from(map['reactions'])
          : null,
      isRead: map['isRead'] ?? false,
      isDelivered: map['isDelivered'] ?? false,
      createdAt: map['createdAt'] ?? Timestamp.now(),
      readAt: map['readAt'],
      replyToId: map['replyToId'],
      replyToText: map['replyToText'],
      isForwarded: map['isForwarded'] ?? false,
      isDeleted: map['isDeleted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'senderPhoto': senderPhoto,
      'text': text,
      'type': type.name,
      'imageUrl': imageUrl,
      'voiceUrl': voiceUrl,
      'voiceDuration': voiceDuration,
      'giftId': giftId,
      'giftName': giftName,
      'giftEmoji': giftEmoji,
      'giftValue': giftValue,
      'reactions': reactions,
      'isRead': isRead,
      'isDelivered': isDelivered,
      'createdAt': createdAt,
      'readAt': readAt,
      'replyToId': replyToId,
      'replyToText': replyToText,
      'isForwarded': isForwarded,
      'isDeleted': isDeleted,
    };
  }

  MessageModel copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? senderName,
    String? senderPhoto,
    String? text,
    MessageType? type,
    String? imageUrl,
    String? voiceUrl,
    int? voiceDuration,
    String? giftId,
    String? giftName,
    String? giftEmoji,
    int? giftValue,
    Map<String, String>? reactions,
    bool? isRead,
    bool? isDelivered,
    Timestamp? createdAt,
    Timestamp? readAt,
    String? replyToId,
    String? replyToText,
    bool? isForwarded,
    bool? isDeleted,
  }) {
    return MessageModel(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderPhoto: senderPhoto ?? this.senderPhoto,
      text: text ?? this.text,
      type: type ?? this.type,
      imageUrl: imageUrl ?? this.imageUrl,
      voiceUrl: voiceUrl ?? this.voiceUrl,
      voiceDuration: voiceDuration ?? this.voiceDuration,
      giftId: giftId ?? this.giftId,
      giftName: giftName ?? this.giftName,
      giftEmoji: giftEmoji ?? this.giftEmoji,
      giftValue: giftValue ?? this.giftValue,
      reactions: reactions ?? this.reactions,
      isRead: isRead ?? this.isRead,
      isDelivered: isDelivered ?? this.isDelivered,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
      replyToId: replyToId ?? this.replyToId,
      replyToText: replyToText ?? this.replyToText,
      isForwarded: isForwarded ?? this.isForwarded,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

enum MessageType {
  text,
  image,
  voice,
  video,
  gift,
  call,
  system,
}