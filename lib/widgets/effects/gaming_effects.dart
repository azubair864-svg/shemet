import 'package:flutter/material.dart';
import 'dart:math' as math;

class GamingEffects extends StatefulWidget {
  final Color themeColor;

  const GamingEffects({super.key, required this.themeColor});

  @override
  State<GamingEffects> createState() => _GamingEffectsState();
}

class _GamingEffectsState extends State<GamingEffects> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late String _randomImage;

  @override
  void initState() {
    super.initState();
    // Randomly select one of the two user images for this session
    _randomImage = math.Random().nextBool() 
        ? 'assets/images/gamming_1.jpg' 
        : 'assets/images/gamming_2.jpg';

    _controller = AnimationController(
       duration: const Duration(seconds: 2),
       vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Background Base Color (Dark)
        Container(color: Colors.black),

        // 2. The Base Image (User's Asset)
        Positioned.fill(
          child: Opacity(
            opacity: 0.6, // Visibility
            child: Image.asset(
             _randomImage,
             fit: BoxFit.cover,
             color: widget.themeColor.withOpacity(0.4), // Theme Tint
             colorBlendMode: BlendMode.hardLight, // "Gaming" Vibe
             errorBuilder: (c, e, s) => CustomPaint(painter: _FallbackTechPainter(color: widget.themeColor)),
            ),
          ),
        ),

        // 3. The Glitch / Scanline Overlay (Code)
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: GamingGlitchPainter(
                color: widget.themeColor,
                progress: _controller.value,
              ),
            );
          },
        ),
      ],
    );
  }
}

// =========================================
// PAINTERS
// =========================================

class GamingGlitchPainter extends CustomPainter {
  final Color color;
  final double progress;

  GamingGlitchPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random((progress * 100).floor());

    // 1. Scanlines (Moving Down)
    final scanLineY = (progress * size.height * 1.5) % size.height;
    final scanPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, color.withOpacity(0.5), Colors.transparent],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, scanLineY - 20, size.width, 40));
    
    canvas.drawRect(Rect.fromLTWH(0, scanLineY - 20, size.width, 40), scanPaint);

    // 2. Glitch Blocks (Random Appearance)
    if (random.nextDouble() > 0.8) {
      final blockX = random.nextDouble() * size.width;
      final blockY = random.nextDouble() * size.height;
      final blockW = random.nextDouble() * 100 + 20;
      final blockH = random.nextDouble() * 10 + 2;
      
      final blockPaint = Paint()
        ..color = color.withOpacity(0.6)
        ..style = PaintingStyle.fill;
        
      canvas.drawRect(Rect.fromLTWH(blockX, blockY, blockW, blockH), blockPaint);
    }

    // 3. Tech Corners (HUD)
    final cornerPaint = Paint()
      ..color = color.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Top Left
    canvas.drawPath(
      Path()..moveTo(20, 50)..lineTo(20, 20)..lineTo(50, 20),
      cornerPaint
    );
    // Bottom Right
    canvas.drawPath(
      Path()..moveTo(size.width - 20, size.height - 50)..lineTo(size.width - 20, size.height - 20)..lineTo(size.width - 50, size.height - 20),
      cornerPaint
    );
  }

  @override
  bool shouldRepaint(GamingGlitchPainter oldDelegate) => oldDelegate.progress != progress;
}

// Fallback if image fails
class _FallbackTechPainter extends CustomPainter {
  final Color color;
  _FallbackTechPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final center = Offset(size.width / 2, size.height / 2);
    
    // Draw a stylized controller shape
    final path = Path();
    path.moveTo(center.dx - 100, center.dy);
    path.cubicTo(center.dx - 150, center.dy - 50, center.dx - 50, center.dy - 100, center.dx, center.dy - 50);
    path.cubicTo(center.dx + 50, center.dy - 100, center.dx + 150, center.dy - 50, center.dx + 100, center.dy);
    path.cubicTo(center.dx + 150, center.dy + 80, center.dx + 80, center.dy + 120, center.dx + 50, center.dy + 80);
    path.cubicTo(center.dx + 20, center.dy + 60, center.dx - 20, center.dy + 60, center.dx - 50, center.dy + 80);
    path.cubicTo(center.dx - 80, center.dy + 120, center.dx - 150, center.dy + 80, center.dx - 100, center.dy);
    
    canvas.drawPath(path, paint);
    canvas.drawPath(path, Paint()..color = color.withOpacity(0.05));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}