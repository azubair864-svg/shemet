import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../models/gift_model.dart';

class GiftService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Singleton pattern
  static final GiftService _instance = GiftService._internal();
  factory GiftService() => _instance;
  GiftService._internal();

  /// Send a gift from one user to another via SECURE CLOUD FUNCTION
  /// Returns true if successful, false otherwise
  Future<bool> sendGift({
    required String fromUserId,
    required String fromUserName,
    required String toUserId,
    required String toUserName,
    required GiftModel gift,
    int quantity = 1,
    String? context, // 'live_stream', 'chat', 'profile', etc.
    String? contextId, // streamId, chatId, etc.
    int? seatIndex, // Optional seat index for direct update
  }) async {
    try {
      debugPrint('[GIFT_SERVICE_DEBUG] 🎁 sendGift called');
      debugPrint('[GIFT_SERVICE_DEBUG] From: $fromUserId ($fromUserName)');
      debugPrint('[GIFT_SERVICE_DEBUG] To: $toUserId ($toUserName)');
      debugPrint('[GIFT_SERVICE_DEBUG] Gift: ${gift.id} (${gift.name}), Price: ${gift.price}, Qty: $quantity');
      
      final totalDiamondCost = gift.effectivePrice * quantity;
      debugPrint('[GIFT_SERVICE_DEBUG] Total Diamond Cost: $totalDiamondCost');
      debugPrint('[GIFT_SERVICE_DEBUG] Context Type: ${context ?? 'NULL'}');
      debugPrint('[GIFT_SERVICE_DEBUG] Context ID: ${contextId ?? 'NULL'}');
      
      // Use Firebase Functions for secure transaction (60/40 Split)
      debugPrint('[GIFT_SERVICE_DEBUG] ☁️ Invoking HTTPS Callable: sendGift');
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('sendGift');
      
      final payload = <String, dynamic>{
        'receiverId': toUserId,
        'giftId': gift.id,
        'amount': totalDiamondCost,
        'contextId': contextId,
        'contextType': context,
        'seatIndex': seatIndex,
        'senderName': fromUserName,
        'receiverName': toUserName,
        'giftName': gift.name,
      };
      debugPrint('[GIFT_SERVICE_DEBUG] 📦 Payload for Cloud Function: $payload');
      
      final results = await callable.call(payload);

      debugPrint('[GIFT_SERVICE_DEBUG] 📥 Received Response from Cloud Function');
      final data = Map<String, dynamic>.from(results.data);
      debugPrint('[GIFT_SERVICE_DEBUG] 📝 Complete Response Data: $data');
      
      if (data['success'] != true) {
        debugPrint('[GIFT_SERVICE_DEBUG] 🛑 Cloud Function reported FAILURE: ${data['message']}');
        return false;
      }

      debugPrint('[GIFT_SERVICE_DEBUG] ✅ Secure Gift sent successfully. Host earned: ${data['hostEarned']}');

      return true;
    } catch (e) {
      debugPrint('[GIFT_SERVICE_DEBUG] ❌ FATAL EXCEPTION in sendGift: $e');
      if (e is FirebaseFunctionsException) {
        debugPrint('[GIFT_SERVICE_DEBUG] 🚨 FirebaseFunctionsException Details:');
        debugPrint('   Code: ${e.code}');
        debugPrint('   Message: ${e.message}');
        debugPrint('   Details: ${e.details}');
      }
      return false;
    }
  }

  /// Get gift transactions for a user (sent or received)
  Future<List<Map<String, dynamic>>> getGiftTransactions({
    required String userId,
    bool sentOnly = false,
    bool receivedOnly = false,
    int limit = 50,
  }) async {
    try {
      Query query = _firestore
          .collection('gift_transactions')
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (sentOnly) {
        query = query.where('fromUserId', isEqualTo: userId);
      } else if (receivedOnly) {
        query = query.where('toUserId', isEqualTo: userId);
      }

      final snapshot = await query.get();

      final transactions = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();

      return transactions;
    } catch (e) {
      return [];
    }
  }

  /// Get total gifts sent by a user
  Future<int> getTotalGiftsSent(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('gift_transactions')
          .where('fromUserId', isEqualTo: userId)
          .get();

      final totalGifts = snapshot.docs.length;
      return totalGifts;
    } catch (e) {
      return 0;
    }
  }

  /// Get total gifts received by a user
  Future<int> getTotalGiftsReceived(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('gift_transactions')
          .where('toUserId', isEqualTo: userId)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  /// Get gift leaderboard for a specific context (e.g., live stream)
  Future<List<Map<String, dynamic>>> getGiftLeaderboard({
    required String contextId,
    int limit = 10,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('gift_transactions')
          .where('contextId', isEqualTo: contextId)
          .orderBy('giftPrice', descending: true)
          .limit(limit)
          .get();

      final leaderboard = <String, Map<String, dynamic>>{};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final userId = data['fromUserId'] as String;

        if (leaderboard.containsKey(userId)) {
          leaderboard[userId]!['totalDiamonds'] += data['giftPrice'] as int;
          leaderboard[userId]!['totalGifts'] += 1;
        } else {
          leaderboard[userId] = {
            'userId': userId,
            'userName': data['fromUserName'],
            'totalDiamonds': data['giftPrice'] as int,
            'totalGifts': 1,
          };
        }
      }

      final sortedLeaderboard = leaderboard.values.toList()
        ..sort(
          (a, b) => (b['totalDiamonds'] as int).compareTo(a['totalDiamonds'] as int),
        );

      return sortedLeaderboard;
    } catch (e) {
      return [];
    }
  }

  /// Stream gift transactions in real-time for a specific context
  Stream<List<Map<String, dynamic>>> streamGiftTransactions({
    required String contextId,
    int limit = 50,
  }) {
    return _firestore
        .collection('gift_transactions')
        .where('contextId', isEqualTo: contextId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();
        });
  }

  /// Get available gifts
  List<GiftModel> getAvailableGifts() {
    return GiftModel.getDefaultGifts();
  }

  /// Check if user can afford a gift
  Future<bool> canAffordGift({
    required String userId,
    required int giftPrice,
  }) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        return false;
      }

      final userDiamonds = userDoc.data()?['diamonds'] ?? 0;
      return userDiamonds >= giftPrice;
    } catch (e) {
      return false;
    }
  }
}
