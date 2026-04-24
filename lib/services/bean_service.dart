import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BeanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Singleton pattern
  static final BeanService _instance = BeanService._internal();
  factory BeanService() => _instance;
  BeanService._internal();

  /// Fetch bean transaction history for a host (Earnings from Gifts & Calls)
  Future<List<Map<String, dynamic>>> fetchBeanTransactions({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {
      // 1. Query for Gifts where user is receiver (Querying gift_transactions instead of coin_transactions)
      Query giftQuery = _firestore
          .collection('gift_transactions')
          .where('receiverId', isEqualTo: user.uid);

      // 2. Query for Calls where user is host (Querying premium_transactions instead of coin_transactions)
      Query callQuery = _firestore
          .collection('premium_transactions')
          .where('hostId', isEqualTo: user.uid);

      // Apply date filters if provided
      if (startDate != null) {
        giftQuery = giftQuery.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
        callQuery = callQuery.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      if (endDate != null) {
        // Add 1 day to include the entire end date
        final endOfday = endDate.add(const Duration(days: 1));
        giftQuery = giftQuery.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfday));
        callQuery = callQuery.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfday));
      }

      // Execute both queries
      final giftSnapshot = await giftQuery.orderBy('timestamp', descending: true).get();
      final callSnapshot = await callQuery.orderBy('timestamp', descending: true).get();

      // Merge and Sort
      final List<Map<String, dynamic>> allTransactions = [];
      
      for (var doc in giftSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        allTransactions.add({
          'id': doc.id,
          ...data,
          'displayType': 'Gift',
          'earnings': data['hostEarned'] ?? data['hostEarning'] ?? 0, // Handle potential field name variations
          'senderId': data['senderId'] ?? data['fromUserId'],
          'timestamp': data['timestamp'],
        });
      }

      for (var doc in callSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        allTransactions.add({
          'id': doc.id,
          ...data,
          'displayType': 'Call',
          'earnings': data['hostPoints'] ?? data['hostEarning'] ?? 0,
          'senderId': data['viewerId'] ?? data['userId'],
          'timestamp': data['timestamp'],
        });
      }

      // Sort by timestamp descending
      allTransactions.sort((a, b) {
        final tA = a['timestamp'] as Timestamp?;
        final tB = b['timestamp'] as Timestamp?;
        if (tA == null || tB == null) return 0;
        return tB.compareTo(tA);
      });

      return allTransactions.take(limit).toList();
    } catch (e) {
      print('❌ [BeanService] Error fetching transactions: $e');
      return [];
    }
  }
}
