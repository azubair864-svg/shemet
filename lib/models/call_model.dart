import 'package:cloud_firestore/cloud_firestore.dart';

class CallModel {
  final String callId;
  final String callerId;
  final String callerName;
  final String? callerPhoto;
  final String receiverId;
  final String receiverName;
  final String? receiverPhoto;
  final CallType type; // video or voice
  final CallStatus status; // ringing, ongoing, ended, missed, rejected, cancelled
  final Timestamp createdAt;
  final Timestamp? startedAt;
  final Timestamp? endedAt;
  final int? duration; // in seconds
  final String? agoraChannelId;
  final String? agoraToken;
  final String? endReason; // 'completed', 'cancelled', 'rejected', 'timeout', 'error'
  final bool isRead; // Track if missed call has been seen

  CallModel({
    required this.callId,
    required this.callerId,
    required this.callerName,
    this.callerPhoto,
    required this.receiverId,
    required this.receiverName,
    this.receiverPhoto,
    required this.type,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.endedAt,
    this.duration,
    this.agoraChannelId,
    this.agoraToken,
    this.endReason,
    this.isRead = false,
  });

  // From Firestore
  factory CallModel.fromMap(Map<String, dynamic> map, String callId) {
    return CallModel(
      callId: callId,
      callerId: map['callerId'] ?? '',
      callerName: map['callerName'] ?? '',
      callerPhoto: map['callerPhoto'],
      receiverId: map['receiverId'] ?? '',
      receiverName: map['receiverName'] ?? '',
      receiverPhoto: map['receiverPhoto'],
      type: CallType.values.firstWhere(
        (e) => e.name == (map['type'] ?? 'voice'),
        orElse: () => CallType.voice,
      ),
      status: CallStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'ringing'),
        orElse: () => CallStatus.ringing,
      ),
      createdAt: map['createdAt'] ?? Timestamp.now(),
      startedAt: map['startedAt'],
      endedAt: map['endedAt'],
      duration: map['duration'],
      agoraChannelId: map['agoraChannelId'],
      agoraToken: map['agoraToken'],
      endReason: map['endReason'],
      isRead: map['isRead'] ?? false,
    );
  }

  // To Firestore
  Map<String, dynamic> toMap() {
    return {
      'callerId': callerId,
      'callerName': callerName,
      'callerPhoto': callerPhoto,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverPhoto': receiverPhoto,
      'type': type.name,
      'status': status.name,
      'createdAt': createdAt,
      'startedAt': startedAt,
      'endedAt': endedAt,
      'duration': duration,
      'agoraChannelId': agoraChannelId,
      'agoraToken': agoraToken,
      'endReason': endReason,
      'isRead': isRead,
      'participants': [callerId, receiverId],
    };
  }

  // CopyWith for updates
  CallModel copyWith({
    String? callId,
    String? callerId,
    String? callerName,
    String? callerPhoto,
    String? receiverId,
    String? receiverName,
    String? receiverPhoto,
    CallType? type,
    CallStatus? status,
    Timestamp? createdAt,
    Timestamp? startedAt,
    Timestamp? endedAt,
    int? duration,
    String? agoraChannelId,
    String? agoraToken,
    String? endReason,
    bool? isRead,
  }) {
    return CallModel(
      callId: callId ?? this.callId,
      callerId: callerId ?? this.callerId,
      callerName: callerName ?? this.callerName,
      callerPhoto: callerPhoto ?? this.callerPhoto,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      receiverPhoto: receiverPhoto ?? this.receiverPhoto,
      type: type ?? this.type,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      duration: duration ?? this.duration,
      agoraChannelId: agoraChannelId ?? this.agoraChannelId,
      agoraToken: agoraToken ?? this.agoraToken,
      endReason: endReason ?? this.endReason,
      isRead: isRead ?? this.isRead,
    );
  }

  // Get other user ID
  String getOtherUserId(String currentUserId) {
    return currentUserId == callerId ? receiverId : callerId;
  }

  // Get other user name
  String getOtherUserName(String currentUserId) {
    return currentUserId == callerId ? receiverName : callerName;
  }

  // Get other user photo
  String? getOtherUserPhoto(String currentUserId) {
    return currentUserId == callerId ? receiverPhoto : callerPhoto;
  }

  // Check if call is missed for a user
  bool isMissedFor(String userId) {
    return receiverId == userId && status == CallStatus.missed;
  }

  // Format duration as MM:SS
  String get formattedDuration {
    if (duration == null) return '00:00';
    final minutes = (duration! / 60).floor();
    final seconds = duration! % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Get call status display text
  String getStatusText(String currentUserId) {
    if (status == CallStatus.missed && receiverId == currentUserId) {
      return 'Missed Call';
    } else if (status == CallStatus.missed && callerId == currentUserId) {
      return 'No Answer';
    } else if (status == CallStatus.rejected) {
      return 'Declined';
    } else if (status == CallStatus.cancelled) {
      return 'Cancelled';
    } else if (status == CallStatus.ended) {
      return formattedDuration;
    } else if (status == CallStatus.ongoing) {
      return 'Ongoing';
    } else {
      return 'Ringing';
    }
  }
}

enum CallType {
  voice,
  video,
}

enum CallStatus {
  ringing,    // Call initiated, waiting for answer
  ongoing,    // Call in progress
  ended,      // Call completed normally
  missed,     // Receiver didn't answer
  rejected,   // Receiver declined
  cancelled,  // Caller cancelled before answer
}
