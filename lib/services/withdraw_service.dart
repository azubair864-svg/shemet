import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class WithdrawService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // Singleton pattern
  static final WithdrawService _instance = WithdrawService._internal();
  factory WithdrawService() => _instance;
  WithdrawService._internal();

  /// Request a withdrawal via Secure Cloud Function
  /// Returns a Map with { success: bool, message: String, requestId: String? }
  Future<Map<String, dynamic>> requestWithdrawal({
    required double amount,
    required String method,
    required Map<String, dynamic> methodDetails,
  }) async {
    
    
    

    try {
      // Call the Cloud Function
      // This ensures the server handles the balance check and deduction atomically
      final HttpsCallable callable = _functions.httpsCallable('requestWithdrawal');
      
      final result = await callable.call({
        'amount': amount,
        'method': method,
        'methodDetails': methodDetails,
      });

      final data = result.data as Map<String, dynamic>;
      
      
      
      

      return {
        'success': true,
        'message': 'Withdrawal request submitted successfully',
        'requestId': data['requestId'],
      };

    } on FirebaseFunctionsException catch (e) {
      
      
      
      
      
      
      return {
        'success': false, 
        'message': e.message ?? 'An unknown error occurred',
      };
    } catch (e) {
      
      
      
      
      return {
        'success': false,
        'message': 'Failed to connect to the server. Please try again.',
      };
    }
  }

  /// Get withdrawal history for the current user
  /// We read DIRECTLY from Firestore because:
  /// 1. Reading your own data is safe (controlled by Security Rules).
  /// 2. It's faster and cheaper than invoking a function just to read data.
  Stream<List<Map<String, dynamic>>> getWithdrawHistoryStream(String userId) {
    return _firestore
        .collection('withdraw_requests')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          // Helper for UI to show formatted date
          'createdAtDate': (data['createdAt'] as Timestamp?)?.toDate(),
        };
      }).toList();
    });
  }

  /// Cancel a pending withdrawal
  Future<bool> cancelWithdrawal(String requestId) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('cancelWithdrawal');
      await callable.call({'requestId': requestId});
      return true;
    } catch (e) {
      
      return false;
    }
  }
}
