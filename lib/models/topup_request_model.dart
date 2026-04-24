import 'package:cloud_firestore/cloud_firestore.dart';

class TopUpRequestModel {
  final String id;
  final String userId;
  final String packageId;
  final String paymentMethodId;
  final String receiptImageUrl;
  final String status; // 'pending', 'approved', 'rejected'
  final int diamondsRequested;
  final DateTime? timestamp;

  TopUpRequestModel({
    required this.id,
    required this.userId,
    required this.packageId,
    required this.paymentMethodId,
    required this.receiptImageUrl,
    required this.diamondsRequested,
    this.status = 'pending',
    this.timestamp,
  });

  factory TopUpRequestModel.fromMap(Map<String, dynamic> map, String docId) {
    return TopUpRequestModel(
      id: docId,
      userId: map['userId'] ?? '',
      packageId: map['packageId'] ?? '',
      paymentMethodId: map['paymentMethodId'] ?? '',
      receiptImageUrl: map['receiptImageUrl'] ?? '',
      status: map['status'] ?? 'pending',
      diamondsRequested: map['diamondsRequested'] ?? map['coinsRequested'] ?? 0,
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'packageId': packageId,
      'paymentMethodId': paymentMethodId,
      'receiptImageUrl': receiptImageUrl,
      'status': status,
      'diamondsRequested': diamondsRequested,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
