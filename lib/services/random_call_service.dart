import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'call_service.dart';
import '../models/call_model.dart';
import 'notification_service.dart';

/// ⭐⭐⭐ PRODUCTION-READY RANDOM CALL MATCHING SERVICE ⭐⭐⭐
/// Handles random user matching for voice/video calls
/// Features: Queue system, Filters, Auto-matching, Call initiation
class RandomCallService {
  static final RandomCallService _instance = RandomCallService._internal();
  factory RandomCallService() => _instance;
  RandomCallService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CallService _callService = CallService();
  final NotificationService _notificationService = NotificationService();

  // Collections
  CollectionReference get _matchingQueue => _firestore.collection('random_call_queue');
  CollectionReference get _usersCollection => _firestore.collection('users');

  // Current matching state
  String? _currentQueueId;
  StreamSubscription? _queueSubscription;
  StreamSubscription? _matchSubscription;
  Timer? _matchingTimer;
  bool _isSearching = false;

  // Getters
  bool get isSearching => _isSearching;
  String? get currentQueueId => _currentQueueId;

  // ==================== JOIN MATCHING QUEUE ====================

  /// Join the random call matching queue
  Future<String?> joinQueue({
    required String userId,
    required UserModel user,
    required String callType, // 'voice' or 'video'
    String? preferredGender,
    int? minAge,
    int? maxAge,
    String? preferredCountry,
    String? preferredLanguage,
  }) async {
    
    
    
    
    
    
    
    

    try {
      // First, leave any existing queue
      await leaveQueue(userId);

      // Create queue entry
      final queueId = _matchingQueue.doc().id;
      final isHost = user.isHost; // Check if user is host
      final initialStatus = isHost ? 'waiting' : 'searching';

      final queueEntry = {
        'queueId': queueId,
        'userId': userId,
        'userName': user.name,
        'userPhoto': user.photoURL,
        'userGender': user.gender,
        'userAge': user.age,
        'userCountry': user.country,
        'userLanguage': user.language,
        'userLevel': user.level,
        'userIsVerified': user.isVerified,
        'userIsVip': user.isVip ?? false,
        'userIsHost': isHost, // Add checking field
        'callType': callType,
        'preferredGender': preferredGender,
        'minAge': minAge ?? 18,
        'maxAge': maxAge ?? 100,
        'preferredCountry': preferredCountry,
        'preferredLanguage': preferredLanguage,
        'status': initialStatus, // searching or waiting
        'matchedWith': null,
        'matchedAt': null,
        'joinedAt': FieldValue.serverTimestamp(),
      };

      await _matchingQueue.doc(queueId).set(queueEntry);
      
      _currentQueueId = queueId;
      _isSearching = true;

      // Start listening for matches (Both Hosts and Users need this to know when they are picked)
      _startMatchListener(queueId, userId);

      // Start matching timer ONLY for Users (Hosts just wait)
      if (!isHost) {
        _startMatchingTimer(
          queueId: queueId,
          userId: userId,
          callType: callType,
          myGender: user.gender,
          myAge: user.age,
          myCountry: user.country,
          preferredGender: preferredGender,
          minAge: minAge,
          maxAge: maxAge,
          preferredCountry: preferredCountry,
          preferredLanguage: preferredLanguage,
        );
      }

      return queueId;
    } catch (e) {
      return null;
    }
  }

  /// Start listening for when we get matched
  void _startMatchListener(String queueId, String userId) {
    _queueSubscription = _matchingQueue.doc(queueId).snapshots().listen((snapshot) {
      if (!snapshot.exists) {
        _isSearching = false;
        return;
      }

      final data = snapshot.data() as Map<String, dynamic>;
      final status = data['status'] as String;
      final matchedWith = data['matchedWith'] as String?;

      if (status == 'matched' && matchedWith != null) {
        _isSearching = false;
        _matchingTimer?.cancel();
      }
    });
  }

  /// Try to find a match periodically (Run by USERS only)
  void _startMatchingTimer({
    required String queueId,
    required String userId,
    required String callType,
    String? myGender,
    int? myAge,
    String? myCountry,
    String? preferredGender,
    int? minAge,
    int? maxAge,
    String? preferredCountry,
    String? preferredLanguage,
  }) {
    _matchingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!_isSearching) {
        timer.cancel();
        return;
      }

      await _tryToFindMatch(
        queueId: queueId,
        userId: userId,
        callType: callType,
        myGender: myGender,
        myAge: myAge,
        myCountry: myCountry,
        preferredGender: preferredGender,
        minAge: minAge,
        maxAge: maxAge,
        preferredCountry: preferredCountry,
        preferredLanguage: preferredLanguage,
      );
    });
  }

  /// Try to find a matching user in the queue
  Future<bool> _tryToFindMatch({
    required String queueId,
    required String userId,
    required String callType,
    String? myGender,
    int? myAge,
    String? myCountry,
    String? preferredGender,
    int? minAge,
    int? maxAge,
    String? preferredCountry,
    String? preferredLanguage,
  }) async {
    try {
      debugPrint('🔍 [MATCHMAKING] Searching for $callType matches for user: $userId');
      
      // Simplify query to avoid composite index requirement for inequality
      Query query = _matchingQueue
          .where('status', whereIn: ['waiting', 'searching'])
          .where('callType', isEqualTo: callType)
          .limit(20);

      final snapshot = await query.get();
      debugPrint('🔍 [MATCHMAKING] Found ${snapshot.docs.length} potential docs in queue');

      if (snapshot.docs.isEmpty) {
        return false;
      }

      // Filter and score potential matches
      final potentialMatches = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final matchUserId = data['userId'] as String;

        // Skip if it's the same user
        if (matchUserId == userId) continue;

        // Skip if they are not in a valid status for matching
        final matchStatus = data['status'] as String;
        if (matchStatus != 'waiting' && matchStatus != 'searching') {
          debugPrint('🔍 [MATCHMAKING] Skipping $matchUserId due to status: $matchStatus');
          continue;
        }

        // Calculate compatibility score
        int score = 0;

        // Gender preference match
        final matchGender = data['userGender'] as String?;
        final matchPreferredGender = data['preferredGender'] as String?;

        // 1. Check if WE match THEIR gender preference
        bool theyLikeUs = false;
        if (matchPreferredGender == null || 
            matchPreferredGender == 'All' || 
            (myGender != null && matchPreferredGender.toLowerCase() == myGender.toLowerCase())) {
          theyLikeUs = true;
          score += 10;
        }

        // 2. Check if THEY match OUR gender preference
        bool weLikeThem = false;
        if (preferredGender == null || 
            preferredGender == 'All' || 
            (matchGender != null && preferredGender.toLowerCase() == matchGender.toLowerCase())) {
          weLikeThem = true;
          score += 10;
        }

        if (!theyLikeUs || !weLikeThem) {
          debugPrint('🔍 [MATCHMAKING] Skipping $matchUserId: Gender mismatch (They want: $matchPreferredGender, We are: $myGender | We want: $preferredGender, They are: $matchGender)');
          continue;
        }

        // Age preference match
        final matchAge = data['userAge'] as int?;
        if (matchAge != null) {
          if ((minAge == null || matchAge >= minAge) &&
              (maxAge == null || matchAge <= maxAge)) {
            score += 5;
          }
        }

        // Country match
        final matchCountry = data['userCountry'] as String?;
        if (preferredCountry != null && matchCountry == preferredCountry) {
          score += 5;
        }

        // Language match
        final matchLanguage = data['userLanguage'] as String?;
        if (preferredLanguage != null && matchLanguage == preferredLanguage) {
          score += 5;
        }

        // VIP bonus
        if (data['userIsVip'] == true) {
          score += 3;
        }

        // Verified bonus
        if (data['userIsVerified'] == true) {
          score += 2;
        }

        potentialMatches.add({
          'queueId': doc.id,
          'userId': matchUserId,
          'data': data,
          'score': score,
        });
      }

      if (potentialMatches.isEmpty) {
        
        return false;
      }

      // Sort by score and pick best match
      potentialMatches.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

      // Add some randomness among top matches
      final topMatches = potentialMatches.take(5).toList();
      final selectedMatch = topMatches[Random().nextInt(topMatches.length)];

      

      // Try to claim the match (atomic operation)
      final success = await _claimMatch(
        myQueueId: queueId,
        myUserId: userId,
        matchQueueId: selectedMatch['queueId'] as String,
        matchUserId: selectedMatch['userId'] as String,
      );

      return success;
    } catch (e) {
      
      return false;
    }
  }

  /// Atomically claim a match (prevent race conditions)
  Future<bool> _claimMatch({
    required String myQueueId,
    required String myUserId,
    required String matchQueueId,
    required String matchUserId,
  }) async {
    
    
    

    try {
      // Use transaction to ensure atomic update
      return await _firestore.runTransaction<bool>((transaction) async {
        // Read both queue entries
        final myDoc = await transaction.get(_matchingQueue.doc(myQueueId));
        final matchDoc = await transaction.get(_matchingQueue.doc(matchQueueId));

        if (!myDoc.exists || !matchDoc.exists) {
          
          return false;
        }

        final myData = myDoc.data() as Map<String, dynamic>;
        final matchData = matchDoc.data() as Map<String, dynamic>;

        // Check if I am searching and they are in a valid status
        final myStatus = myData['status'] as String?;
        final matchStatus = matchData['status'] as String?;

        if (myStatus != 'searching' || 
            (matchStatus != 'waiting' && matchStatus != 'searching')) {
          return false;
        }

        // Update both to matched
        final now = FieldValue.serverTimestamp();

        transaction.update(_matchingQueue.doc(myQueueId), {
          'status': 'matched',
          'matchedWith': matchUserId,
          'matchedQueueId': matchQueueId,
          'matchedAt': now,
        });

        transaction.update(_matchingQueue.doc(matchQueueId), {
          'status': 'matched',
          'matchedWith': myUserId,
          'matchedQueueId': myQueueId,
          'matchedAt': now,
        });

        
        return true;
      });
    } catch (e) {
      
      return false;
    }
  }

  // ==================== LEAVE QUEUE ====================

  /// Leave the matching queue
  Future<bool> leaveQueue(String userId) async {
    
    

    try {
      // Cancel subscriptions
      await _queueSubscription?.cancel();
      await _matchSubscription?.cancel();
      _matchingTimer?.cancel();

      _queueSubscription = null;
      _matchSubscription = null;
      _matchingTimer = null;

      // Find and delete user's queue entries
      final snapshot = await _matchingQueue
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'searching')
          .get();

      for (final doc in snapshot.docs) {
        await doc.reference.delete();
        
      }

      _currentQueueId = null;
      _isSearching = false;

      
      return true;
    } catch (e) {
      
      return false;
    }
  }

  // ==================== GET MATCH INFO ====================

  /// Get matched user info when a match is found
  Future<Map<String, dynamic>?> getMatchInfo(String queueId) async {
    
    

    try {
      final doc = await _matchingQueue.doc(queueId).get();
      if (!doc.exists) {
        
        return null;
      }

      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] as String;

      if (status != 'matched') {
        
        return null;
      }

      final matchedUserId = data['matchedWith'] as String;
      final matchedQueueId = data['matchedQueueId'] as String;

      // Get matched user's queue data
      final matchQueueDoc = await _matchingQueue.doc(matchedQueueId).get();
      if (!matchQueueDoc.exists) {
        
        return null;
      }

      final matchData = matchQueueDoc.data() as Map<String, dynamic>;

      final matchInfo = {
        'matchedUserId': matchedUserId,
        'matchedUserName': matchData['userName'],
        'matchedUserPhoto': matchData['userPhoto'],
        'matchedUserGender': matchData['userGender'],
        'matchedUserAge': matchData['userAge'],
        'matchedUserCountry': matchData['userCountry'],
        'matchedUserLevel': matchData['userLevel'],
        'matchedUserIsVerified': matchData['userIsVerified'],
        'matchedUserIsVip': matchData['userIsVip'],
        'callType': data['callType'],
        'matchedAt': data['matchedAt'],
      };

      
      
      return matchInfo;
    } catch (e) {
      
      return null;
    }
  }

  /// Stream match info updates
  Stream<Map<String, dynamic>?> streamMatchInfo(String queueId) {
    return _matchingQueue.doc(queueId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;

      final data = snapshot.data() as Map<String, dynamic>;
      return data;
    });
  }

  // ==================== INITIATE CALL ====================

  /// Initiate call with matched user
  Future<String?> initiateCallWithMatch({
    required String callerId,
    required String callerName,
    String? callerPhoto,
    required String receiverId,
    required String receiverName,
    String? receiverPhoto,
    required String callType,
  }) async {
    
    
    
    

    try {
      final callId = await _callService.initiateCall(
        callerId: callerId,
        callerName: callerName,
        callerPhoto: callerPhoto,
        receiverId: receiverId,
        receiverName: receiverName,
        receiverPhoto: receiverPhoto,
        type: callType == 'video' ? CallType.video : CallType.voice,
      );

      

      // Send notification to receiver
      await _notificationService.sendIncomingCallNotification(
        receiverId: receiverId,
        callerName: callerName,
        callType: callType,
        callId: callId,
      );
    
      return callId;
    } catch (e) {
      
      return null;
    }
  }

  // ==================== STATISTICS ====================

  /// Get queue statistics (for debugging/admin)
  Future<Map<String, dynamic>> getQueueStats() async {
    

    try {
      final searchingSnapshot = await _matchingQueue
          .where('status', isEqualTo: 'searching')
          .get();

      final voiceCount = searchingSnapshot.docs
          .where((doc) => (doc.data() as Map<String, dynamic>)['callType'] == 'voice')
          .length;
      final videoCount = searchingSnapshot.docs
          .where((doc) => (doc.data() as Map<String, dynamic>)['callType'] == 'video')
          .length;

      // Gender breakdown
      final maleCount = searchingSnapshot.docs
          .where((doc) =>
              (doc.data() as Map<String, dynamic>)['userGender']
                  ?.toString()
                  .toLowerCase() ==
              'male')
          .length;
      final femaleCount = searchingSnapshot.docs
          .where((doc) =>
              (doc.data() as Map<String, dynamic>)['userGender']
                  ?.toString()
                  .toLowerCase() ==
              'female')
          .length;

      final stats = {
        'totalSearching': searchingSnapshot.docs.length,
        'voiceSearching': voiceCount,
        'videoSearching': videoCount,
        'maleSearching': maleCount,
        'femaleSearching': femaleCount,
      };

      
      
      

      return stats;
    } catch (e) {
      
      return {};
    }
  }

  // ==================== CLEANUP ====================

  /// Clean up old queue entries (call periodically via Cloud Function)
  Future<int> cleanupStaleEntries({int maxAgeMinutes = 5}) async {
    

    try {
      final cutoff = DateTime.now().subtract(Duration(minutes: maxAgeMinutes));

      final snapshot = await _matchingQueue
          .where('status', isEqualTo: 'searching')
          .where('joinedAt', isLessThan: Timestamp.fromDate(cutoff))
          .get();

      int deletedCount = 0;
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
        deletedCount++;
      }

      
      return deletedCount;
    } catch (e) {
      
      return 0;
    }
  }

  /// Dispose resources
  void dispose() {
    _queueSubscription?.cancel();
    _matchSubscription?.cancel();
    _matchingTimer?.cancel();
    _isSearching = false;
    _currentQueueId = null;
  }
}
