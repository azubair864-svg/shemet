import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'diamond_service.dart';
import 'database_service.dart';

enum DiceGameState { betting, rolling, result }

class DiceGameService extends ChangeNotifier {
  final DiamondService _diamondService = DiamondService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Singleton Pattern
  static final DiceGameService _instance = DiceGameService._internal();
  factory DiceGameService() => _instance;
  
  DiceGameService._internal() {
    _init();
  }
  
  // Game State
  DiceGameState _state = DiceGameState.betting;
  DiceGameState get state => _state;
  
  // Timer
  Timer? _gameLoopTimer;
  int _countdown = 20; // 20s betting, 5s rolling
  int get countdown => _countdown;
  
  // Game Data
  List<int> _diceResult = [1, 1, 1];
  List<int> get diceResult => _diceResult;
  int get totalSum => _diceResult.reduce((a, b) => a + b);
  
  // Betting
  int _selectedNumber = -1;
  int get selectedNumber => _selectedNumber;
  
  int _betAmount = 0;
  int get betAmount => _betAmount; // Current active bet
  
  int _winnings = 0;
  int get winnings => _winnings;
  bool _won = false;
  bool get won => _won;
  
  int get balance => _diamondService.balance;

  // Payout Multipliers (Sic Bo style)
  final Map<int, double> payouts = {
    3: 50.0, 4: 50.0, 
    5: 20.0, 6: 15.0, 7: 12.0, 8: 8.0, 9: 6.0, 
    10: 6.0, 11: 6.0, 
    12: 6.0, 13: 8.0, 14: 12.0, 15: 15.0, 16: 20.0, 
    17: 50.0, 18: 50.0
  };

  // Tracking processed rounds to prevent double payouts
  String _lastProcessedRoundId = '';
  String _currentRoundId = '';

  // 🤖 Auto-Bet State
  bool _autoBetEnabled = false;
  bool get autoBetEnabled => _autoBetEnabled;
  int _autoBetAmount = 0;
  int get autoBetAmount => _autoBetAmount;
  
  // Room Integration
  String? _activeRoomId;
  String? _activeContext;
  bool _isHost = false;
  bool get isHost => _isHost;
  final DatabaseService _databaseService = DatabaseService();

  void setRoomContext(String? roomId, String? context, {bool isHost = false}) {
    bool changed = _activeRoomId != roomId || _isHost != isHost;
    
    _activeRoomId = roomId;
    _activeContext = context;
    _isHost = isHost;

    if (changed) {
      debugPrint('[DICE] 🏠 Room Context: RoomID=$roomId, IsHost=$isHost');
      notifyListeners();
    }
  }

  void startGame() {
    debugPrint('[DICE] 🎮 startGame() requested. _isHost: $_isHost, _activeRoomId: $_activeRoomId');
    if (_isHost && _activeRoomId != null) {
      debugPrint('[DICE] 🚀 Initializing game loop (Host Mode)');
      _databaseService.startRoomGame(
        roomId: _activeRoomId!,
        gameId: 'dice',
        crashPoint: 0.0,
        context: _activeContext,
      ).then((_) {
         debugPrint('[DICE] ✅ Firestore Broadcast: SUCCESS');
      }).catchError((error) {
         debugPrint('[DICE] ❌ Firestore Broadcast: FAILED ($error)');
      });
    }
    _startGameLoopTicker();
  }

  void stopGame() {
    debugPrint('[DICE] 🛑 stopGame: Cleaning up timers and state.');
    _gameLoopTimer?.cancel();
    _gameLoopTimer = null;

    // 🧹 HARD RESET STATE
    _activeRoomId = null;
    _isHost = false;
    _state = DiceGameState.betting;
    _countdown = 20;
    _betAmount = 0;
    _selectedNumber = -1;
    _won = false;
    _winnings = 0;
    _autoBetEnabled = false;
    _autoBetAmount = 0;

    notifyListeners();
  }
  
  void _init() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _diamondService.getDiamondBalance(user.uid);
      notifyListeners();
    }
  }
  
  // ==========================================
  // ROOM-SPECIFIC SERVER SYNC
  // ==========================================
  
  /// Synchronize local game state with Firestore (Master Room Document)
  void syncWithFirestore(Map<String, dynamic>? gameData) {
    if (gameData == null || _isHost) return;

    final String phaseStr = gameData['phase'] ?? 'betting';
    final String roundId = gameData['roundId'] ?? 'N/A';
    debugPrint('[DICE] 📥 Sync: Phase=$phaseStr, Round=$roundId');

    if (phaseStr == 'betting' && _state != DiceGameState.betting) {
      debugPrint('[DICE] 🚀 Sync: Transitioning to BETTING');
      _state = DiceGameState.betting;
    } else if (phaseStr == 'rolling' && _state != DiceGameState.rolling) {
      debugPrint('[DICE] 🎲 Sync: Transitioning to ROLLING');
      _state = DiceGameState.rolling;
    } else if (phaseStr == 'result' && _state != DiceGameState.result) {
      debugPrint('[DICE] 🏆 Sync: Transitioning to RESULT');
      _state = DiceGameState.result;
    }

    List<dynamic> diceRaw = gameData['diceResult'] ?? [1, 1, 1];
    _diceResult = diceRaw.map((e) => e as int).toList();
    
    // Handle Round Changes
    if (roundId != _currentRoundId) {
        debugPrint('[DICE] 🔄 New Round Detected: $roundId');
        if (_state == DiceGameState.betting) {
            _betAmount = 0;
            _winnings = 0;
            _won = false;
        }

        // 🤖 AUTO-BET TRIGGER
        if (_state == DiceGameState.betting && _autoBetEnabled && _autoBetAmount > 0 && _selectedNumber != -1) {
            placeBet(_autoBetAmount);
        }
    }
    _currentRoundId = roundId;

    if (_state == DiceGameState.result && roundId != _lastProcessedRoundId) {
        _lastProcessedRoundId = roundId;
        _checkResultsAndPayout();
    }

    if (gameData['expiresAt'] != null) {
        dynamic expiresAtRaw = gameData['expiresAt'];
        DateTime expiresAt = DateTime.fromMillisecondsSinceEpoch(expiresAtRaw is Timestamp ? expiresAtRaw.millisecondsSinceEpoch : expiresAtRaw as int);
        _countdown = expiresAt.difference(DateTime.now()).inSeconds;
        if (_countdown < 0) _countdown = 0;
    }

    notifyListeners();
  }

  // Local UI Ticker
  void _startGameLoopTicker() {
    debugPrint('[DICE] ⚙️ Starting game loop ticker...');
    _gameLoopTimer?.cancel();
    _gameLoopTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        _countdown--;
        debugPrint('[DICE] ⏳ Countdown: $_countdown s (Phase: ${_state.name})');
        notifyListeners();
      } else {
        if (_isHost) {
            _handleHostPhaseTransition();
        }
      }
    });
  }

  void _handleHostPhaseTransition() {
    debugPrint('[DICE] ⚡ Host: Transitioning phase (Current: ${_state.name})');
    if (_state == DiceGameState.betting) {
        _state = DiceGameState.rolling;
        _countdown = 5; 
        
        final random = DateTime.now().millisecondsSinceEpoch;
        _diceResult = [
            (random % 6) + 1,
            ((random ~/ 7) % 6) + 1,
            ((random ~/ 13) % 6) + 1,
        ];
        _currentRoundId = DateTime.now().millisecondsSinceEpoch.toString();
        
        if (_activeRoomId != null) {
            debugPrint('[DICE] 📡 Syncing ROLLING phase to Firestore...');
            _databaseService.updateRoomGameState(
                roomId: _activeRoomId!,
                updates: {
                    'phase': 'rolling',
                    'countdown': 5,
                    'diceResult': _diceResult,
                    'roundId': _currentRoundId,
                    'expiresAt': DateTime.now().add(const Duration(seconds: 5)).millisecondsSinceEpoch,
                },
                context: _activeContext,
            ).then((_) => debugPrint('[DICE] ✅ Firestore Sync: ROLLING'))
             .catchError((e) => debugPrint('[DICE] ❌ Firestore Sync: FAILED ($e)'));
        }
    } else if (_state == DiceGameState.rolling) {
        _state = DiceGameState.result;
        _countdown = 10; 
        
        if (_activeRoomId != null) {
            _databaseService.updateRoomGameState(
                roomId: _activeRoomId!,
                updates: {
                    'phase': 'result',
                    'countdown': 10,
                    'expiresAt': DateTime.now().add(const Duration(seconds: 10)).millisecondsSinceEpoch,
                },
                context: _activeContext,
            );
        }
    } else if (_state == DiceGameState.result) {
        _state = DiceGameState.betting;
        _countdown = 20; 
        if (_activeRoomId != null) {
            _databaseService.updateRoomGameState(
                roomId: _activeRoomId!,
                updates: {
                    'phase': 'betting',
                    'countdown': 20,
                    'expiresAt': DateTime.now().add(const Duration(seconds: 20)).millisecondsSinceEpoch,
                },
                context: _activeContext,
            );
        }
    }
    notifyListeners();
  }
  
  void _checkResultsAndPayout() {
    debugPrint('[DICE] 🏁 Checking result: Selected=$_selectedNumber, Actual=$totalSum');
    if (_betAmount > 0 && _selectedNumber != -1) {
       if (totalSum == _selectedNumber) {
         double multiplier = payouts[totalSum] ?? 1.0;
         _winnings = (_betAmount * multiplier).floor();
         _won = true;
         debugPrint('[DICE] 👑 WIN! Winnings: $_winnings diamonds');
         _payoutUser();
       } else {
         _won = false;
         _winnings = 0;
         debugPrint('[DICE] 🛑 LOSS.');
       }
    }
  }

  Future<void> _payoutUser() async {
    final user = _auth.currentUser;
    if (user != null && _winnings > 0) {
       try {
         debugPrint('[DICE SERVER] 🛰️ Sending Payout Request: Win=$_winnings');
         final callable = FirebaseFunctions.instance.httpsCallable('processDicePayout');
         final result = await callable.call({
           'bet_amount': _betAmount,
           'multiplier': payouts[totalSum] ?? 1.0,
         });

         if (result.data['success']) {
            final serverWin = result.data['winnings'];
            debugPrint('[DICE SERVER] ✅ Payout SUCCESS: $serverWin diamonds');
            await _diamondService.getDiamondBalance(user.uid);
            notifyListeners();
         } else {
            debugPrint('[DICE SERVER] ❌ Payout REFUSED: ${result.data['message']}');
         }
       } catch (e) {
          debugPrint('[DICE SERVER] 🛑 Error during payout: $e');
       }
    }
  }

  // ==========================================
  // USER ACTIONS
  // ==========================================

  void selectNumber(int number) {
    if (_state != DiceGameState.betting) return;
    _selectedNumber = number;
    notifyListeners();
  }

  Future<void> placeBet(int amount) async {
    if (_state != DiceGameState.betting || _selectedNumber == -1 || amount <= 0) return;

    final user = _auth.currentUser;
    if (user == null) return;

    try {
      debugPrint('[DICE SERVER] 🎰 Placing bet: $amount');
      final callable = FirebaseFunctions.instance.httpsCallable('placeDiceBet');
      final result = await callable.call({
        'amount': amount,
      });

      if (result.data['success']) {
        _betAmount += amount; 
        debugPrint('[DICE SERVER] ✅ Bet placed successfully');
        await _diamondService.getDiamondBalance(user.uid);

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
      }
    } catch (e) {
      debugPrint('[DICE SERVER] ❌ Error placing bet: $e');
    }
  }

  void setAutoBet(bool enabled, int amount) {
    _autoBetEnabled = enabled;
    _autoBetAmount = amount;
    if (enabled && _state == DiceGameState.betting && _betAmount == 0 && _selectedNumber != -1) {
      placeBet(amount);
    }
    notifyListeners();
  }
  
  double getMultiplierFor(int number) => payouts[number] ?? 0.0;

  Future<void> debugAddDiamonds(int amount) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _diamondService.addFreeDiamonds(
        userId: user.uid,
        amount: amount,
        reason: 'dice_debug_add',
        grantedBy: 'Debug',
      );
      notifyListeners();
    }
  }
  
  @override
  void dispose() {
    _gameLoopTimer?.cancel();
    super.dispose();
  }
}
