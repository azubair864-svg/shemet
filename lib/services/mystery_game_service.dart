import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'diamond_service.dart';

enum MysteryGameState { betting, playing, won, lost }

class MysteryGameService extends ChangeNotifier {
  // Dependencies
  final DiamondService _diamondService = DiamondService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Game Configuration
  static const int totalChambers = 6;
  static const List<double> multipliers = [1.2, 1.5, 2.0, 3.0, 6.0];

  // State
  MysteryGameState _state = MysteryGameState.betting;
  int _betAmount = 0;
  List<bool> _revealedChambers = List.filled(totalChambers, false);
  int _penaltyIndex = -1; // 0 to 5
  int _revealedCount = 0;
  double _currentMultiplier = 1.0;
  int _winnings = 0;

  // Getters
  MysteryGameState get state => _state;
  int get betAmount => _betAmount;
  List<bool> get revealedChambers => _revealedChambers;
  int get penaltyIndex => _penaltyIndex; // Only use for debug or reveal at end
  int get revealedCount => _revealedCount;
  double get currentMultiplier => _currentMultiplier;
  int get winnings => _winnings;
  int get balance => _diamondService.balance;

  // Methods

  /// Start a new round
  Future<void> placeBet(int amount) async {
    if (amount <= 0) return;

    // Check balance
    final user = _auth.currentUser;
    if (user == null) return;

    // Ideally we verify balance via DiamondService, but for UI speed we check local cache
    if (_diamondService.balance < amount) {
      debugPrint("Insufficient funds");
      return;
    }

    // Deduct Coins
    final success = await _diamondService.deductDiamonds(
      userId: user.uid,
      amount: amount,
      reason: 'mystery_bet',
    );

    if (!success) return;

    // Initialize Round
    _betAmount = amount;
    _state = MysteryGameState.playing;
    _revealedChambers = List.filled(totalChambers, false);
    _revealedCount = 0;
    _currentMultiplier = 1.0;
    _winnings = 0;

    // Generate Random Penalty Position (Provably Fair Basic)
    _penaltyIndex = Random().nextInt(totalChambers);

    debugPrint("🎲 New Round: Bet $_betAmount | Penalty at $_penaltyIndex");
    notifyListeners();
  }

  /// Pick a chamber
  Future<void> pickChamber(int index) async {
    if (_state != MysteryGameState.playing) return;
    if (user == null) return;

    if (_revealedChambers[index]) return; // Already picked

    _revealedChambers[index] = true;
    notifyListeners(); // Update UI for reveal animation

    await Future.delayed(const Duration(milliseconds: 500)); // Suspense

    if (index == _penaltyIndex) {
      // 💥 BOOM! Penalty Hit
      _state = MysteryGameState.lost;
      _winnings = 0;
      debugPrint("💥 BOOM! Lost bet.");
      notifyListeners();
    } else {
      // 💎 SAFE!
      _revealedCount++;
      _currentMultiplier = multipliers[_revealedCount - 1];
      _winnings = (_betAmount * _currentMultiplier).floor();

      debugPrint("💎 Safe! Multiplier: $_currentMultiplier | Win: $_winnings");

      // Check if all safe chambers found (Jackpot 6.0x)
      if (_revealedCount == totalChambers - 1) {
        await cashOut(); // Auto cashout if max win reached
      } else {
        notifyListeners();
      }
    }
  }

  /// Cash Out current winnings
  Future<void> cashOut() async {
    if (_state != MysteryGameState.playing && _state != MysteryGameState.won) {
      return;
    }
    if (_winnings <= 0) return;

    final user = _auth.currentUser;
    if (user == null) return;

    _state = MysteryGameState.won;

    // Credit Winnings
    await _diamondService.addFreeDiamonds(
      amount: _winnings,
      source: 'mystery_win',
      transactionId: 'mystery_${DateTime.now().millisecondsSinceEpoch}',
    );

    debugPrint("💰 Cashed Out: $_winnings");
    notifyListeners();
  }

  void resetGame() {
    _state = MysteryGameState.betting;
    _winnings = 0;
    _betAmount = 0;
    _currentMultiplier = 1.0;
    _revealedChambers = List.filled(totalChambers, false);
    notifyListeners();
  }

  User? get user => _auth.currentUser;
}
