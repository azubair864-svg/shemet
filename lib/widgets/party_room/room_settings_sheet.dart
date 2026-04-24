import 'package:flutter/material.dart';
import '../../services/database_service.dart';

class RoomSettingsSheet extends StatefulWidget {
  final String roomId;
  final bool initialAllowFreeJoin;

  const RoomSettingsSheet({
    super.key,
    required this.roomId,
    required this.initialAllowFreeJoin,
  });

  @override
  State<RoomSettingsSheet> createState() => _RoomSettingsSheetState();
}

class _RoomSettingsSheetState extends State<RoomSettingsSheet> {
  late bool _allowFreeJoin;
  final DatabaseService _databaseService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _allowFreeJoin = widget.initialAllowFreeJoin;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1033),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 24),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            'Room Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          
          // Allow Free Join Toggle
          SwitchListTile(
            title: const Text(
              'Allow Free Joining',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'Anyone can join a seat without waiting for approval',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            value: _allowFreeJoin,
            activeThumbColor: const Color(0xFFFF1493),
            onChanged: (val) async {
              setState(() => _allowFreeJoin = val);
              await _databaseService.updateRoomSettings(
                roomId: widget.roomId,
                settings: {'allowFreeJoin': val},
              );
            },
          ),
          
          const SizedBox(height: 32),
          
          // Close button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Close'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
