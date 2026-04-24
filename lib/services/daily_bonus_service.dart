import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Daily Bonus Reward Model
class DailyReward {
  final int day;
  final int diamonds;
  final int xp;
  final String? giftId;
  final String? specialReward;
  final bool isMilestone;

  const DailyReward({
    required this.day,
    required this.diamonds,
    this.xp = 0,
    this.giftId,
    this.specialReward,
    this.isMilestone = false,
  });
}

/// User Login Streak Model
class LoginStreak {
  final String oderId;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastLoginDate;
  final int totalLogins;
  final DateTime? streakStartDate;
  final List<int> claimedDays;
  final int currentWeek;

  LoginStreak({
    required this.oderId,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastLoginDate,
    this.totalLogins = 0,
    this.streakStartDate,
    this.claimedDays = const [],
    this.currentWeek = 1,
  });

  factory LoginStreak.fromMap(Map<String, dynamic> map, String oderId) {
    return LoginStreak(
      oderId: oderId,
      currentStreak: map['currentStreak'] ?? 0,
      longestStreak: map['longestStreak'] ?? 0,
      lastLoginDate: (map['lastLoginDate'] as Timestamp?)?.toDate(),
      totalLogins: map['totalLogins'] ?? 0,
      streakStartDate: (map['streakStartDate'] as Timestamp?)?.toDate(),
      claimedDays: List<int>.from(map['claimedDays'] ?? []),
      currentWeek: map['currentWeek'] ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'lastLoginDate': lastLoginDate != null
          ? Timestamp.fromDate(lastLoginDate!)
          : null,
      'totalLogins': totalLogins,
      'streakStartDate': streakStartDate != null
          ? Timestamp.fromDate(streakStartDate!)
          : null,
      'claimedDays': claimedDays,
      'currentWeek': currentWeek,
    };
  }

  bool get canClaimToday {
    if (lastLoginDate == null) return true;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastLogin = DateTime(
      lastLoginDate!.year,
      lastLoginDate!.month,
      lastLoginDate!.day,
    );
    return today.isAfter(lastLogin);
  }

  int get todayRewardDay {
    // Returns 1-7 for the current week
    return ((currentStreak) % 7) + 1;
  }
}

/// Claim Result
class ClaimResult {
  final bool success;
  final int diamondsEarned;
  final int xpEarned;
  final String? giftId;
  final String? specialReward;
  final int newStreak;
  final bool isNewLongestStreak;
  final String? errorMessage;

  ClaimResult({
    required this.success,
    this.diamondsEarned = 0,
    this.xpEarned = 0,
    this.giftId,
    this.specialReward,
    this.newStreak = 0,
    this.isNewLongestStreak = false,
    this.errorMessage,
  });
}

/// Daily Bonus Service
class DailyBonusService {
  static final DailyBonusService _instance = DailyBonusService._internal();
  factory DailyBonusService() => _instance;
  DailyBonusService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection reference
  CollectionReference get _streaksCollection =>
      _firestore.collection('login_streaks');

  // Weekly rewards configuration (7 days)
  static const List<DailyReward> weeklyRewards = [
    DailyReward(day: 1, diamonds: 50, xp: 20),
    DailyReward(day: 2, diamonds: 75, xp: 30),
    DailyReward(day: 3, diamonds: 100, xp: 40, isMilestone: true),
    DailyReward(day: 4, diamonds: 125, xp: 50),
    DailyReward(day: 5, diamonds: 150, xp: 60),
    DailyReward(day: 6, diamonds: 200, xp: 80),
    DailyReward(
      day: 7,
      diamonds: 500,
      xp: 200,
      specialReward: 'mystery_box',
      isMilestone: true,
    ),
  ];

  // Milestone bonus multipliers
  static const Map<int, double> milestoneMultipliers = {
    7: 1.5,   // 1 week
    14: 1.75, // 2 weeks
    30: 2.0,  // 1 month
    60: 2.5,  // 2 months
    90: 3.0,  // 3 months
    180: 4.0, // 6 months
    365: 5.0, // 1 year
  };

  // ============ LOGIN STREAK MANAGEMENT ============

  /// Get user's login streak
  Future<LoginStreak> getLoginStreak(String oderId) async {
    final doc = await _streaksCollection.doc(oderId).get();
    if (!doc.exists) {
      return LoginStreak(oderId: oderId);
    }
    return LoginStreak.fromMap(doc.data() as Map<String, dynamic>, oderId);
  }

  /// Check if user can claim daily bonus
  Future<bool> canClaimBonus(String oderId) async {
    final streak = await getLoginStreak(oderId);
    return streak.canClaimToday;
  }

  /// Claim daily bonus
  Future<ClaimResult> claimDailyBonus(String oderId) async {
    final streak = await getLoginStreak(oderId);

    // Check if already claimed today
    if (!streak.canClaimToday) {
      return ClaimResult(
        success: false,
        errorMessage: 'Already claimed today. Come back tomorrow!',
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Calculate new streak
    int newStreak;
    DateTime newStreakStart;
    int newWeek;

    if (streak.lastLoginDate == null) {
      // First ever login
      newStreak = 1;
      newStreakStart = today;
      newWeek = 1;
    } else {
      final lastLogin = DateTime(
        streak.lastLoginDate!.year,
        streak.lastLoginDate!.month,
        streak.lastLoginDate!.day,
      );
      final daysSinceLastLogin = today.difference(lastLogin).inDays;

      if (daysSinceLastLogin == 1) {
        // Consecutive day - streak continues
        newStreak = streak.currentStreak + 1;
        newStreakStart = streak.streakStartDate ?? today;
        newWeek = ((newStreak - 1) ~/ 7) + 1;
      } else if (daysSinceLastLogin > 1) {
        // Streak broken - reset
        newStreak = 1;
        newStreakStart = today;
        newWeek = 1;
      } else {
        // Same day (shouldn't happen due to canClaimToday check)
        return ClaimResult(
          success: false,
          errorMessage: 'Already claimed today',
        );
      }
    }

    // Get today's reward
    final rewardDay = ((newStreak - 1) % 7) + 1;
    final dailyReward = weeklyRewards[rewardDay - 1];

    // Calculate multiplier based on streak milestones
    double multiplier = 1.0;
    for (final entry in milestoneMultipliers.entries) {
      if (newStreak >= entry.key) {
        multiplier = entry.value;
      }
    }

    final finalDiamonds = (dailyReward.diamonds * multiplier).round();
    final finalXp = (dailyReward.xp * multiplier).round();

    // Update longest streak if needed
    final newLongestStreak =
        newStreak > streak.longestStreak ? newStreak : streak.longestStreak;
    final isNewLongest = newStreak > streak.longestStreak;

    // Update claimed days for current week
    List<int> newClaimedDays;
    if (newWeek != streak.currentWeek) {
      // New week started, reset claimed days
      newClaimedDays = [rewardDay];
    } else {
      newClaimedDays = [...streak.claimedDays, rewardDay];
    }

    // Update streak document
    await _streaksCollection.doc(oderId).set({
      'currentStreak': newStreak,
      'longestStreak': newLongestStreak,
      'lastLoginDate': Timestamp.fromDate(now),
      'totalLogins': streak.totalLogins + 1,
      'streakStartDate': Timestamp.fromDate(newStreakStart),
      'claimedDays': newClaimedDays,
      'currentWeek': newWeek,
    });

    // Add diamonds to user
    await _firestore.collection('users').doc(oderId).update({
      'diamonds': FieldValue.increment(finalDiamonds),
      'xp': FieldValue.increment(finalXp),
    });

    // Record transaction
    await _recordBonusTransaction(
      oderId: oderId,
      diamonds: finalDiamonds,
      xp: finalXp,
      day: rewardDay,
      streak: newStreak,
      multiplier: multiplier,
    );

    // Handle special rewards
    String? earnedGiftId;
    if (dailyReward.giftId != null) {
      earnedGiftId = dailyReward.giftId;
      await _awardSpecialGift(oderId, dailyReward.giftId!);
    }

    // Handle mystery box (day 7 special)
    String? specialReward;
    if (dailyReward.specialReward == 'mystery_box') {
      specialReward = await _openMysteryBox(oderId);
    }

    // Save to local preferences for quick access
    await _saveLastClaimDate(oderId);

    return ClaimResult(
      success: true,
      diamondsEarned: finalDiamonds,
      xpEarned: finalXp,
      giftId: earnedGiftId,
      specialReward: specialReward,
      newStreak: newStreak,
      isNewLongestStreak: isNewLongest,
    );
  }

  /// Get reward for specific day
  DailyReward getRewardForDay(int day) {
    final rewardIndex = ((day - 1) % 7);
    return weeklyRewards[rewardIndex];
  }

  /// Get current multiplier based on streak
  double getMultiplier(int streak) {
    double multiplier = 1.0;
    for (final entry in milestoneMultipliers.entries) {
      if (streak >= entry.key) {
        multiplier = entry.value;
      }
    }
    return multiplier;
  }

  /// Get next milestone
  int? getNextMilestone(int currentStreak) {
    for (final milestone in milestoneMultipliers.keys) {
      if (milestone > currentStreak) {
        return milestone;
      }
    }
    return null;
  }

  /// Get time until next claim
  Duration getTimeUntilNextClaim() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return tomorrow.difference(now);
  }

  // ============ HELPER METHODS ============

  Future<void> _recordBonusTransaction({
    required String oderId,
    required int diamonds,
    required int xp,
    required int day,
    required int streak,
    required double multiplier,
  }) async {
    await _firestore.collection('transactions').add({
      'oderId': oderId,
      'type': 'daily_bonus',
      'diamonds': diamonds,
      'xp': xp,
      'day': day,
      'streak': streak,
      'multiplier': multiplier,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _awardSpecialGift(String oderId, String giftId) async {
    await _firestore
        .collection('users')
        .doc(oderId)
        .collection('inventory')
        .add({
      'giftId': giftId,
      'source': 'daily_bonus',
      'earnedAt': FieldValue.serverTimestamp(),
      'isUsed': false,
    });
  }

  Future<String> _openMysteryBox(String oderId) async {
    // Randomly select a mystery reward
    final rewards = [
      {'type': 'diamonds', 'amount': 200},
      {'type': 'diamonds', 'amount': 500},
      {'type': 'diamonds', 'amount': 1000},
      {'type': 'xp', 'amount': 500},
      {'type': 'gift', 'giftId': 'mystery_rose'},
      {'type': 'gift', 'giftId': 'mystery_heart'},
      {'type': 'vip_hours', 'amount': 24},
    ];

    final random = DateTime.now().millisecondsSinceEpoch % rewards.length;
    final reward = rewards[random];

    String rewardDescription;

    switch (reward['type']) {
      case 'diamonds':
        final amount = reward['amount'] as int;
        await _firestore.collection('users').doc(oderId).update({
          'diamonds': FieldValue.increment(amount),
        });
        rewardDescription = '+$amount Diamonds';
        break;
      case 'xp':
        final amount = reward['amount'] as int;
        await _firestore.collection('users').doc(oderId).update({
          'xp': FieldValue.increment(amount),
        });
        rewardDescription = '+$amount XP';
        break;
      case 'gift':
        final giftId = reward['giftId'] as String;
        await _awardSpecialGift(oderId, giftId);
        rewardDescription = 'Special Gift: $giftId';
        break;
      case 'vip_hours':
        final hours = reward['amount'] as int;
        await _extendVipTime(oderId, hours);
        rewardDescription = '+$hours hours VIP';
        break;
      default:
        rewardDescription = 'Mystery Reward';
    }

    return rewardDescription;
  }

  Future<void> _extendVipTime(String oderId, int hours) async {
    final userDoc = await _firestore.collection('users').doc(oderId).get();
    final userData = userDoc.data();

    DateTime newExpiry;
    if (userData != null && userData['vipExpiresAt'] != null) {
      final currentExpiry =
          (userData['vipExpiresAt'] as Timestamp).toDate();
      if (currentExpiry.isAfter(DateTime.now())) {
        newExpiry = currentExpiry.add(Duration(hours: hours));
      } else {
        newExpiry = DateTime.now().add(Duration(hours: hours));
      }
    } else {
      newExpiry = DateTime.now().add(Duration(hours: hours));
    }

    await _firestore.collection('users').doc(oderId).update({
      'isVIP': true,
      'vipExpiresAt': Timestamp.fromDate(newExpiry),
    });
  }

  Future<void> _saveLastClaimDate(String oderId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'last_claim_date_$oderId',
      DateTime.now().toIso8601String(),
    );
  }

  /// Quick check from local storage if claimed today
  Future<bool> hasClaimedTodayLocally(String oderId) async {
    final prefs = await SharedPreferences.getInstance();
    final lastClaimStr = prefs.getString('last_claim_date_$oderId');

    if (lastClaimStr == null) return false;

    final lastClaim = DateTime.parse(lastClaimStr);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final claimDate = DateTime(lastClaim.year, lastClaim.month, lastClaim.day);

    return claimDate == today;
  }

  // ============ LEADERBOARD ============

  /// Get top streakers
  Future<List<StreakLeaderboardEntry>> getTopStreakers({int limit = 20}) async {
    final snapshot = await _streaksCollection
        .orderBy('currentStreak', descending: true)
        .limit(limit)
        .get();

    final entries = <StreakLeaderboardEntry>[];

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final oderId = doc.id;

      // Get user info
      final userDoc = await _firestore.collection('users').doc(oderId).get();
      final userData = userDoc.data();

      entries.add(StreakLeaderboardEntry(
        oderId: oderId,
        userName: userData?['name'] ?? 'Unknown',
        userAvatar: userData?['profileImage'],
        currentStreak: data['currentStreak'] ?? 0,
        longestStreak: data['longestStreak'] ?? 0,
      ));
    }

    return entries;
  }

  /// Get user's rank
  Future<int> getUserRank(String oderId) async {
    final streak = await getLoginStreak(oderId);

    final higherCount = await _streaksCollection
        .where('currentStreak', isGreaterThan: streak.currentStreak)
        .count()
        .get();

    return (higherCount.count ?? 0) + 1;
  }
}

/// Leaderboard entry model
class StreakLeaderboardEntry {
  final String oderId;
  final String userName;
  final String? userAvatar;
  final int currentStreak;
  final int longestStreak;

  StreakLeaderboardEntry({
    required this.oderId,
    required this.userName,
    this.userAvatar,
    required this.currentStreak,
    required this.longestStreak,
  });
}
