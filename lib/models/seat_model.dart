class SeatModel {
  final int index;
  final String? userId;
  final bool isLocked;
  final bool isMutedByHost;
  final bool isSelfMuted;

  final bool isVideoOn;
  final int contributionDiamonds; // Added for seat rewards

  const SeatModel({
    required this.index,
    this.userId,
    this.isLocked = false,
    this.isMutedByHost = false,
    this.isSelfMuted = false,
    this.isVideoOn = false,
    this.contributionDiamonds = 0,
  });

  bool get isOccupied => userId != null;

  Map<String, dynamic> toMap() {
    return {
      'index': index,
      'userId': userId,
      'isLocked': isLocked,
      'isMutedByHost': isMutedByHost,
      'isSelfMuted': isSelfMuted,
      'isVideoOn': isVideoOn,
      'contributionDiamonds': contributionDiamonds,
    };
  }

  factory SeatModel.fromMap(Map<String, dynamic> map) {
    return SeatModel(
      index: map['index'] ?? 0,
      userId: map['userId'],
      isLocked: map['isLocked'] ?? false,
      isMutedByHost: map['isMutedByHost'] ?? false,
      isSelfMuted: map['isSelfMuted'] ?? false,
      isVideoOn: map['isVideoOn'] ?? false,
      contributionDiamonds: map['contributionDiamonds'] ?? 0,
    );
  }

  SeatModel copyWith({
    int? index,
    String? userId,
    bool? isLocked,
    bool? isMutedByHost,
    bool? isSelfMuted,
    bool? isVideoOn,
    int? contributionDiamonds,
    bool clearUser = false,
  }) {
    return SeatModel(
      index: index ?? this.index,
      userId: clearUser ? null : (userId ?? this.userId),
      isLocked: isLocked ?? this.isLocked,
      isMutedByHost: isMutedByHost ?? this.isMutedByHost,
      isSelfMuted: isSelfMuted ?? this.isSelfMuted,
      isVideoOn: isVideoOn ?? this.isVideoOn,
      contributionDiamonds: contributionDiamonds ?? this.contributionDiamonds,
    );
  }
}
