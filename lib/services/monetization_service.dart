import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/gift_model.dart';
import '../models/diamond_package_model.dart';
import '../models/payment_method_model.dart';
import '../models/topup_request_model.dart';
import '../models/user_model.dart';

class MonetizationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // ============================================
  // GIFTS CATALOG
  // ============================================

  /// Stream gifts by category (CLASSIC, POPULAR, LUXURY, EXCLUSIVE)
  Stream<List<GiftModel>> streamGiftsByCategory(String category) {
    return _firestore
        .collection('gifts')
        .where('category', isEqualTo: category)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => GiftModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  /// Send a gift securely via Cloud Functions
  Future<Map<String, dynamic>> sendGift({
    required String roomId,
    required String receiverId,
    required String giftId,
    int quantity = 1,
  }) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('sendGift');
      final result = await callable.call(<String, dynamic>{
        'roomId': roomId,
        'receiverId': receiverId,
        'giftId': giftId,
        'quantity': quantity,
      });
      return {'success': true, 'data': result.data};
    } on FirebaseFunctionsException catch (e) {
      return {'success': false, 'error': e.message ?? e.code};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ============================================
  // TOP-UP CATALOG (RECOMMEND TAB)
  // ============================================

  /// Fetch active manual diamond packages
  Future<List<DiamondPackageModel>> getDiamondPackages() async {
    try {
      final snapshot = await _firestore
          .collection('diamond_packages')
          .where('isActive', isEqualTo: true)
          // Ordered by diamonds value
          .orderBy('diamonds')
          .get();
      return snapshot.docs
          .map((doc) => DiamondPackageModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error fetching diamond packages: $e');
      return [];
    }
  }

  /// Fetch active payment methods (Easypaisa, Bank, etc.)
  Future<List<PaymentMethodModel>> getPaymentMethods() async {
    try {
      final snapshot = await _firestore
          .collection('payment_methods')
          .where('isActive', isEqualTo: true)
          .get();
      return snapshot.docs
          .map((doc) => PaymentMethodModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error fetching payment methods: $e');
      return [];
    }
  }

  /// Submit a manual top-up request (with receipt)
  Future<bool> submitTopUpRequest(TopUpRequestModel request) async {
    try {
      await _firestore
          .collection('topup_requests')
          .doc(request.id.isEmpty ? null : request.id)
          .set(request.toMap(), SetOptions(merge: true));
      return true;
    } catch (e) {
      print('Error submitting top up request: $e');
      return false;
    }
  }

  // ============================================
  // AGENTS CATALOG (HELPER TAB)
  // ============================================

  /// Fetch users with the 'agent' role
  Future<List<UserModel>> getAgents() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'agent')
          .limit(2) // PRODUCTION: Limit to 2 agents as requested by client
          .get();
      return snapshot.docs
          .map((doc) {
            final data = doc.data();
            data['uid'] = doc.id;
            return UserModel.fromMap(data);
          })
          .toList();
    } catch (e) {
      print('Error fetching agents: $e');
      return [];
    }
  }
}
