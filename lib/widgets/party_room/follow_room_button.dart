import 'package:flutter/material.dart';

class FollowRoomButton extends StatefulWidget {
  final String roomId;
  final String userId;
  final bool isFollowing;
  final Function(bool) onToggle;

  const FollowRoomButton({
    super.key,
    required this.roomId,
    required this.userId,
    required this.isFollowing,
    required this.onToggle,
  });

  @override
  State<FollowRoomButton> createState() => _FollowRoomButtonState();
}

class _FollowRoomButtonState extends State<FollowRoomButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    _controller.forward().then((_) => _controller.reverse());
    widget.onToggle(!widget.isFollowing);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTap: _toggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: widget.isFollowing
                    ? LinearGradient(colors: [Colors.grey[700]!, Colors.grey[800]!])
                    : const LinearGradient(colors: [Color(0xFFFF1493), Color(0xFFFF69B4)]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (widget.isFollowing ? Colors.grey : Colors.pink).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.isFollowing ? Icons.star : Icons.star_outline,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.isFollowing ? 'Following' : 'Follow',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}