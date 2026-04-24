import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Achievement Definition Model
class Achievement {
  final String id;
  final String name;
  final String description;
  final String icon;
  final AchievementCategory category;
  final AchievementTier tier;
  final int requiredProgress;
  final int diamondsReward;
  final int xpReward;
  final String? badgeUrl;
  final bool isSecret;
  final bool isActive;

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    this.tier = AchievementTier.bronze,
    required this.requiredProgress,
    this.diamondsReward = 0,
    this.xpReward = 0,
    this.badgeUrl,
    this.isSecret = false,
    this.isActive = true,
  });

  factory Achievement.fromMap(Map<String, dynamic> map, String id) {
    return Achievement(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      icon: map['icon'] ?? '🏆',
      category: AchievementCategory.values.firstWhere(
        (c) => c.name == map['category'],
        orElse: () => AchievementCategory.social,
      ),
      tier: AchievementTier.values.firstWhere(
        (t) => t.name == map['tier'],
        orElse: () => AchievementTier.bronze,
      ),
      requiredProgress: map['requiredProgress'] ?? 1,
      diamondsReward: map['diamondsReward'] ?? map['diamondsReward'] ?? 0,
      xpReward: map['xpReward'] ?? 0,
      badgeUrl: map['badgeUrl'],
      isSecret: map['isSecret'] ?? false,
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'icon': icon,
      'category': category.name,
      'tier': tier.name,
      'requiredProgress': requiredProgress,
      'diamondsReward': diamondsReward,
      'xpReward': xpReward,
      'badgeUrl': badgeUrl,
      'isSecret': isSecret,
      'isActive': isActive,
    };
  }
}

enum AchievementCategory {
  social,
  streaming,
  gifting,
  profile,
  engagement,
  special,
}

enum AchievementTier {
  bronze,
  silver,
  gold,
  platinum,
  diamond,
}

/// User Achievement Progress Model
class UserAchievement {
  final String oderId;
  final String achievementId;
  final int currentProgress;
  final bool isCompleted;
  final DateTime? completedAt;
  final bool isRewardClaimed;
  final DateTime? claimedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserAchievement({
    required this.oderId,
    required this.achievementId,
    this.currentProgress = 0,
    this.isCompleted = false,
    this.completedAt,
    this.isRewardClaimed = false,
    this.claimedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserAchievement.fromMap(Map<String, dynamic> map, String oderId) {
    return UserAchievement(
      oderId: oderId,
      achievementId: map['achievementId'] ?? '',
      currentProgress: map['currentProgress'] ?? 0,
      isCompleted: map['isCompleted'] ?? false,
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
      isRewardClaimed: map['isRewardClaimed'] ?? false,
      claimedAt: (map['claimedAt'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'achievementId': achievementId,
      'currentProgress': currentProgress,
      'isCompleted': isCompleted,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'isRewardClaimed': isRewardClaimed,
      'claimedAt': claimedAt != null ? Timestamp.fromDate(claimedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  double get progressPercent => currentProgress / 1; // Will be calculated with achievement
}

/// Achievement Notification
class AchievementNotification {
  final Achievement achievement;
  final bool isNewlyCompleted;
  final int newProgress;

  AchievementNotification({
    required this.achievement,
    required this.isNewlyCompleted,
    required this.newProgress,
  });
}

/// Achievements Service
class AchievementsService {
  static final AchievementsService _instance = AchievementsService._internal();
  factory AchievementsService() => _instance;
  AchievementsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream controller for achievement notifications
  final _achievementNotifications = StreamController<AchievementNotification>.broadcast();
  Stream<AchievementNotification> get achievementNotifications => _achievementNotifications.stream;

  // Cache for achievements definitions
  List<Achievement>? _achievementsCache;
  DateTime? _cacheTime;
  static const _cacheDuration = Duration(minutes: 30);

  // Collection references
  CollectionReference get _achievementsCollection =>
      _firestore.collection('achievements');

  CollectionReference _userAchievementsCollection(String oderId) =>
      _firestore.collection('users').doc(oderId).collection('achievements');

  // ============ ACHIEVEMENT DEFINITIONS ============

  /// Get all achievements definitions
  Future<List<Achievement>> getAllAchievements({bool forceRefresh = false}) async {
    

    // Check cache
    if (!forceRefresh &&
        _achievementsCache != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheDuration) {
      
      return _achievementsCache!;
    }

    final snapshot = await _achievementsCollection
        .where('isActive', isEqualTo: true)
        .get();

    _achievementsCache = snapshot.docs
        .map((doc) => Achievement.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
    _cacheTime = DateTime.now();

    
    return _achievementsCache!;
  }

  /// Get achievements by category
  Future<List<Achievement>> getAchievementsByCategory(AchievementCategory category) async {
    final all = await getAllAchievements();
    return all.where((a) => a.category == category).toList();
  }

  /// Initialize default achievements (call once during app setup)
  Future<void> initializeDefaultAchievements() async {
    

    final existingDocs = await _achievementsCollection.limit(1).get();
    if (existingDocs.docs.isNotEmpty) {
      
      return;
    }

    final defaultAchievements = _getDefaultAchievements();
    final batch = _firestore.batch();

    for (final achievement in defaultAchievements) {
      final docRef = _achievementsCollection.doc(achievement.id);
      batch.set(docRef, achievement.toMap());
    }

    await batch.commit();
    
  }

  List<Achievement> _getDefaultAchievements() {
    return [
      // Social Achievements
      const Achievement(
        id: 'first_friend',
        name: 'First Connection',
        description: 'Add your first friend',
        icon: '👋',
        category: AchievementCategory.social,
        tier: AchievementTier.bronze,
        requiredProgress: 1,
        diamondsReward: 50,
        xpReward: 100,
      ),
      const Achievement(
        id: 'social_butterfly',
        name: 'Social Butterfly',
        description: 'Add 10 friends',
        icon: '🦋',
        category: AchievementCategory.social,
        tier: AchievementTier.silver,
        requiredProgress: 10,
        diamondsReward: 200,
        xpReward: 500,
      ),
      const Achievement(
        id: 'popular',
        name: 'Popular',
        description: 'Add 50 friends',
        icon: '⭐',
        category: AchievementCategory.social,
        tier: AchievementTier.gold,
        requiredProgress: 50,
        diamondsReward: 500,
        xpReward: 1000,
      ),
      const Achievement(
        id: 'influencer',
        name: 'Influencer',
        description: 'Add 100 friends',
        icon: '👑',
        category: AchievementCategory.social,
        tier: AchievementTier.platinum,
        requiredProgress: 100,
        diamondsReward: 1000,
        xpReward: 2500,
      ),
      const Achievement(
        id: 'first_chat',
        name: 'Ice Breaker',
        description: 'Send your first message',
        icon: '💬',
        category: AchievementCategory.social,
        tier: AchievementTier.bronze,
        requiredProgress: 1,
        diamondsReward: 30,
        xpReward: 50,
      ),
      const Achievement(
        id: 'chatty',
        name: 'Chatty',
        description: 'Send 100 messages',
        icon: '🗣️',
        category: AchievementCategory.social,
        tier: AchievementTier.silver,
        requiredProgress: 100,
        diamondsReward: 150,
        xpReward: 300,
      ),
      const Achievement(
        id: 'conversation_master',
        name: 'Conversation Master',
        description: 'Send 1000 messages',
        icon: '💎',
        category: AchievementCategory.social,
        tier: AchievementTier.gold,
        requiredProgress: 1000,
        diamondsReward: 500,
        xpReward: 1000,
      ),

      // Streaming Achievements
      const Achievement(
        id: 'first_stream',
        name: 'On Air',
        description: 'Start your first live stream',
        icon: '📺',
        category: AchievementCategory.streaming,
        tier: AchievementTier.bronze,
        requiredProgress: 1,
        diamondsReward: 100,
        xpReward: 200,
      ),
      const Achievement(
        id: 'streamer',
        name: 'Streamer',
        description: 'Complete 10 live streams',
        icon: '🎬',
        category: AchievementCategory.streaming,
        tier: AchievementTier.silver,
        requiredProgress: 10,
        diamondsReward: 300,
        xpReward: 600,
      ),
      const Achievement(
        id: 'star_streamer',
        name: 'Star Streamer',
        description: 'Complete 50 live streams',
        icon: '🌟',
        category: AchievementCategory.streaming,
        tier: AchievementTier.gold,
        requiredProgress: 50,
        diamondsReward: 800,
        xpReward: 1500,
      ),
      const Achievement(
        id: 'first_viewer',
        name: 'Audience Member',
        description: 'Watch your first live stream',
        icon: '👀',
        category: AchievementCategory.streaming,
        tier: AchievementTier.bronze,
        requiredProgress: 1,
        diamondsReward: 20,
        xpReward: 50,
      ),
      const Achievement(
        id: 'stream_fanatic',
        name: 'Stream Fanatic',
        description: 'Watch 100 live streams',
        icon: '📱',
        category: AchievementCategory.streaming,
        tier: AchievementTier.gold,
        requiredProgress: 100,
        diamondsReward: 400,
        xpReward: 800,
      ),

      // Gifting Achievements
      const Achievement(
        id: 'first_gift',
        name: 'Generous',
        description: 'Send your first gift',
        icon: '🎁',
        category: AchievementCategory.gifting,
        tier: AchievementTier.bronze,
        requiredProgress: 1,
        diamondsReward: 50,
        xpReward: 100,
      ),
      const Achievement(
        id: 'gift_giver',
        name: 'Gift Giver',
        description: 'Send 50 gifts',
        icon: '💝',
        category: AchievementCategory.gifting,
        tier: AchievementTier.silver,
        requiredProgress: 50,
        diamondsReward: 250,
        xpReward: 500,
      ),
      const Achievement(
        id: 'big_spender',
        name: 'Big Spender',
        description: 'Spend 10,000 diamonds on gifts',
        icon: '💰',
        category: AchievementCategory.gifting,
        tier: AchievementTier.gold,
        requiredProgress: 10000,
        diamondsReward: 1000,
        xpReward: 2000,
      ),
      const Achievement(
        id: 'gift_received',
        name: 'Appreciated',
        description: 'Receive your first gift',
        icon: '🎀',
        category: AchievementCategory.gifting,
        tier: AchievementTier.bronze,
        requiredProgress: 1,
        diamondsReward: 30,
        xpReward: 50,
      ),

      // Profile Achievements
      const Achievement(
        id: 'complete_profile',
        name: 'All Set',
        description: 'Complete your profile',
        icon: '✅',
        category: AchievementCategory.profile,
        tier: AchievementTier.bronze,
        requiredProgress: 1,
        diamondsReward: 100,
        xpReward: 200,
      ),
      const Achievement(
        id: 'verified',
        name: 'Verified',
        description: 'Get your profile verified',
        icon: '✓',
        category: AchievementCategory.profile,
        tier: AchievementTier.silver,
        requiredProgress: 1,
        diamondsReward: 200,
        xpReward: 400,
      ),
      const Achievement(
        id: 'photo_album',
        name: 'Photo Album',
        description: 'Upload 10 photos',
        icon: '📸',
        category: AchievementCategory.profile,
        tier: AchievementTier.bronze,
        requiredProgress: 10,
        diamondsReward: 80,
        xpReward: 150,
      ),
      const Achievement(
        id: 'vip_member',
        name: 'VIP Member',
        description: 'Become a VIP member',
        icon: '👑',
        category: AchievementCategory.profile,
        tier: AchievementTier.gold,
        requiredProgress: 1,
        diamondsReward: 500,
        xpReward: 1000,
      ),

      // Engagement Achievements
      const Achievement(
        id: 'first_like',
        name: 'Liker',
        description: 'Like your first post',
        icon: '❤️',
        category: AchievementCategory.engagement,
        tier: AchievementTier.bronze,
        requiredProgress: 1,
        diamondsReward: 20,
        xpReward: 30,
      ),
      const Achievement(
        id: 'first_post',
        name: 'Creator',
        description: 'Create your first post',
        icon: '📝',
        category: AchievementCategory.engagement,
        tier: AchievementTier.bronze,
        requiredProgress: 1,
        diamondsReward: 50,
        xpReward: 100,
      ),
      const Achievement(
        id: 'content_creator',
        name: 'Content Creator',
        description: 'Create 20 posts',
        icon: '🎨',
        category: AchievementCategory.engagement,
        tier: AchievementTier.silver,
        requiredProgress: 20,
        diamondsReward: 200,
        xpReward: 400,
      ),
      const Achievement(
        id: 'daily_login_7',
        name: 'Weekly Warrior',
        description: 'Login 7 days in a row',
        icon: '📅',
        category: AchievementCategory.engagement,
        tier: AchievementTier.bronze,
        requiredProgress: 7,
        diamondsReward: 100,
        xpReward: 200,
      ),
      const Achievement(
        id: 'daily_login_30',
        name: 'Monthly Master',
        description: 'Login 30 days in a row',
        icon: '🗓️',
        category: AchievementCategory.engagement,
        tier: AchievementTier.silver,
        requiredProgress: 30,
        diamondsReward: 500,
        xpReward: 1000,
      ),
      const Achievement(
        id: 'daily_login_100',
        name: 'Dedicated',
        description: 'Login 100 days in a row',
        icon: '🏆',
        category: AchievementCategory.engagement,
        tier: AchievementTier.gold,
        requiredProgress: 100,
        diamondsReward: 2000,
        xpReward: 5000,
      ),

      // Special Achievements
      const Achievement(
        id: 'early_adopter',
        name: 'Early Adopter',
        description: 'Join during launch period',
        icon: '🚀',
        category: AchievementCategory.special,
        tier: AchievementTier.platinum,
        requiredProgress: 1,
        diamondsReward: 500,
        xpReward: 1000,
        isSecret: true,
      ),
      const Achievement(
        id: 'night_owl',
        name: 'Night Owl',
        description: 'Be active between 12 AM and 4 AM',
        icon: '🦉',
        category: AchievementCategory.special,
        tier: AchievementTier.bronze,
        requiredProgress: 5,
        diamondsReward: 100,
        xpReward: 200,
        isSecret: true,
      ),
      const Achievement(
        id: 'top_gifter',
        name: 'Top Gifter',
        description: 'Be in top 10 gifters for a week',
        icon: '💎',
        category: AchievementCategory.special,
        tier: AchievementTier.diamond,
        requiredProgress: 1,
        diamondsReward: 2000,
        xpReward: 5000,
      ),
    ];
  }

  // ============ USER ACHIEVEMENTS ============

  /// Get user's achievements with progress
  Future<List<UserAchievementWithDetails>> getUserAchievements(String oderId) async {
    

    final achievements = await getAllAchievements();
    final userAchievementsSnapshot = await _userAchievementsCollection(oderId).get();

    final userAchievementsMap = <String, UserAchievement>{};
    for (final doc in userAchievementsSnapshot.docs) {
      final ua = UserAchievement.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      userAchievementsMap[ua.achievementId] = ua;
    }

    final result = <UserAchievementWithDetails>[];
    for (final achievement in achievements) {
      // Skip secret achievements that haven't been started
      if (achievement.isSecret && !userAchievementsMap.containsKey(achievement.id)) {
        continue;
      }

      final userProgress = userAchievementsMap[achievement.id];
      result.add(UserAchievementWithDetails(
        achievement: achievement,
        userProgress: userProgress,
        currentProgress: userProgress?.currentProgress ?? 0,
        isCompleted: userProgress?.isCompleted ?? false,
        isRewardClaimed: userProgress?.isRewardClaimed ?? false,
      ));
    }

    // Sort: completed unclaimed first, then in progress, then completed claimed
    result.sort((a, b) {
      if (a.isCompleted && !a.isRewardClaimed) return -1;
      if (b.isCompleted && !b.isRewardClaimed) return 1;
      if (a.isCompleted && b.isCompleted) return 0;
      if (a.isCompleted) return 1;
      if (b.isCompleted) return -1;
      return b.progressPercent.compareTo(a.progressPercent);
    });

    
    return result;
  }

  /// Update achievement progress
  Future<void> updateProgress({
    required String oderId,
    required String achievementId,
    required int progressIncrement,
  }) async {
    

    final achievements = await getAllAchievements();
    final achievement = achievements.firstWhere(
      (a) => a.id == achievementId,
      orElse: () => throw Exception('Achievement not found'),
    );

    final docRef = _userAchievementsCollection(oderId).doc(achievementId);
    final docSnapshot = await docRef.get();

    int newProgress;
    bool wasCompleted = false;
    bool nowCompleted = false;

    if (docSnapshot.exists) {
      final current = UserAchievement.fromMap(
        docSnapshot.data() as Map<String, dynamic>,
        docSnapshot.id,
      );
      wasCompleted = current.isCompleted;
      newProgress = current.currentProgress + progressIncrement;
    } else {
      newProgress = progressIncrement;
    }

    nowCompleted = newProgress >= achievement.requiredProgress;

    final updateData = <String, dynamic>{
      'achievementId': achievementId,
      'currentProgress': newProgress,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!wasCompleted && nowCompleted) {
      updateData['isCompleted'] = true;
      updateData['completedAt'] = FieldValue.serverTimestamp();
    }

    if (!docSnapshot.exists) {
      updateData['createdAt'] = FieldValue.serverTimestamp();
      updateData['isRewardClaimed'] = false;
    }

    await docRef.set(updateData, SetOptions(merge: true));

    // Notify about achievement progress/completion
    _achievementNotifications.add(AchievementNotification(
      achievement: achievement,
      isNewlyCompleted: !wasCompleted && nowCompleted,
      newProgress: newProgress,
    ));

    
  }

  /// Set absolute progress (for achievements like "complete profile")
  Future<void> setProgress({
    required String oderId,
    required String achievementId,
    required int progress,
  }) async {
    

    final achievements = await getAllAchievements();
    final achievement = achievements.firstWhere(
      (a) => a.id == achievementId,
      orElse: () => throw Exception('Achievement not found'),
    );

    final docRef = _userAchievementsCollection(oderId).doc(achievementId);
    final docSnapshot = await docRef.get();

    bool wasCompleted = false;
    if (docSnapshot.exists) {
      final current = UserAchievement.fromMap(
        docSnapshot.data() as Map<String, dynamic>,
        docSnapshot.id,
      );
      wasCompleted = current.isCompleted;
    }

    final nowCompleted = progress >= achievement.requiredProgress;

    final updateData = <String, dynamic>{
      'achievementId': achievementId,
      'currentProgress': progress,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!wasCompleted && nowCompleted) {
      updateData['isCompleted'] = true;
      updateData['completedAt'] = FieldValue.serverTimestamp();
    }

    if (!docSnapshot.exists) {
      updateData['createdAt'] = FieldValue.serverTimestamp();
      updateData['isRewardClaimed'] = false;
    }

    await docRef.set(updateData, SetOptions(merge: true));

    if (!wasCompleted && nowCompleted) {
      _achievementNotifications.add(AchievementNotification(
        achievement: achievement,
        isNewlyCompleted: true,
        newProgress: progress,
      ));
    }

    
  }

  /// Claim achievement reward
  Future<ClaimRewardResult> claimReward({
    required String oderId,
    required String achievementId,
  }) async {
    

    final achievements = await getAllAchievements();
    final achievement = achievements.firstWhere(
      (a) => a.id == achievementId,
      orElse: () => throw Exception('Achievement not found'),
    );

    final docRef = _userAchievementsCollection(oderId).doc(achievementId);
    final docSnapshot = await docRef.get();

    if (!docSnapshot.exists) {
      throw Exception('Achievement progress not found');
    }

    final userAchievement = UserAchievement.fromMap(
      docSnapshot.data() as Map<String, dynamic>,
      docSnapshot.id,
    );

    if (!userAchievement.isCompleted) {
      throw Exception('Achievement not completed');
    }

    if (userAchievement.isRewardClaimed) {
      throw Exception('Reward already claimed');
    }

    // Update achievement
    await docRef.update({
      'isRewardClaimed': true,
      'claimedAt': FieldValue.serverTimestamp(),
    });

    // Add diamonds to user
    if (achievement.diamondsReward > 0) {
      await _firestore.collection('users').doc(oderId).update({
        'diamonds': FieldValue.increment(achievement.diamondsReward),
      });
    }

    // Add XP to user
    if (achievement.xpReward > 0) {
      await _firestore.collection('users').doc(oderId).update({
        'xp': FieldValue.increment(achievement.xpReward),
      });
    }

    

    return ClaimRewardResult(
      diamondsEarned: achievement.diamondsReward,
      xpEarned: achievement.xpReward,
      badgeUrl: achievement.badgeUrl,
    );
  }

  /// Get completed achievements count
  Future<int> getCompletedCount(String oderId) async {
    final snapshot = await _userAchievementsCollection(oderId)
        .where('isCompleted', isEqualTo: true)
        .get();
    return snapshot.docs.length;
  }

  /// Get unclaimed rewards count
  Future<int> getUnclaimedRewardsCount(String oderId) async {
    final snapshot = await _userAchievementsCollection(oderId)
        .where('isCompleted', isEqualTo: true)
        .where('isRewardClaimed', isEqualTo: false)
        .get();
    return snapshot.docs.length;
  }

  /// Get user's achievement statistics
  Future<AchievementStats> getUserStats(String oderId) async {
    final userAchievements = await getUserAchievements(oderId);
    final allAchievements = await getAllAchievements();

    int completed = 0;
    int unclaimed = 0;
    int totalDiamonds = 0;
    int totalXp = 0;

    for (final ua in userAchievements) {
      if (ua.isCompleted) {
        completed++;
        if (!ua.isRewardClaimed) {
          unclaimed++;
        } else {
          totalDiamonds += ua.achievement.diamondsReward;
          totalXp += ua.achievement.xpReward;
        }
      }
    }

    return AchievementStats(
      total: allAchievements.where((a) => !a.isSecret).length,
      completed: completed,
      unclaimed: unclaimed,
      totalDiamondsEarned: totalDiamonds,
      totalXpEarned: totalXp,
    );
  }

  // ============ TRIGGER HELPERS ============

  /// Call when user sends a message
  Future<void> onMessageSent(String oderId) async {
    await updateProgress(
      oderId: oderId,
      achievementId: 'first_chat',
      progressIncrement: 1,
    );
    await updateProgress(
      oderId: oderId,
      achievementId: 'chatty',
      progressIncrement: 1,
    );
    await updateProgress(
      oderId: oderId,
      achievementId: 'conversation_master',
      progressIncrement: 1,
    );
  }

  /// Call when user adds a friend
  Future<void> onFriendAdded(String oderId) async {
    await updateProgress(
      oderId: oderId,
      achievementId: 'first_friend',
      progressIncrement: 1,
    );
    await updateProgress(
      oderId: oderId,
      achievementId: 'social_butterfly',
      progressIncrement: 1,
    );
    await updateProgress(
      oderId: oderId,
      achievementId: 'popular',
      progressIncrement: 1,
    );
    await updateProgress(
      oderId: oderId,
      achievementId: 'influencer',
      progressIncrement: 1,
    );
  }

  /// Call when user starts a stream
  Future<void> onStreamStarted(String oderId) async {
    await updateProgress(
      oderId: oderId,
      achievementId: 'first_stream',
      progressIncrement: 1,
    );
    await updateProgress(
      oderId: oderId,
      achievementId: 'streamer',
      progressIncrement: 1,
    );
    await updateProgress(
      oderId: oderId,
      achievementId: 'star_streamer',
      progressIncrement: 1,
    );
  }

  /// Call when user watches a stream
  Future<void> onStreamWatched(String oderId) async {
    await updateProgress(
      oderId: oderId,
      achievementId: 'first_viewer',
      progressIncrement: 1,
    );
    await updateProgress(
      oderId: oderId,
      achievementId: 'stream_fanatic',
      progressIncrement: 1,
    );
  }

  /// Call when user sends a gift
  Future<void> onGiftSent(String oderId, int giftValue) async {
    await updateProgress(
      oderId: oderId,
      achievementId: 'first_gift',
      progressIncrement: 1,
    );
    await updateProgress(
      oderId: oderId,
      achievementId: 'gift_giver',
      progressIncrement: 1,
    );
    await updateProgress(
      oderId: oderId,
      achievementId: 'big_spender',
      progressIncrement: giftValue,
    );
  }

  /// Call when user receives a gift
  Future<void> onGiftReceived(String oderId) async {
    await updateProgress(
      oderId: oderId,
      achievementId: 'gift_received',
      progressIncrement: 1,
    );
  }

  /// Call when user creates a post
  Future<void> onPostCreated(String oderId) async {
    await updateProgress(
      oderId: oderId,
      achievementId: 'first_post',
      progressIncrement: 1,
    );
    await updateProgress(
      oderId: oderId,
      achievementId: 'content_creator',
      progressIncrement: 1,
    );
  }

  /// Call when user likes a post
  Future<void> onPostLiked(String oderId) async {
    await updateProgress(
      oderId: oderId,
      achievementId: 'first_like',
      progressIncrement: 1,
    );
  }

  /// Call when user logs in (for streak achievements)
  Future<void> onDailyLogin(String oderId, int currentStreak) async {
    await setProgress(
      oderId: oderId,
      achievementId: 'daily_login_7',
      progress: currentStreak,
    );
    await setProgress(
      oderId: oderId,
      achievementId: 'daily_login_30',
      progress: currentStreak,
    );
    await setProgress(
      oderId: oderId,
      achievementId: 'daily_login_100',
      progress: currentStreak,
    );
  }

  /// Dispose
  void dispose() {
    _achievementNotifications.close();
  }
}

/// Combined model for display
class UserAchievementWithDetails {
  final Achievement achievement;
  final UserAchievement? userProgress;
  final int currentProgress;
  final bool isCompleted;
  final bool isRewardClaimed;

  UserAchievementWithDetails({
    required this.achievement,
    this.userProgress,
    required this.currentProgress,
    required this.isCompleted,
    required this.isRewardClaimed,
  });

  double get progressPercent =>
      (currentProgress / achievement.requiredProgress).clamp(0.0, 1.0);
}

/// Claim reward result
class ClaimRewardResult {
  final int diamondsEarned;
  final int xpEarned;
  final String? badgeUrl;

  ClaimRewardResult({
    required this.diamondsEarned,
    required this.xpEarned,
    this.badgeUrl,
  });
}

/// Achievement stats
class AchievementStats {
  final int total;
  final int completed;
  final int unclaimed;
  final int totalDiamondsEarned;
  final int totalXpEarned;

  AchievementStats({
    required this.total,
    required this.completed,
    required this.unclaimed,
    required this.totalDiamondsEarned,
    required this.totalXpEarned,
  });

  double get completionPercent => total > 0 ? completed / total : 0;
}
