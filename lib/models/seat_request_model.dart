import 'package:cloud_firestore/cloud_firestore.dart';

class SeatRequestModel {
  final String id;
  final String roomId;
  final String userId;
  final String userName;
  final String? userPhoto;
  final int userLevel;
  final bool isVip;
  final int requestedSeat; // -1 means any available seat
  final DateTime createdAt;
  final String status; // 'pending', 'approved', 'rejected', 'expired'

  SeatRequestModel({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.userName,
    this.userPhoto,
    required this.userLevel,
    required this.isVip,
    required this.requestedSeat,
    required this.createdAt,
    required this.status,
  });

  factory SeatRequestModel.fromMap(Map<String, dynamic> map, String id) {
    return SeatRequestModel(
      id: id,
      roomId: map['roomId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userPhoto: map['userPhoto'],
      userLevel: map['userLevel'] ?? 0,
      isVip: map['isVip'] ?? false,
      requestedSeat: map['requestedSeat'] ?? -1,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      status: map['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'userId': userId,
      'userName': userName,
      'userPhoto': userPhoto,
      'userLevel': userLevel,
      'isVip': isVip,
      'requestedSeat': requestedSeat,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
    };
  }

  SeatRequestModel copyWith({
    String? id,
    String? roomId,
    String? userId,
    String? userName,
    String? userPhoto,
    int? userLevel,
    bool? isVip,
    int? requestedSeat,
    DateTime? createdAt,
    String? status,
  }) {
    return SeatRequestModel(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userPhoto: userPhoto ?? this.userPhoto,
      userLevel: userLevel ?? this.userLevel,
      isVip: isVip ?? this.isVip,
      requestedSeat: requestedSeat ?? this.requestedSeat,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }
}