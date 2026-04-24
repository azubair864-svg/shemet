import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminBroadcastListener extends StatefulWidget {
  final Widget child;

  const AdminBroadcastListener({super.key, required this.child});

  @override
  State<AdminBroadcastListener> createState() => _AdminBroadcastListenerState();
}

class _AdminBroadcastListenerState extends State<AdminBroadcastListener> {
  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    FirebaseFirestore.instance
        .collection('admin_broadcasts')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            final broadcast = snapshot.docs.first;
            final broadcastId = broadcast.id;
            final data = broadcast.data();

            _checkAndShowBroadcast(broadcastId, data);
          }
        });
  }

  Future<void> _checkAndShowBroadcast(
    String id,
    Map<String, dynamic> data,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final lastSeenId = prefs.getString('last_seen_broadcast_id');

    if (lastSeenId != id) {
      // New broadcast found!
      if (mounted) {
        _showBroadcastDialog(id, data);
      }
    }
  }

  void _showBroadcastDialog(String id, Map<String, dynamic> data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.campaign, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                data['title'] ?? 'Official Announcement',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data['message'] ?? '', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            Text(
              'From: ${data['senderName'] ?? 'Admin'}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('last_seen_broadcast_id', id);
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
