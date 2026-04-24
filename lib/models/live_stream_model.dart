import 'package:cloud_firestore/cloud_firestore.dart';

class LiveStreamModel {
  final String streamId;
  final String hostId;
  final String hostName;
  final String hostPhoto;
  final String title;
  final String? description;
  final int viewerCount;
  final bool isActive;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String channelName;
  final String? thumbnailUrl;
  final List<String> tags;
  final int totalDiamondsReceived;
  final int totalGiftsReceived;
  final bool isPremium;
  final int entryFee;
  final String premiumMode; // 'none', 'entrance', 'minute'

  LiveStreamModel({
    required this.streamId,
    required this.hostId,
    required this.hostName,
    required this.hostPhoto,
    required this.title,
    this.description,
    this.viewerCount = 0,
    this.isActive = true,
    required this.startedAt,
    this.endedAt,
    required this.channelName,
    this.thumbnailUrl,
    this.tags = const [],
    this.totalDiamondsReceived = 0,
    this.totalGiftsReceived = 0,
    this.isPremium = false,
    this.entryFee = 0,
    this.premiumMode = 'none',
  });

  Map<String, dynamic> toMap() {
    
    
    
    
    
    

    return {
      'streamId': streamId,
      'hostId': hostId,
      'hostName': hostName,
      'hostPhoto': hostPhoto,
      'title': title,
      'description': description,
      'viewerCount': viewerCount,
      'isActive': isActive,
      'startedAt': Timestamp.fromDate(startedAt),
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'channelName': channelName,
      'thumbnailUrl': thumbnailUrl,
      'tags': tags,
      'totalDiamondsReceived': totalDiamondsReceived,
      'totalGiftsReceived': totalGiftsReceived,
      'isPremium': isPremium,
      'entryFee': entryFee,
      'premiumMode': premiumMode,
    };
  }

  factory LiveStreamModel.fromMap(Map<String, dynamic> map) {
    
    
    

    return LiveStreamModel(
      streamId: map['streamId'] ?? '',
      hostId: map['hostId'] ?? '',
      hostName: map['hostName'] ?? '',
      hostPhoto: map['hostPhoto'] ?? '',
      title: map['title'] ?? '',
      description: map['description'],
      viewerCount: map['viewerCount'] ?? 0,
      isActive: map['isActive'] ?? true,
      startedAt: (map['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endedAt: (map['endedAt'] as Timestamp?)?.toDate(),
      channelName: map['channelName'] ?? '',
      thumbnailUrl: map['thumbnailUrl'],
      tags: List<String>.from(map['tags'] ?? []),
      totalDiamondsReceived: (map['totalDiamondsReceived'] ?? map['totalCoinsReceived'] ?? 0) as int,
      totalGiftsReceived: map['totalGiftsReceived'] ?? 0,
      isPremium: map['isPremium'] ?? false,
      entryFee: map['entryFee'] ?? 0,
      premiumMode: map['premiumMode'] ?? 'none',
    );
  }

  factory LiveStreamModel.fromSnapshot(DocumentSnapshot doc) {
    
    

    final data = doc.data() as Map<String, dynamic>;
    return LiveStreamModel.fromMap(data);
  }

  LiveStreamModel copyWith({
    String? streamId,
    String? hostId,
    String? hostName,
    String? hostPhoto,
    String? title,
    String? description,
    int? viewerCount,
    bool? isActive,
    DateTime? startedAt,
    DateTime? endedAt,
    String? channelName,
    String? thumbnailUrl,
    List<String>? tags,
    int? totalDiamondsReceived,
    int? totalGiftsReceived,
    bool? isPremium,
    int? entryFee,
    String? premiumMode,
  }) {
    

    return LiveStreamModel(
      streamId: streamId ?? this.streamId,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      hostPhoto: hostPhoto ?? this.hostPhoto,
      title: title ?? this.title,
      description: description ?? this.description,
      viewerCount: viewerCount ?? this.viewerCount,
      isActive: isActive ?? this.isActive,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      channelName: channelName ?? this.channelName,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      tags: tags ?? this.tags,
      totalDiamondsReceived: totalDiamondsReceived ?? this.totalDiamondsReceived,
      totalGiftsReceived: totalGiftsReceived ?? this.totalGiftsReceived,
      isPremium: isPremium ?? this.isPremium,
      entryFee: entryFee ?? this.entryFee,
      premiumMode: premiumMode ?? this.premiumMode,
    );
  }
}
