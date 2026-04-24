import 'package:flutter/material.dart';

class SeatLockIndicator extends StatelessWidget {
  final bool isLocked;
  final bool isHost;
  final VoidCallback? onToggleLock;

  const SeatLockIndicator({
    super.key,
    required this.isLocked,
    this.isHost = false,
    this.onToggleLock,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLocked && !isHost) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: isHost ? onToggleLock : null,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isLocked
              ? Colors.red.withOpacity(0.9)
              : Colors.grey.withOpacity(0.7),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (isLocked ? Colors.red : Colors.grey).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          isLocked ? Icons.lock : Icons.lock_open,
          color: Colors.white,
          size: 16,
        ),
      ),
    );
  }
}