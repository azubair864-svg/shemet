import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  try {
    final snapshot = await FirebaseFirestore.instance.collection('users').limit(1).get();
    for (var doc in snapshot.docs) {
      print("===== USER ${doc.id}: profileComplete = ${doc.data()['profileComplete']} =====");
    }
  } catch (e) {
    print("===== ERROR: $e =====");
  }
}
