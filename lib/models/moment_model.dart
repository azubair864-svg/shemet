import 'package:cloud_firestore/cloud_firestore.dart';

/// ⭐⭐⭐ PRODUCTION-READY MOMENT MODEL ⭐⭐⭐
/// Complete model for social media posts/moments
/// Features: Photos, Videos, Likes, Comments, Shares, Privacy
class MomentModel {
  final String momentId;
  final String userId;
  final String userName;
  final String? userPhoto;
  final int userLevel;
  final bool userIsVerified;
  final bool userIsVip;

  // Content
  final String? text;
  final List<String> mediaUrls; // Photos or video URLs
  final String mediaType; // 'photo', 'video', 'text'
  final String? thumbnailUrl; // For videos
  final int? videoDuration; // In seconds

  // Location
  final String? location;
  final GeoPoint? geoLocation;

  // Stats
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final int viewsCount;

  // Engagement tracking
  final List<String> likedBy; // User IDs who liked
  final bool isLikedByCurrentUser;

  // Privacy & Settings
  final String privacy; // 'public', 'followers', 'private'
  final bool commentsEnabled;
  final bool isReported;
  final bool isHidden;

  // Tags & Mentions
  final List<String> hashtags;
  final List<String> mentionedUserIds;

  // Timestamps
  final DateTime createdAt;
  final DateTime? updatedAt;

  MomentModel({
    required this.momentId,
    required this.userId,
    required this.userName,
    this.userPhoto,
    this.userLevel = 0,
    this.userIsVerified = false,
    this.userIsVip = false,
    this.text,
    this.mediaUrls = const [],
    this.mediaType = 'text',
    this.thumbnailUrl,
    this.videoDuration,
    this.location,
    this.geoLocation,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.viewsCount = 0,
    this.likedBy = const [],
    this.isLikedByCurrentUser = false,
    this.privacy = 'public',
    this.commentsEnabled = true,
    this.isReported = false,
    this.isHidden = false,
    this.hashtags = const [],
    this.mentionedUserIds = const [],
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    
    
    
    
    
    
    

    return {
      'momentId': momentId,
      'userId': userId,
      'userName': userName,
      'userPhoto': userPhoto,
      'userLevel': userLevel,
      'userIsVerified': userIsVerified,
      'userIsVip': userIsVip,
      'text': text,
      'mediaUrls': mediaUrls,
      'mediaType': mediaType,
      'thumbnailUrl': thumbnailUrl,
      'videoDuration': videoDuration,
      'location': location,
      'geoLocation': geoLocation,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'sharesCount': sharesCount,
      'viewsCount': viewsCount,
      'likedBy': likedBy,
      'privacy': privacy,
      'commentsEnabled': commentsEnabled,
      'isReported': isReported,
      'isHidden': isHidden,
      'hashtags': hashtags,
      'mentionedUserIds': mentionedUserIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory MomentModel.fromMap(Map<String, dynamic> map, {String? currentUserId}) {
    
    
    
    
    

    final likedByList = List<String>.from(map['likedBy'] ?? []);

    return MomentModel(
      momentId: map['momentId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userPhoto: map['userPhoto'],
      userLevel: map['userLevel'] ?? 0,
      userIsVerified: map['userIsVerified'] ?? false,
      userIsVip: map['userIsVip'] ?? false,
      text: map['text'],
      mediaUrls: List<String>.from(map['mediaUrls'] ?? []),
      mediaType: map['mediaType'] ?? 'text',
      thumbnailUrl: map['thumbnailUrl'],
      videoDuration: map['videoDuration'],
      location: map['location'],
      geoLocation: map['geoLocation'],
      likesCount: map['likesCount'] ?? 0,
      commentsCount: map['commentsCount'] ?? 0,
      sharesCount: map['sharesCount'] ?? 0,
      viewsCount: map['viewsCount'] ?? 0,
      likedBy: likedByList,
      isLikedByCurrentUser: currentUserId != null && likedByList.contains(currentUserId),
      privacy: map['privacy'] ?? 'public',
      commentsEnabled: map['commentsEnabled'] ?? true,
      isReported: map['isReported'] ?? false,
      isHidden: map['isHidden'] ?? false,
      hashtags: List<String>.from(map['hashtags'] ?? []),
      mentionedUserIds: List<String>.from(map['mentionedUserIds'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory MomentModel.fromSnapshot(DocumentSnapshot doc, {String? currentUserId}) {
    
    

    final data = doc.data() as Map<String, dynamic>;
    return MomentModel.fromMap({...data, 'momentId': doc.id}, currentUserId: currentUserId);
  }

  MomentModel copyWith({
    String? momentId,
    String? userId,
    String? userName,
    String? userPhoto,
    int? userLevel,
    bool? userIsVerified,
    bool? userIsVip,
    String? text,
    List<String>? mediaUrls,
    String? mediaType,
    String? thumbnailUrl,
    int? videoDuration,
    String? location,
    GeoPoint? geoLocation,
    int? likesCount,
    int? commentsCount,
    int? sharesCount,
    int? viewsCount,
    List<String>? likedBy,
    bool? isLikedByCurrentUser,
    String? privacy,
    bool? commentsEnabled,
    bool? isReported,
    bool? isHidden,
    List<String>? hashtags,
    List<String>? mentionedUserIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MomentModel(
      momentId: momentId ?? this.momentId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userPhoto: userPhoto ?? this.userPhoto,
      userLevel: userLevel ?? this.userLevel,
      userIsVerified: userIsVerified ?? this.userIsVerified,
      userIsVip: userIsVip ?? this.userIsVip,
      text: text ?? this.text,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      mediaType: mediaType ?? this.mediaType,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      videoDuration: videoDuration ?? this.videoDuration,
      location: location ?? this.location,
      geoLocation: geoLocation ?? this.geoLocation,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      viewsCount: viewsCount ?? this.viewsCount,
      likedBy: likedBy ?? this.likedBy,
      isLikedByCurrentUser: isLikedByCurrentUser ?? this.isLikedByCurrentUser,
      privacy: privacy ?? this.privacy,
      commentsEnabled: commentsEnabled ?? this.commentsEnabled,
      isReported: isReported ?? this.isReported,
      isHidden: isHidden ?? this.isHidden,
      hashtags: hashtags ?? this.hashtags,
      mentionedUserIds: mentionedUserIds ?? this.mentionedUserIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if moment has media
  bool get hasMedia => mediaUrls.isNotEmpty;

  /// Check if moment is a video
  bool get isVideo => mediaType == 'video';

  /// Check if moment is photo(s)
  bool get isPhoto => mediaType == 'photo';

  /// Get time ago string
  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }

  /// Format engagement count
  static String formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  String get formattedLikes => formatCount(likesCount);
  String get formattedComments => formatCount(commentsCount);
  String get formattedShares => formatCount(sharesCount);
  String get formattedViews => formatCount(viewsCount);
}

/// ⭐ Comment Model for Moments
class MomentCommentModel {
  final String commentId;
  final String momentId;
  final String userId;
  final String userName;
  final String? userPhoto;
  final int userLevel;
  final bool userIsVerified;
  final String text;
  final int likesCount;
  final List<String> likedBy;
  final String? replyToCommentId;
  final String? replyToUserName;
  final int repliesCount;
  final DateTime createdAt;

  MomentCommentModel({
    required this.commentId,
    required this.momentId,
    required this.userId,
    required this.userName,
    this.userPhoto,
    this.userLevel = 0,
    this.userIsVerified = false,
    required this.text,
    this.likesCount = 0,
    this.likedBy = const [],
    this.replyToCommentId,
    this.replyToUserName,
    this.repliesCount = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    

    return {
      'commentId': commentId,
      'momentId': momentId,
      'userId': userId,
      'userName': userName,
      'userPhoto': userPhoto,
      'userLevel': userLevel,
      'userIsVerified': userIsVerified,
      'text': text,
      'likesCount': likesCount,
      'likedBy': likedBy,
      'replyToCommentId': replyToCommentId,
      'replyToUserName': replyToUserName,
      'repliesCount': repliesCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory MomentCommentModel.fromMap(Map<String, dynamic> map) {
    return MomentCommentModel(
      commentId: map['commentId'] ?? '',
      momentId: map['momentId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userPhoto: map['userPhoto'],
      userLevel: map['userLevel'] ?? 0,
      userIsVerified: map['userIsVerified'] ?? false,
      text: map['text'] ?? '',
      likesCount: map['likesCount'] ?? 0,
      likedBy: List<String>.from(map['likedBy'] ?? []),
      replyToCommentId: map['replyToCommentId'],
      replyToUserName: map['replyToUserName'],
      repliesCount: map['repliesCount'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory MomentCommentModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MomentCommentModel.fromMap({...data, 'commentId': doc.id});
  }

  /// Get time ago string
  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${(diff.inDays / 7).floor()}w';
  }
}
