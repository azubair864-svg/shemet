import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'diamond_service.dart';

class GameService {
  static final GameService _instance = GameService._internal();
  factory GameService() => _instance;
  GameService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DiamondService _diamondService = DiamondService();

  /// Place a bet for a game
  Future<bool> placeBet({
    required String gameId,
    required String gameName,
    required int amount,
  }) async {
    
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      
      return false;
    }

    try {
      // 1. Check balance
      final balance = await _diamondService.getDiamondBalance(user.uid);
      if (balance < amount) {
        
        return false;
      }

      // 2. Deduct coins via CoinService
      // Note: We need a deduct method in CoinService or we manually do it here.
      // Looking at CoinService, it has 'deductCoins'.
      
      final success = await _diamondService.deductDiamonds(
        userId: user.uid,
        amount: amount,
        reason: 'bet_$gameId',
        contextId: gameId,
      );

      if (!success) {
        
        return false;
      }

      // 3. Log transaction
      await _firestore.collection('game_transactions').add({
        'userId': user.uid,
        'gameId': gameId,
        'gameName': gameName,
        'type': 'bet',
        'amount': amount,
        'timestamp': FieldValue.serverTimestamp(),
      });

      
      return true;
    } catch (e) {
      
      return false;
    }
  }

  /// Process a win
  Future<bool> processWin({
    required String gameId,
    required String gameName,
    required int betAmount,
    required double multiplier,
  }) async {
    final winAmount = (betAmount * multiplier).floor();
    

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      // 1. Add diamonds
      final success = await _diamondService.addDiamonds(
        userId: user.uid,
        amount: winAmount,
        source: 'game_win',
        sourceId: gameId,
        metadata: {
          'gameName': gameName,
          'betAmount': betAmount,
          'multiplier': multiplier,
        },
      );

      if (!success) {
        
        return false;
      }

      // 2. Log transaction
      await _firestore.collection('game_transactions').add({
        'userId': user.uid,
        'gameId': gameId,
        'gameName': gameName,
        'type': 'win',
        'betAmount': betAmount,
        'winAmount': winAmount,
        'multiplier': multiplier,
        'timestamp': FieldValue.serverTimestamp(),
      });

      
      return true;
    } catch (e) {
      
      return false;
    }
  }
}
