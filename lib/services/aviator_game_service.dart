import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'diamond_service.dart';
import 'database_service.dart';

enum AviatorPhase { betting, flying, crashed, result }

class AviatorGameState {
  final AviatorPhase phase;
  final double currentMultiplier;
  final double crashPoint;
  final int secondsRemaining; // For betting/result phases
  final List<double> history;
  final String roundId;

  AviatorGameState({
    required this.phase,
    required this.currentMultiplier,
    required this.crashPoint,
    required this.secondsRemaining,
    required this.history,
    required this.roundId,
  });
}

class AviatorBetRecord {
  final String roundId;
  final int amount;
  double? cashOutMultiplier; // null if lost/pending
  int? winAmount; // null if lost/pending
  final DateTime timestamp;
  
  AviatorBetRecord({
    required this.roundId,
    required this.amount,
    this.cashOutMultiplier,
    this.winAmount,
    required this.timestamp,
  });
}

class AviatorGameService extends ChangeNotifier {
  // 🏛️ ELITE SINGLETON PATTERN
  static final AviatorGameService _instance = AviatorGameService._internal();
  factory AviatorGameService() => _instance;
  AviatorGameService._internal();

  // Dependencies
  final DiamondService _diamondService = DiamondService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // State
  AviatorPhase _phase = AviatorPhase.betting;
  double _currentMultiplier = 1.00;
  double _crashPoint = 0.0;
  int _timerSeconds = 10;
  String _currentRoundId = "";
  final List<double> _history = [];
  final List<AviatorBetRecord> _myBets = [];
  
  // ⚡ Performance Optimization for 2GB RAM
  final ValueNotifier<double> multiplierNotifier = ValueNotifier<double>(1.00);
  final ValueNotifier<List<Map<String, dynamic>>> viewerBalancesNotifier = ValueNotifier([]);
  
  // My Player State
  int _myBetAmount = 0;
  bool _hasCashedOut = false;
  double _cashedOutAt = 0.0;

  // Auto Features
  bool _autoBetEnabled = false;
  double? _autoCashoutMultiplier; // If null, disabled
  
  // Room Integration
  String? _activeRoomId;
  String? _activeContext;
  bool _isHost = false; // Is this user the room host?
  DateTime? _serverStartTime;
  final DatabaseService _databaseService = DatabaseService();
  StreamSubscription? _viewersSubscription;

  void setRoomContext(String? roomId, String? context, {bool isHost = false}) {
    debugPrint('[AVIATOR] 🏠 setRoomContext: Room=$roomId, Context=$context, IsHost=$isHost');
    bool changed = _activeRoomId != roomId || _isHost != isHost;
    
    _activeRoomId = roomId;
    _activeContext = context;
    _isHost = isHost;
    
    if (changed) {
      debugPrint('[AVIATOR] 🏁 Interaction Context Updated.');
      notifyListeners();
    }

    if (_isHost && _activeRoomId != null) {
      if (changed) {
        debugPrint('[AVIATOR] 🛡️ Host mode: Starting viewers monitor.');
        _listenToActiveViewers();
      }
    } else if (changed) {
      debugPrint('[AVIATOR] 👁️ Viewer mode: Cleaning up host-specific listeners.');
      _viewersSubscription?.cancel();
    }
  }

  void _listenToActiveViewers() {
    _viewersSubscription?.cancel();
    if (_activeRoomId == null) return;
    
    _viewersSubscription = _databaseService.streamViewerBalances(
      _activeRoomId!,
      context: _activeContext ?? 'live_stream',
    ).listen((viewers) {
      viewerBalancesNotifier.value = viewers;
    });
  }

  void setIsHost(bool val) {
    _isHost = val;
    notifyListeners();
  }
  
  bool get autoBetEnabled => _autoBetEnabled;
  double? get autoCashoutMultiplier => _autoCashoutMultiplier;

  // Timers
  Timer? _gameLoopTimer;
  Timer? _flyTimer;
  double _flyElapsedTime = 0;

  // Getters
  AviatorPhase get phase => _phase;
  double get currentMultiplier => _currentMultiplier;
  int get timerSeconds => _timerSeconds;
  bool get isHost => _isHost;
  List<double> get history => _history;
  List<AviatorBetRecord> get myBets => _myBets;
  int get myBetAmount => _myBetAmount;
  bool get hasCashedOut => _hasCashedOut;
  double get cashedOutAt => _cashedOutAt;
  
  // Expose Balance for UI checks
  int get balance => _diamondService.balance; 

  // Singleton
  void startGame() {
    debugPrint('[AVIATOR] 🎮 startGame() requested. _isHost: $_isHost, _activeRoomId: $_activeRoomId');
    if (_isHost && _activeRoomId != null) {
      if (_gameLoopTimer == null || !_gameLoopTimer!.isActive) {
        debugPrint('[AVIATOR] 🚀 Initializing game loop (Host Mode)');
        _startBettingPhase();
      } else {
        debugPrint('[AVIATOR] ⚠️ startGame ignored: Loop already active.');
      }
    } else {
        debugPrint('[AVIATOR] 🚫 Cannot start: Not host or room ID is null.');
    }
  }

  void stopGame() {
    debugPrint('[AVIATOR] 🛑 stopGame: Cleaning up timers and state.');
    _gameLoopTimer?.cancel();
    _flyTimer?.cancel();
    _viewersSubscription?.cancel();
    _gameLoopTimer = null;
    _flyTimer = null;
    _viewersSubscription = null;
    
    // 🧹 HARD RESET STATE
    _activeRoomId = null;
    _isHost = false;
    _phase = AviatorPhase.betting;
    _currentMultiplier = 1.00;
    multiplierNotifier.value = 1.00;
    _timerSeconds = 10;
    _myBetAmount = 0;
    _hasCashedOut = false;
    _cashedOutAt = 0.0;
    _flyElapsedTime = 0;
    
    notifyListeners();
  }

  // --- CONTROLS ---

  void setAutoBet(bool enabled) {
    _autoBetEnabled = enabled;
    notifyListeners();
  }
  
  void setAutoCashout(double? multiplier) {
    _autoCashoutMultiplier = multiplier;
    notifyListeners();
  }

  Future<bool> placeBet(int amount) async {
    final user = _auth.currentUser;
    if (user == null || _phase != AviatorPhase.betting) return false;
    if (_myBetAmount > 0) return false; // Already bet

    try {
      debugPrint('[AVIATOR SERVER] 🎰 Placing bet: $amount for Round=$_currentRoundId');
      final callable = FirebaseFunctions.instance.httpsCallable('placeAviatorBet');
      final result = await callable.call({
         'amount': amount,
      });

      debugPrint('[AVIATOR SERVER] 🛰️ Bet Result: ${result.data}');

      if (result.data['success']) {
        _myBetAmount = amount;
        _hasCashedOut = false;
        
        // Add Pending Record
        _myBets.insert(0, AviatorBetRecord(
          roundId: _currentRoundId,
          amount: amount,
          timestamp: DateTime.now(),
        ));
        
        // Keep only last 50
        if (_myBets.length > 50) _myBets.removeLast();
        
        // Sync cache
        await _diamondService.getDiamondBalance(user.uid);
        
        // 💰 ADD COMMISSION TO HOST
        if (_activeRoomId != null && _activeContext != null) {
          final commission = (amount * 0.1).toInt();
          if (commission > 0) {
            await _databaseService.addGameEarnings(
              roomId: _activeRoomId!,
              amount: commission,
              context: _activeContext!,
            );
          }
        }
        
        notifyListeners();
        return true;
      } else {
        debugPrint('[AVIATOR SERVER] ❌ Bet failed: ${result.data['message']}');
        return false;
      }
    } catch (e) {
      debugPrint('[AVIATOR SERVER] 🛑 Error placing bet: $e');
      return false;
    }
  }

  Future<void> cashOut() async {
    if (_phase == AviatorPhase.flying && _myBetAmount > 0 && !_hasCashedOut) {
      debugPrint('[AVIATOR SERVER] 💸 Attempting cashout at $_currentMultiplier...');
      _hasCashedOut = true;
      _cashedOutAt = _currentMultiplier; // Snapshot local multiplier instantly for fluid UI
      
      final user = _auth.currentUser;
      if (user != null) {
        try {
          final callable = FirebaseFunctions.instance.httpsCallable('cashOutAviator');
          final result = await callable.call({
            'bet_amount': _myBetAmount,
            'multiplier': _cashedOutAt,
            'roundId': _currentRoundId,
          });

          debugPrint('[AVIATOR SERVER] 🛰️ Cashout Result: ${result.data}');

          if (result.data['success']) {
            final winnings = result.data['winnings'];
            debugPrint('[AVIATOR SERVER] ✅ Cashout confirmed: $winnings');

            // Update Record
            if (_myBets.isNotEmpty && _myBets.first.roundId == _currentRoundId) {
              _myBets.first.cashOutMultiplier = _cashedOutAt;
              _myBets.first.winAmount = winnings;
            }
            
            // Sync cache
            await _diamondService.getDiamondBalance(user.uid);
            notifyListeners();
          }
        } catch (e) {
           debugPrint('[AVIATOR SERVER] 🛑 Error during cashout: $e');
        }
      }
    }
  }

  /// Synchronize local game state with Firestore (Master Room Document)
  void syncWithFirestore(Map<String, dynamic>? gameData) {
    if (gameData == null || _isHost) return;

    final String status = gameData['status'] ?? 'betting';
    final String roundId = gameData['roundId'] ?? '';
    final double? serverCrashPoint = (gameData['crashPoint'] as num?)?.toDouble();
    final dynamic startTimeRaw = gameData['startTime'];

    debugPrint('[AVIATOR SYNC] 📥 Sync: Status=$status, RoundId=$roundId, CrashPoint=$serverCrashPoint');

    // 1. Handle Round Changes
    if (roundId != _currentRoundId) {
      debugPrint('[AVIATOR SYNC] 🔄 New Round Detected: $roundId');
      _currentRoundId = roundId;
      _myBetAmount = 0;
      _hasCashedOut = false;
    }

    // 2. Handle Phase Transitions
    if (status == 'betting' && _phase != AviatorPhase.betting) {
      _phase = AviatorPhase.betting;
      _currentMultiplier = 1.00;
      multiplierNotifier.value = 1.00;
      _timerSeconds = 10; 
      notifyListeners();
    } else if (status == 'flying' && _phase != AviatorPhase.flying) {
      if (startTimeRaw != null && serverCrashPoint != null) {
        _crashPoint = serverCrashPoint;
        _startFlyingPhaseSynced(startTimeRaw is Timestamp ? startTimeRaw.toDate() : DateTime.now());
      }
    } else if (status == 'crashed' && _phase != AviatorPhase.crashed) {
      if (serverCrashPoint != null) {
         _crashPoint = serverCrashPoint;
         _crash();
      }
    }
  }

  void _startFlyingPhaseSynced(DateTime startTime) {
    debugPrint('[AVIATOR SYNC] 🛫 Synced Takeoff Initiated');
    _phase = AviatorPhase.flying;
    _serverStartTime = startTime;
    notifyListeners();

    _flyTimer?.cancel();
    _flyTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      final now = DateTime.now();
      final elapsedMs = now.difference(_serverStartTime!).inMilliseconds;
      final double elapsedSeconds = elapsedMs / 1000.0;
      
      final double oldMultiplier = _currentMultiplier;
      _currentMultiplier = pow(1.0024, elapsedSeconds * 35).toDouble();
      multiplierNotifier.value = _currentMultiplier;

      if (_currentMultiplier.floor() > oldMultiplier.floor()) {
        debugPrint('[AVIATOR FLY] 🧭 Synced Altitude: ${_currentMultiplier.toStringAsFixed(2)}x');
      }

      // Auto Cashout Check
      if (_myBetAmount > 0 && !_hasCashedOut && _autoCashoutMultiplier != null) {
        if (_currentMultiplier >= _autoCashoutMultiplier!) {
          cashOut();
        }
      }

      if (_currentMultiplier >= _crashPoint) {
        debugPrint('[AVIATOR FLY] 💥 Reached Crash Point');
        timer.cancel();
        _crash();
      } else {
        notifyListeners();
      }
    });
  }

  // --- GAME LOOP LOGIC ---

  void _startBettingPhase() {
    debugPrint('[AVIATOR] 🏁 PHASE: BETTING STARTED (Timer: 10s)');
    _phase = AviatorPhase.betting;
    _currentMultiplier = 1.00;
    multiplierNotifier.value = 1.00;
    _timerSeconds = 10; 
    _myBetAmount = 0;
    _hasCashedOut = false;
    
    if (_isHost) {
      debugPrint('[AVIATOR] 🎲 Host: Generating crash point and round ID...');
      _generateCrashPoint(); 
      _currentRoundId = DateTime.now().millisecondsSinceEpoch.toString();
      
      // BROADCAST ROUND START
      if (_activeRoomId != null) {
        debugPrint('[AVIATOR] 📡 Broadcasting BETTING phase to Firestore (Room: $_activeRoomId)');
        _databaseService.startRoomGame(
          roomId: _activeRoomId!,
          gameId: 'aviator',
          crashPoint: _crashPoint,
          context: _activeContext,
        ).then((_) {
           debugPrint('[AVIATOR] ✅ Firestore Broadcast: SUCCESS');
        }).catchError((error) {
           debugPrint('[AVIATOR] ❌ Firestore Broadcast: FAILED ($error)');
        });
      }
    }
    
    // Auto Bet Logic
    if (_autoBetEnabled) {
      debugPrint('[AVIATOR] 🤖 Auto-betting 100 diamonds...');
      placeBet(100); 
    }
    
    notifyListeners();

    _gameLoopTimer?.cancel();
    _gameLoopTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds > 0) {
        debugPrint('[AVIATOR] ⏳ Betting Timer: $_timerSeconds s');
        _timerSeconds--;
        notifyListeners();
      } else {
        debugPrint('[AVIATOR] ⌛ Betting Over. Transitioning to Flying...');
        timer.cancel();
        _startFlyingPhase();
      }
    });
  }

  void _startFlyingPhase() {
    debugPrint('[AVIATOR] 🛫 PHASE: FLYING STARTED (Altitude Gain: 🚀)');
    _phase = AviatorPhase.flying;
    _flyElapsedTime = 0;
    _serverStartTime = DateTime.now(); 
    
    if (_isHost && _activeRoomId != null) {
      debugPrint('[AVIATOR] 📡 Syncing FLYING status to Firestore...');
      _databaseService.updateRoomGameState(
        roomId: _activeRoomId!,
        updates: {
          'status': 'flying',
          'startTime': FieldValue.serverTimestamp(),
        },
        context: _activeContext,
      ).then((_) => debugPrint('[AVIATOR] ✅ Firestore Sync: FLYING'))
       .catchError((e) => debugPrint('[AVIATOR] ❌ Firestore Sync: FAILED ($e)'));
    }
    
    notifyListeners();

    _flyTimer?.cancel();
    _flyTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) { 
      final double oldMultiplier = _currentMultiplier;
      _flyElapsedTime += 0.1;
      
      _currentMultiplier = pow(1.0024, _flyElapsedTime * 35).toDouble();
      multiplierNotifier.value = _currentMultiplier;
      
      if (_currentMultiplier.floor() > oldMultiplier.floor()) {
        debugPrint('[AVIATOR] 🧗 Current Altitude: ${_currentMultiplier.toStringAsFixed(2)}x');
      }

      if (_myBetAmount > 0 && !_hasCashedOut && _autoCashoutMultiplier != null) {
        if (_currentMultiplier >= _autoCashoutMultiplier!) {
          debugPrint('[AVIATOR] 🤖 Auto-cashout triggered at ${_currentMultiplier.toStringAsFixed(2)}x');
          cashOut();
        }
      }

      if (_currentMultiplier >= _crashPoint) {
        debugPrint('[AVIATOR] 💥 CRASH POINT REACHED: ${_crashPoint.toStringAsFixed(2)}x');
        timer.cancel();
        _crash();
      } else {
        notifyListeners();
      }
    });
  }

  void _crash() {
    debugPrint('[AVIATOR] 💥 PHASE: CRASHED (at ${_crashPoint.toStringAsFixed(2)}x)');
    _phase = AviatorPhase.crashed;
    _currentMultiplier = _crashPoint; 
    multiplierNotifier.value = _crashPoint;
    _history.insert(0, _crashPoint);
    if (_history.length > 20) _history.removeLast();
    
    if (_isHost && _activeRoomId != null) {
      debugPrint('[AVIATOR] 📡 Syncing CRASHED status to Firestore...');
      _databaseService.updateRoomGameState(
        roomId: _activeRoomId!,
        updates: {
          'status': 'crashed',
          'lastCrashPoint': _crashPoint,
        },
        context: _activeContext,
      ).then((_) => debugPrint('[AVIATOR] ✅ Firestore Sync: CRASHED'))
       .catchError((e) => debugPrint('[AVIATOR] ❌ Firestore Sync: FAILED ($e)'));
    }

    if (_myBetAmount > 0 && !_hasCashedOut) {
       debugPrint('[AVIATOR] 💸 Result: Player CRASHED Out (LOST)');
      if (_myBets.isNotEmpty && _myBets.first.roundId == _currentRoundId) {
         _myBets.first.winAmount = 0; 
      }
    }
    
    notifyListeners();

    debugPrint('[AVIATOR] ⏳ Waiting 3s before next round...');
    Timer(const Duration(seconds: 3), () {
      if (_isHost) {
        debugPrint('[AVIATOR] 🔄 Restarting Loop...');
        _startBettingPhase();
      } else {
        debugPrint('[AVIATOR] 😴 Guest: Waiting for next round sync.');
      }
    });
  }

  // --- ALGORITHM ---

  void _generateCrashPoint() {
    final random = Random();
    double e = 1.0 / (1.0 - random.nextDouble());
    
    if (e > 50.0) e = 50.0;
    if (e < 1.0) e = 1.0;
    
    _crashPoint = (e * 100).floorToDouble() / 100;
    debugPrint("[AVIATOR] 🎲 NEXT CRASH POINT: $_crashPoint");
  }

  // Helper to allow forcing a crash point for testing
  void setDebugCrashPoint(double val) {
    _crashPoint = val;
  }

  Future<void> debugAddDiamonds(int amount) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _diamondService.addFreeDiamonds(
        userId: user.uid,
        amount: amount,
        reason: 'aviator_debug_add',
        grantedBy: 'Debug',
      );
      notifyListeners();
    }
  }
}
