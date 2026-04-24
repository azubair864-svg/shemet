import 'package:flutter/material.dart';

class PartyRoomSimpleHeader extends StatelessWidget {
  final String appName;
  final String hostName;
  final int totalDiamonds;

  const PartyRoomSimpleHeader({
    super.key,
    required this.appName,
    required this.hostName,
    required this.totalDiamonds,
    this.onHostTap,
  });

  final VoidCallback? onHostTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0), // REMOVED vertical padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // App name with logo + Host name
          GestureDetector(
            onTap: onHostTap,
            child: Row(
              children: [
                Container(
                  width: 22, // REDUCED: 24 → 22
                  height: 22,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF69B4), Color(0xFFFF1493)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.celebration,
                    color: Colors.white,
                    size: 12, // REDUCED
                  ),
                ),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      appName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13, // REDUCED: 14 → 13
                        fontWeight: FontWeight.bold,
                        height: 1.1, // TIGHT line height
                      ),
                    ),
                    Text(
                      hostName,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 10, // REDUCED: 11 → 10
                        fontWeight: FontWeight.w400,
                        height: 1.1, // TIGHT line height
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 3), // REDUCED: 4 → 3

          // Total diamonds
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), // REDUCED
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('💎', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 3),
                Text(
                  _formatDiamonds(totalDiamonds),
                  style: const TextStyle(
                    color: Colors.yellow,
                    fontSize: 12, // REDUCED: 13 → 12
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDiamonds(int diamonds) {
    if (diamonds >= 1000000) {
      return '${(diamonds / 1000000).toStringAsFixed(1)}M';
    } else if (diamonds >= 1000) {
      return '${(diamonds / 1000).toStringAsFixed(1)}K';
    }
    return diamonds.toString();
  }
}