import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'diamond_service.dart';

/// Represents the global state of the Racing Game
enum RacingStatus { betting, racing, result, waiting }

class RacingGameState {
  final String roundId;
  final RacingStatus status;
  final DateTime nextPhaseTime;
  final String? winnerCarId;
  final List<String> history;
  final int totalPool;
  final Duration serverTimeOffset; // Offset between client and server
  final Map<String, dynamic> vehicles; // Dynamic odds, speed, and bets

  RacingGameState({
    required this.roundId,
    required this.status,
    required this.nextPhaseTime,
    this.winnerCarId,
    this.history = const [],
    this.totalPool = 0,
    this.serverTimeOffset = Duration.zero,
    this.vehicles = const {},
  });

  factory RacingGameState.fromMap(Map<String, dynamic> data, Duration offset) {
    RacingStatus status = RacingStatus.betting;
    if (data['status'] == 'RACING') status = RacingStatus.racing;
    if (data['status'] == 'RESULT') status = RacingStatus.result;

    return RacingGameState(
      roundId: data['current_round_id'] ?? 'unknown',
      status: status,
      nextPhaseTime: (data['next_phase_time'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(seconds: 10)),
      winnerCarId: data['winner_car_id'],
      history: List<String>.from(data['history'] ?? []),
      totalPool: data['total_pool'] ?? 0,
      vehicles: data['vehicles'] as Map<String, dynamic>? ?? {},
      serverTimeOffset: offset,
    );
  }
  
  // Helper to know how many seconds left (Synced to Server Time)
  int get secondsRemaining {
    final nowSynced = DateTime.now().add(serverTimeOffset);
    final diff = nextPhaseTime.difference(nowSynced).inSeconds;
    // CLAMP: Never return negative values to prevent UI weirdness like -100s
    return diff < 0 ? 0 : diff;
  }
}

class RacingGameService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _rtDatabase = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DiamondService _diamondService = DiamondService();
  
  Duration _serverTimeOffset = Duration.zero;

  // Singleton
  static final RacingGameService _instance = RacingGameService._internal();
  factory RacingGameService() => _instance;
  RacingGameService._internal() {
    _syncServerTime();
  }

  /// Calculates the difference between local clock and Firestore server time
  void _syncServerTime() {
    // Firebase provides a special location to track clock skew
    _firestore.collection('.info').doc('serverTimeOffset').snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final offsetMs = snapshot.data()?['offset'] as int? ?? 0;
        _serverTimeOffset = Duration(milliseconds: offsetMs);
        debugPrint('[RACING_TRACE] ⏰ Clock Synced | Server Offset: ${_serverTimeOffset.inMilliseconds}ms');
      }
    }, onError: (e) {
      debugPrint('[RACING_TRACE] ❌ Error syncing clock: $e');
    });
  }

  /// Stream of the Global Game State
  Stream<RacingGameState> get gameStateStream {
    return _firestore
        .collection('games')
        .doc('racing')
        .snapshots()
        .map((snapshot) {
           if (!snapshot.exists) {
             return RacingGameState(
               roundId: 'init',
               status: RacingStatus.waiting, // Change enum to include waiting
               nextPhaseTime: DateTime.now(),
             );
           }
           
            final data = snapshot.data()!;
            
            // TRACE LOGGING: Use unique prefix to help user find these in terminal spam
            if (kDebugMode) {
               final statusStr = data['status'] ?? 'UNKNOWN';
               final nextTime = (data['next_phase_time'] as Timestamp?)?.toDate();
               final remaining = nextTime != null 
                  ? nextTime.difference(DateTime.now().add(_serverTimeOffset)).inSeconds 
                  : 0;
               
               debugPrint('[RACING_TRACE] 📡 Firestore Update | Status: $statusStr | Round: ${data['current_round_id']} | SyncTime: ${remaining}s');
            }

            // Update offset if possible or just use zero for now (assuming Firestore handles drift)
            return RacingGameState.fromMap(data, _serverTimeOffset);
        });
  }

  // --- PRESENCE TRACKING (Active Players) ---
  
  /// Call this when the user opens the Racing Game Garage screen.
  Future<void> joinGameRoom() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final presenceRef = _rtDatabase.ref('racing_presence/${user.uid}');
      
      // Auto-remove when the user disconnects or closes the app suddenly
      await presenceRef.onDisconnect().remove();
      
      // Set the user as active in the room
      await presenceRef.set(true);
      
      debugPrint('[RACING_PRESENCE] 👤 User joined the game room.');
    } catch (e) {
      debugPrint('[RACING_PRESENCE] ❌ Error joining room: $e');
    }
  }

  /// Call this when the user leaves the Racing Game Garage screen.
  Future<void> leaveGameRoom() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final presenceRef = _rtDatabase.ref('racing_presence/${user.uid}');
      await presenceRef.remove();
      
      // Cancel the onDisconnect since we manually removed it to save resources
      await presenceRef.onDisconnect().cancel();
      
      debugPrint('[RACING_PRESENCE] 👋 User left the game room.');
    } catch (e) {
      debugPrint('[RACING_PRESENCE] ❌ Error leaving room: $e');
    }
  }

  /// Stream of active players governed by the backend Presence trigger
  Stream<int> get activePlayersStream {
    return _firestore
        .collection('games')
        .doc('racing')
        .collection('stats')
        .doc('live')
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return 1; // Default to 1 (the current user)
      }
      try {
        final data = snapshot.data();
        if (data != null && data.containsKey('active_players')) {
          int count = (data['active_players'] as num).toInt();
          return count > 0 ? count : 1;
        } else {
          return 1; // Safety fallback
        }
      } catch (e) {
        debugPrint('Error parsing activePlayersStream (Firestore): $e');
        return 1;
      }
    }).handleError((error) {
       debugPrint('Stream error in activePlayersStream: $error');
       return 1;
    });
  }

  // --- LOCAL SIMULATION LOGIC REMOVED ---
  
  /// Call cloud function to manually trigger next phase if scheduler is delayed
  Future<void> triggerNextPhase() async {
    try {
      debugPrint('[RACING_TRACE] 🛠️ Manually triggering next phase via Cloud Function');
      final callable = FirebaseFunctions.instance.httpsCallable('triggerRacingPhase');
      final result = await callable.call();
      debugPrint('[RACING_TRACE] 🛠️ Manual trigger result: ${result.data}');
    } catch (e) {
      debugPrint('[RACING_TRACE] ❌ Error triggering next phase: $e');
    }
  }


  /// Place a Bet
  Future<bool> placeBet(String carId, int amount) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    // 1. Check current game state locally before calling function to save network
    final gameDoc = await _firestore.collection('games').doc('racing').get();
    if (gameDoc.exists && gameDoc.data()?['status'] != 'BETTING') {
      debugPrint('⚠️ Cannot bet: Game is not in BETTING phase');
      return false;
    }

    try {
      // 2. Client-Side Validation (Backend will also verify)
      final balance = await _diamondService.getDiamondBalance(user.uid);
      if (balance < amount) {
        debugPrint('❌ Insufficient diamond balance');
        return false;
      }

      // 3. Call the Atomic Backend Cloud Function
      // The backend handles the diamond deduction AND updating total_pool / vehicle popularity safely
      final callable = FirebaseFunctions.instance.httpsCallable('placeBet');
      await callable.call({
         'car_id': carId,
         'amount': amount,
      });
      
      return true;

    } catch (e) {
      debugPrint('Error placing bet via Cloud Function: $e');
      return false;
    }
  }

  /// Get Bet Stream for a specific round
  Stream<Map<String, dynamic>?> getBetStreamForRound(String roundId) {
     final user = _auth.currentUser;
     if (user == null) return const Stream.empty();

     return _firestore
        .collection('games')
        .doc('racing')
        .collection('rounds')
        .doc(roundId)
        .collection('bets')
        .doc(user.uid)
        .snapshots()
        .map((betSnap) => betSnap.data());
  }
}
