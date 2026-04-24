import 'package:cloud_firestore/cloud_firestore.dart';

class GreetingModel {
  final String id;
  final String userId;
  final String text;
  final String? imageUrl;
  final String? audioUrl;
  final int? audioDuration;
  final DateTime createdAt;

  GreetingModel({
    required this.id,
    required this.userId,
    required this.text,
    this.imageUrl,
    this.audioUrl,
    this.audioDuration,
    required this.createdAt,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'text': text,
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'audioDuration': audioDuration,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Create from Firestore document
  static GreetingModel fromMap(Map<String, dynamic> map) {
    return GreetingModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      text: map['text'] ?? '',
      imageUrl: map['imageUrl'],
      audioUrl: map['audioUrl'],
      audioDuration: map['audioDuration'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Create from Firestore DocumentSnapshot
  factory GreetingModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GreetingModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      text: data['text'] ?? '',
      imageUrl: data['imageUrl'],
      audioUrl: data['audioUrl'],
      audioDuration: data['audioDuration'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // CopyWith method for updates
  GreetingModel copyWith({
    String? id,
    String? userId,
    String? text,
    String? imageUrl,
    String? audioUrl,
    int? audioDuration,
    DateTime? createdAt,
  }) {
    return GreetingModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      audioDuration: audioDuration ?? this.audioDuration,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}