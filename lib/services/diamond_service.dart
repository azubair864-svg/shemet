import 'package:cloud_firestore/cloud_firestore.dart';

class DiamondService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Singleton pattern
  static final DiamondService _instance = DiamondService._internal();
  factory DiamondService() => _instance;
  DiamondService._internal();

  // Local cache for spending balance
  final int _spendingBalance = 0;
  int get balance => _spendingBalance;

  /// Add diamonds to host (earned from gifts received)
  /// Diamonds are earned when users send gifts during live streams, party rooms, etc.
  Future<bool> addDiamonds({
    required String userId,
    required int amount,
    required String source, // 'gift', 'live_stream', 'party_room', etc.
    String? sourceId, // gift transaction ID, stream ID, etc.
    Map<String, dynamic>? metadata,
  }) async {
    
    
    
    
    
    

    try {
      // 1. Validate amount
      
      if (amount <= 0) {
        
        return false;
      }
      

      // 2. Add diamonds to user account
      
      await _firestore.collection('users').doc(userId).update({
        'diamonds': FieldValue.increment(amount),
      });
      

      // 3. Save diamond transaction
      
      final transactionData = {
        'userId': userId,
        'type': 'earned',
        'amount': amount,
        'source': source,
        'sourceId': sourceId,
        'metadata': metadata ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'completed',
      };

      final docRef = await _firestore
          .collection('diamond_transactions')
          .add(transactionData);

      

      // 4. Update user diamond statistics
      
      await _firestore.collection('users').doc(userId).update({
        'totalDiamondsEarned': FieldValue.increment(amount),
        'lastDiamondEarnedAt': FieldValue.serverTimestamp(),
      });
      

      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Purchase diamonds through payment gateway
  Future<bool> purchaseDiamonds({
    required String userId,
    required int amount,
    required double price,
    String? transactionId,
    String? paymentMethod,
    String? priceLabel,
    String? currencyCode,
    int bonus = 0,
  }) async {
    try {
      if (amount <= 0) return false;

      // 1. Add diamonds to user account
      await _firestore.collection('users').doc(userId).update({
        'diamonds': FieldValue.increment(amount + bonus),
      });

      // 2. Save purchase transaction
      final transactionData = {
        'userId': userId,
        'type': 'purchase',
        'amount': amount,
        'bonus': bonus,
        'price': price,
        'priceLabel': priceLabel,
        'currencyCode': currencyCode,
        'transactionId': transactionId,
        'paymentMethod': paymentMethod,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'completed',
      };

      await _firestore.collection('diamond_transactions').add(transactionData);

      // 3. Update user purchase statistics
      await _firestore.collection('users').doc(userId).update({
        'totalDiamondsPurchased': FieldValue.increment(amount + bonus),
        'lastPurchaseAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Add free diamonds (daily rewards, etc.)
  Future<bool> addFreeDiamonds({
    required String userId,
    required int amount,
    required String reason,
    String? grantedBy,
  }) async {
    try {
      if (amount <= 0) return false;

      await _firestore.collection('users').doc(userId).update({
        'diamonds': FieldValue.increment(amount),
      });

      final transactionData = {
        'userId': userId,
        'type': 'free_diamonds',
        'amount': amount,
        'reason': reason,
        'grantedBy': grantedBy ?? 'system',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'completed',
      };

      await _firestore.collection('diamond_transactions').add(transactionData);

      await _firestore.collection('users').doc(userId).update({
        'totalFreeDiamondsReceived': FieldValue.increment(amount),
        'lastFreeDiamondAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Deduct diamonds for a purchase or gifting
  Future<bool> deductDiamonds({
    required String userId,
    required int amount,
    required String reason,
    String? contextId,
  }) async {
    try {
      if (amount <= 0) return false;

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;

      final currentDiamonds = userDoc.data()?['diamonds'] ?? 0;
      if (currentDiamonds < amount) return false;

      await _firestore.collection('users').doc(userId).update({
        'diamonds': FieldValue.increment(-amount),
      });

      final transactionData = {
        'userId': userId,
        'type': 'spending',
        'amount': -amount,
        'reason': reason,
        'contextId': contextId,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'completed',
        'balanceBefore': currentDiamonds,
        'balanceAfter': currentDiamonds - amount,
      };

      await _firestore.collection('diamond_transactions').add(transactionData);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if user can afford
  Future<bool> canAfford({
    required String userId,
    required int amount,
  }) async {
    try {
      final balance = await getDiamondBalance(userId);
      return balance >= amount;
    } catch (e) {
      return false;
    }
  }

  /// Refund diamonds
  Future<bool> refundDiamonds({
    required String userId,
    required int amount,
    required String reason,
    String? originalTransactionId,
  }) async {
    try {
      if (amount <= 0) return false;

      await _firestore.collection('users').doc(userId).update({
        'diamonds': FieldValue.increment(amount),
      });

      final transactionData = {
        'userId': userId,
        'type': 'refund',
        'amount': amount,
        'reason': reason,
        'originalTransactionId': originalTransactionId,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'completed',
      };

      await _firestore.collection('diamond_transactions').add(transactionData);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Withdraw diamonds (convert to real money)
  /// Hosts can withdraw their diamonds through various payment methods
  Future<bool> withdrawDiamonds({
    required String userId,
    required int amount,
    required String paymentMethod, // 'bank_transfer', 'paypal', 'stripe', etc.
    required Map<String, dynamic> paymentDetails,
  }) async {
    
    
    
    
    

    try {
      // 1. Validate amount
      
      if (amount <= 0) {
        
        return false;
      }
      

      // 2. Check minimum withdrawal amount (e.g., 100 diamonds)
      const minWithdrawal = 100;
      if (amount < minWithdrawal) {
        
        return false;
      }
      

      // 3. Check user's diamond balance
      
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        
        return false;
      }

      final currentDiamonds = userDoc.data()?['diamonds'] ?? 0;
      

      if (currentDiamonds < amount) {
        
        final shortage = amount - currentDiamonds;
        
        return false;
      }

      

      // 4. Deduct diamonds from user account
      
      await _firestore.collection('users').doc(userId).update({
        'diamonds': FieldValue.increment(-amount),
      });
      

      // 5. Calculate withdrawal amount (diamond value in USD, e.g., 1 diamond = $0.01)
      const diamondValue = 0.01; // $0.01 per diamond
      final withdrawalAmount = amount * diamondValue;
      

      // 6. Create withdrawal request
      
      final withdrawalData = {
        'userId': userId,
        'type': 'withdrawal',
        'amount': -amount,
        'withdrawalAmount': withdrawalAmount,
        'paymentMethod': paymentMethod,
        'paymentDetails': paymentDetails,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending', // pending, processing, completed, failed
        'balanceBefore': currentDiamonds,
        'balanceAfter': currentDiamonds - amount,
      };

      final docRef = await _firestore
          .collection('diamond_transactions')
          .add(withdrawalData);

      

      // 7. Update user statistics
      
      await _firestore.collection('users').doc(userId).update({
        'totalDiamondsWithdrawn': FieldValue.increment(amount),
        'totalWithdrawn': FieldValue.increment(withdrawalAmount),
        'lastWithdrawalAt': FieldValue.serverTimestamp(),
      });
      

      
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get user's current diamond balance
  Future<int> getDiamondBalance(String userId) async {
    
    

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        
        return 0;
      }

      final diamonds = userDoc.data()?['diamonds'] ?? 0;
      

      // Calculate USD value
      const diamondValue = 0.01;
      final usdValue = diamonds * diamondValue;
      

      

      return diamonds;
    } catch (e) {
      
      
      
      
      return 0;
    }
  }

  /// Get diamond transaction history for a user
  Future<List<Map<String, dynamic>>> getDiamondTransactions({
    required String userId,
    String? type, // 'earned', 'withdrawal', 'bonus', 'refund'
    int limit = 50,
  }) async {
    
    
    
    

    try {
      Query query = _firestore
          .collection('diamond_transactions')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (type != null) {
        query = query.where('type', isEqualTo: type);
        
      }

      final snapshot = await query.get();
      

      final transactions = snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              })
          .toList();

      // Calculate statistics
      int totalEarned = 0;
      int totalWithdrawn = 0;
      double totalWithdrawnUSD = 0.0;

      for (var transaction in transactions) {
        final transactionType = transaction['type'];
        final amount = (transaction['amount'] ?? 0) as int;

        if (transactionType == 'earned') {
          totalEarned += amount;
        } else if (transactionType == 'withdrawal') {
          totalWithdrawn += amount.abs();
          totalWithdrawnUSD += (transaction['withdrawalAmount'] ?? 0.0) as double;
        }
      }

      
      
      
      

      
      

      return transactions;
    } catch (e) {
      
      
      
      
      return [];
    }
  }

  /// Get diamond earning statistics
  Future<Map<String, dynamic>> getDiamondStatistics(String userId) async {
    
    

    try {
      // Get user document
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        
        return {
          'currentBalance': 0,
          'currentBalanceUSD': 0.0,
          'totalEarned': 0,
          'totalWithdrawn': 0,
          'totalWithdrawnUSD': 0.0,
          'availableForWithdrawal': 0,
        };
      }

      final data = userDoc.data()!;
      final currentBalance = data['diamonds'] ?? 0;
      final totalEarned = data['totalDiamondsEarned'] ?? 0;
      final totalWithdrawn = data['totalDiamondsWithdrawn'] ?? 0;
      final totalWithdrawnUSD = (data['totalWithdrawn'] ?? 0.0) as double;

      // Calculate USD values
      const diamondValue = 0.01;
      final currentBalanceUSD = currentBalance * diamondValue;
      final availableForWithdrawal = currentBalance >= 100 ? currentBalance : 0;

      final statistics = {
        'currentBalance': currentBalance,
        'currentBalanceUSD': currentBalanceUSD,
        'totalEarned': totalEarned,
        'totalWithdrawn': totalWithdrawn,
        'totalWithdrawnUSD': totalWithdrawnUSD,
        'availableForWithdrawal': availableForWithdrawal,
      };

      
      
      
      
      

      final totalUsed = totalEarned - currentBalance - totalWithdrawn;
      if (totalUsed > 0) {
        
      }

      
      

      return statistics;
    } catch (e) {
      
      
      
      
      return {
        'currentBalance': 0,
        'currentBalanceUSD': 0.0,
        'totalEarned': 0,
        'totalWithdrawn': 0,
        'totalWithdrawnUSD': 0.0,
        'availableForWithdrawal': 0,
      };
    }
  }

  /// Get pending withdrawal requests for admin approval
  Future<List<Map<String, dynamic>>> getPendingWithdrawals({
    String? userId,
    int limit = 50,
  }) async {
    
    
    

    try {
      Query query = _firestore
          .collection('diamond_transactions')
          .where('type', isEqualTo: 'withdrawal')
          .where('status', isEqualTo: 'pending')
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
        
      }

      final snapshot = await query.get();
      

      final withdrawals = snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              })
          .toList();

      // Calculate total pending amount
      double totalPendingUSD = 0.0;
      for (var withdrawal in withdrawals) {
        totalPendingUSD += (withdrawal['withdrawalAmount'] ?? 0.0) as double;
      }

      
      
      

      return withdrawals;
    } catch (e) {
      
      
      
      
      return [];
    }
  }

  /// Update withdrawal status (for admin)
  Future<bool> updateWithdrawalStatus({
    required String transactionId,
    required String status, // 'processing', 'completed', 'failed'
    String? notes,
  }) async {
    
    
    
    

    try {
      // Validate status
      final validStatuses = ['processing', 'completed', 'failed'];
      if (!validStatuses.contains(status)) {
        
        
        return false;
      }

      // Update transaction status
      
      final updateData = {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (notes != null) {
        updateData['notes'] = notes;
      }

      if (status == 'completed') {
        updateData['completedAt'] = FieldValue.serverTimestamp();
      } else if (status == 'failed') {
        updateData['failedAt'] = FieldValue.serverTimestamp();

        // Refund diamonds if withdrawal failed
        
        final transactionDoc = await _firestore
            .collection('diamond_transactions')
            .doc(transactionId)
            .get();

        if (transactionDoc.exists) {
          final transactionData = transactionDoc.data()!;
          final userId = transactionData['userId'] as String;
          final amount = (transactionData['amount'] as int).abs();

          
          await _firestore.collection('users').doc(userId).update({
            'diamonds': FieldValue.increment(amount),
          });
          
        }
      }

      await _firestore
          .collection('diamond_transactions')
          .doc(transactionId)
          .update(updateData);

      
      
      return true;
    } catch (e) {
      return false;
    }
  }


  /// Calculate diamond earnings from gift price
  /// Default conversion: 50% of gift price goes to host as diamonds
  int calculateDiamondsFromGift(int giftPrice, {double conversionRate = 0.5}) {
    
    
    

    final diamonds = (giftPrice * conversionRate).toInt();

    
    

    return diamonds;
  }

  /// Check if user can withdraw
  Future<Map<String, dynamic>> canWithdraw({
    required String userId,
    required int amount,
  }) async {
    
    
    

    try {
      // Check minimum withdrawal
      const minWithdrawal = 100;
      if (amount < minWithdrawal) {
        
        return {
          'canWithdraw': false,
          'reason': 'Minimum withdrawal is $minWithdrawal diamonds',
        };
      }

      // Check balance
      final balance = await getDiamondBalance(userId);
      

      if (balance < amount) {
        
        final shortage = amount - balance;
        return {
          'canWithdraw': false,
          'reason': 'Insufficient balance (short by $shortage diamonds)',
        };
      }

      
      

      return {
        'canWithdraw': true,
        'reason': 'Withdrawal approved',
      };
    } catch (e) {
      
      
      
      
      return {
        'canWithdraw': false,
        'reason': 'Error checking withdrawal eligibility: $e',
      };
    }
  }
}
