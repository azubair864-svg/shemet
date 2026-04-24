import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class RandomMatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  StreamSubscription? _queueSubscription;
  
  /// Joins the matchmaking queue
  Future<void> joinQueue({
    required String gender,
    required String preference,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('random_match_queue').doc(user.uid).set({
      'uid': user.uid,
      'gender': gender,
      'preference': preference,
      'status': 'searching',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Leaves the matchmaking queue
  Future<void> leaveQueue() async {
    final user = _auth.currentUser;
    if (user == null) return;

    _queueSubscription?.cancel();
    await _firestore.collection('random_match_queue').doc(user.uid).delete();
  }

  /// Listens to the queue status for a match
  void listenToMatchStatus({
    required Function(String sessionId) onMatched,
    required Function() onCanceled,
  }) {
    final user = _auth.currentUser;
    if (user == null) return;

    _queueSubscription?.cancel();
    _queueSubscription = _firestore
        .collection('random_match_queue')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) return;

      final data = snapshot.data();
      if (data == null) return;

      final status = data['status'];
      if (status == 'matched') {
        final sessionId = data['sessionId'];
        if (sessionId != null) {
          onMatched(sessionId);
        }
      } else if (status == 'canceled') {
        onCanceled();
      }
    });
  }

  /// Fetches session details
  Future<Map<String, dynamic>?> getSession(String sessionId) async {
    final doc = await _firestore.collection('match_sessions').doc(sessionId).get();
    return doc.data();
  }

  /// Cleans up subscriptions
  void dispose() {
    _queueSubscription?.cancel();
  }
}
