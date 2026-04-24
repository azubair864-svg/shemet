import 'dart:ui';
import 'package:flutter/material.dart';

class PremiumSeatFrame extends StatelessWidget {
  final Widget child;
  final bool isOccupied;
  final bool isSpeaking;
  final int rank; // 0=None, 1=Top, etc.
  final Color themeColor;
  final double size;
  final bool isVideoOn;

  const PremiumSeatFrame({
    super.key,
    required this.child,
    required this.isOccupied,
    this.isSpeaking = false,
    this.rank = 0,
    required this.themeColor,
    this.size = 85,
    this.isVideoOn = false,
  });

  @override
  Widget build(BuildContext context) {
    // Rank Colors
    Color borderColor = isOccupied 
        ? (rank == 1 ? Colors.amber : (rank == 2 ? Colors.grey.shade300 : themeColor)) 
        : Colors.white.withOpacity(0.1);
    
    // Scale up for speaking effect
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      // transform: isSpeaking ? Matrix4.diagonal3Values(1.05, 1.05, 1) : Matrix4.identity(),
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          
          // 1. Glassmorphic Base
          ClipPath(
            clipper: SquircleClipper(), // Modern "Squircle" shape
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: isVideoOn ? 0 : 10, 
                sigmaY: isVideoOn ? 0 : 10,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: isVideoOn 
                      ? Colors.transparent 
                      : Colors.white.withOpacity(isOccupied ? 0.1 : 0.05),
                  border: Border.all(
                    color: borderColor.withOpacity((isOccupied || isVideoOn) ? 0.6 : 0.2),
                    width: rank > 0 ? 2 : 1.5,
                  ),
                ),
                child: child, // The Avatar
              ),
            ),
          ),

          // 2. Rank Frame (If applicable)
          if (rank > 0)
            Positioned(
              top: -5,
              child: _buildRankCrown(rank),
            ),
        ],
      ),
    );
  }

  Widget _buildRankCrown(int rank) {
    if (rank == 1) {
       return const Text('👑', style: TextStyle(fontSize: 16));
    }
    return const SizedBox.shrink();
  }
}

class SquircleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final width = size.width;
    final height = size.height;
    
    // Smooth Squircle Approximation
    path.moveTo(0, height / 2);
    path.cubicTo(0, height * 0.1, width * 0.1, 0, width / 2, 0);
    path.cubicTo(width * 0.9, 0, width, height * 0.1, width, height / 2);
    path.cubicTo(width, height * 0.9, width * 0.9, height, width / 2, height);
    path.cubicTo(width * 0.1, height, 0, height * 0.9, 0, height / 2);
    path.close();
    
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
