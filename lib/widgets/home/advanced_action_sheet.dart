import 'dart:ui';
import 'package:flutter/material.dart';

class AdvancedActionSheet extends StatefulWidget {
  const AdvancedActionSheet({super.key});

  @override
  State<AdvancedActionSheet> createState() => _AdvancedActionSheetState();
}

class _AdvancedActionSheetState extends State<AdvancedActionSheet> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                children: [
                  _buildActionItem(
                    context,
                    title: 'Go Live',
                    subtitle: 'Start live streaming',
                    icon: Icons.videocam,
                    gradient: const LinearGradient(colors: [Color(0xFFFF1493), Color(0xFFFF69B4)]),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/broadcast_setup'); // Updated route
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  _buildActionItem(
                    context,
                    title: 'Create Party Room',
                    subtitle: 'Start voice chat room',
                    icon: Icons.groups,
                    gradient: const LinearGradient(colors: [Color(0xFF9C27B0), Color(0xFFE040FB)]),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/create_party_room');
                    },
                  ),
                  const SizedBox(height: 12),

                  _buildActionItem(
                    context,
                    title: 'Random Call',
                    subtitle: 'Video/Voice call with random users',
                    icon: Icons.phone_in_talk,
                    gradient: const LinearGradient(colors: [Color(0xFF00BCD4), Color(0xFF26C6DA)]),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/random_call');
                    },
                  ),
                  // Removed extra items as per client request
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (gradient.colors.first).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }
}
