import 'package:flutter/material.dart';

class PartyActionSheet extends StatelessWidget {
  final VoidCallback onJoinPressed;
  final VoidCallback onMessagesPressed;
  final VoidCallback onSharePressed;
  final VoidCallback onTopUpPressed;

  final VoidCallback onBeautyPressed; // Add this

  const PartyActionSheet({
    super.key,
    required this.onJoinPressed,
    required this.onMessagesPressed,
    required this.onSharePressed,
    required this.onTopUpPressed,
    required this.onBeautyPressed, // Add this
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceAround,
            spacing: 20,
            runSpacing: 20,
            children: [
              _buildActionItem(
                icon: Icons.mic,
                label: 'Join',
                color: const Color(0xFF9C27B0),
                onTap: onJoinPressed,
              ),
              _buildActionItem(
                icon: Icons.message,
                label: 'Messages',
                color: const Color(0xFFFF4081),
                onTap: onMessagesPressed,
              ),
              _buildActionItem(
                icon: Icons.share,
                label: 'Share',
                color: const Color(0xFFFF5252),
                onTap: onSharePressed,
              ),
              _buildActionItem(
                icon: Icons.diamond,
                label: 'Top Up',
                color: const Color(0xFFFFC107),
                onTap: onTopUpPressed,
              ),
              _buildActionItem(
                icon: Icons.face, 
                label: 'Beauty',
                color: const Color(0xFF00BCD4), // Cyan
                onTap: onBeautyPressed,
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Optional Cancel button or just tap outside
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.8),
                  color,
                ],
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
