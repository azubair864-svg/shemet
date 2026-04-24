class PartyRoomModel {
  final String roomId;
  final String hostId;
  final String hostName;
  final String hostPhoto;
  final int hostLevel;
  final String roomName;
  final String category;
  final int maxSeats;
  final List<String> participants;
  final Map<String, SeatData> seats; // Seat index -> SeatData
  final int participantCount;
  final bool isActive;
  final int totalDiamondsReceived;
  final DateTime createdAt;
  final String country;
  final String countryFlag;
  final String coverPhoto;
  final String backgroundTheme;
  final String password;
  final List<TopContributor> topContributors;
  final int followersCount;
  final RoomSettings settings;

  PartyRoomModel({
    required this.roomId,
    required this.hostId,
    required this.hostName,
    required this.hostPhoto,
    required this.hostLevel,
    required this.roomName,
    required this.category,
    this.maxSeats = 12,
    required this.participants,
    this.seats = const {},
    required this.participantCount,
    this.isActive = true,
    this.totalDiamondsReceived = 0,
    required this.createdAt,
    required this.country,
    required this.countryFlag,
    this.coverPhoto = '',
    this.backgroundTheme = 'purple',
    this.password = '',
    this.topContributors = const [],
    this.followersCount = 0,
    RoomSettings? settings,
  }) : settings = settings ?? RoomSettings();

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'hostId': hostId,
      'hostName': hostName,
      'hostPhoto': hostPhoto,
      'hostLevel': hostLevel,
      'roomName': roomName,
      'category': category,
      'maxSeats': maxSeats,
      'participants': participants,
      'seats': seats.map((key, value) => MapEntry(key, value.toMap())),
      'participantCount': participantCount,
      'isActive': isActive,
      'totalDiamondsReceived': totalDiamondsReceived,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'country': country,
      'countryFlag': countryFlag,
      'coverPhoto': coverPhoto,
      'backgroundTheme': backgroundTheme,
      'password': password,
      'topContributors': topContributors.map((c) => c.toMap()).toList(),
      'followersCount': followersCount,
      'settings': settings.toMap(),
    };
  }

  factory PartyRoomModel.fromMap(Map<String, dynamic> map) {
    return PartyRoomModel(
      roomId: map['roomId'] as String? ?? '',
      hostId: map['hostId'] as String? ?? '',
      hostName: map['hostName'] as String? ?? '',
      hostPhoto: map['hostPhoto'] as String? ?? '',
      hostLevel: map['hostLevel'] as int? ?? 1,
      roomName: map['roomName'] as String? ?? 'Party Room',
      category: map['category'] as String? ?? 'Chat',
      maxSeats: map['maxSeats'] as int? ?? 12,
      participants: List<String>.from(map['participants'] ?? []),
      seats: (map['seats'] as Map<String, dynamic>? ?? {}).map(
            (key, value) => MapEntry(key, SeatData.fromMap(value as Map<String, dynamic>)),
      ),
      participantCount: map['participantCount'] as int? ?? 0,
      isActive: map['isActive'] as bool? ?? true,
      totalDiamondsReceived: (map['totalDiamondsReceived'] ?? map['earnings'] ?? 0) as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int? ?? 0),
      country: map['country'] as String? ?? 'Unknown',
      countryFlag: map['countryFlag'] as String? ?? '🌍',
      coverPhoto: map['coverPhoto'] as String? ?? '',
      backgroundTheme: map['backgroundTheme'] as String? ?? 'purple',
      password: map['password'] as String? ?? '',
      topContributors: (map['topContributors'] as List? ?? [])
          .map((c) => TopContributor.fromMap(c as Map<String, dynamic>))
          .toList(),
      followersCount: map['followersCount'] as int? ?? 0,
      settings: map['settings'] != null
          ? RoomSettings.fromMap(map['settings'] as Map<String, dynamic>)
          : RoomSettings(),
    );
  }
}

class SeatData {
  final String? userId;
  final int contributionDiamonds;
  final bool isMicOn;
  final bool isCameraOn;
  final DateTime? joinedAt;

  SeatData({
    this.userId,
    this.contributionDiamonds = 0,
    this.isMicOn = true,
    this.isCameraOn = false,
    this.joinedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'contributionDiamonds': contributionDiamonds,
      'isMicOn': isMicOn,
      'isCameraOn': isCameraOn,
      'joinedAt': joinedAt?.millisecondsSinceEpoch,
    };
  }

  factory SeatData.fromMap(Map<String, dynamic> map) {
    return SeatData(
      userId: map['userId'] as String?,
      contributionDiamonds: (map['contributionDiamonds'] ?? map['contributionCoins'] ?? 0) as int,
      isMicOn: map['isMicOn'] as bool? ?? true,
      isCameraOn: map['isCameraOn'] as bool? ?? false,
      joinedAt: map['joinedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['joinedAt'] as int)
          : null,
    );
  }
}

class TopContributor {
  final String userId;
  final String userName;
  final String userPhoto;
  final int totalDiamonds;
  final int rank;

  TopContributor({
    required this.userId,
    required this.userName,
    required this.userPhoto,
    required this.totalDiamonds,
    required this.rank,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userPhoto': userPhoto,
      'totalDiamonds': totalDiamonds,
      'rank': rank,
    };
  }

  factory TopContributor.fromMap(Map<String, dynamic> map) {
    return TopContributor(
      userId: map['userId'] as String? ?? '',
      userName: map['userName'] as String? ?? '',
      userPhoto: map['userPhoto'] as String? ?? '',
      totalDiamonds: (map['totalDiamonds'] ?? map['totalCoins'] ?? 0) as int,
      rank: map['rank'] as int? ?? 0,
    );
  }
}

class RoomSettings {
  final bool allowGuests;
  final bool autoMuteNewUsers;
  final int minLevelToSpeak;
  final bool showEntranceEffects;
  final bool showGiftAnimations;
  final String musicUrl;
  final bool isMusicPlaying;

  RoomSettings({
    this.allowGuests = true,
    this.autoMuteNewUsers = false,
    this.minLevelToSpeak = 0,
    this.showEntranceEffects = true,
    this.showGiftAnimations = true,
    this.musicUrl = '',
    this.isMusicPlaying = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'allowGuests': allowGuests,
      'autoMuteNewUsers': autoMuteNewUsers,
      'minLevelToSpeak': minLevelToSpeak,
      'showEntranceEffects': showEntranceEffects,
      'showGiftAnimations': showGiftAnimations,
      'musicUrl': musicUrl,
      'isMusicPlaying': isMusicPlaying,
    };
  }

  factory RoomSettings.fromMap(Map<String, dynamic> map) {
    return RoomSettings(
      allowGuests: map['allowGuests'] as bool? ?? true,
      autoMuteNewUsers: map['autoMuteNewUsers'] as bool? ?? false,
      minLevelToSpeak: map['minLevelToSpeak'] as int? ?? 0,
      showEntranceEffects: map['showEntranceEffects'] as bool? ?? true,
      showGiftAnimations: map['showGiftAnimations'] as bool? ?? true,
      musicUrl: map['musicUrl'] as String? ?? '',
      isMusicPlaying: map['isMusicPlaying'] as bool? ?? false,
    );
  }
}