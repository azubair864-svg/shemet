import 'package:flutter/material.dart';
import 'dart:math';

class DiamondRainAnimation extends StatefulWidget {
  final bool isActive;

  const DiamondRainAnimation({
    super.key,
    this.isActive = true,
  });

  @override
  State<DiamondRainAnimation> createState() => _DiamondRainAnimationState();
}

class _DiamondRainAnimationState extends State<DiamondRainAnimation>
    with TickerProviderStateMixin {
  final List<DiamondParticle> _diamonds = [];
  final Random _random = Random();
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    )..addListener(() {
      if (widget.isActive) {
        _updateDiamonds();
      }
    });

    _controller.repeat();
    _initializeDiamonds();
  }

  void _initializeDiamonds() {
    // Start with 15 diamonds at random positions
    for (int i = 0; i < 15; i++) {
      _diamonds.add(_createDiamond());
    }
  }

  DiamondParticle _createDiamond() {
    return DiamondParticle(
      x: _random.nextDouble(),
      y: _random.nextDouble() * -0.5, // Start above screen
      speed: 0.003 + _random.nextDouble() * 0.007,
      size: 30 + _random.nextDouble() * 30,
      rotation: _random.nextDouble() * 2 * pi,
      rotationSpeed: (_random.nextDouble() - 0.5) * 0.2,
    );
  }

  void _updateDiamonds() {
    setState(() {
      for (var diamond in _diamonds) {
        diamond.y += diamond.speed;
        diamond.rotation += diamond.rotationSpeed;

        // Reset diamond if it goes off screen
        if (diamond.y > 1.2) {
          diamond.y = -0.1;
          diamond.x = _random.nextDouble();
          diamond.speed = 0.003 + _random.nextDouble() * 0.007;
          diamond.size = 30 + _random.nextDouble() * 30;
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: CustomPaint(
        painter: DiamondPainter(_diamonds),
        child: Container(),
      ),
    );
  }
}

class DiamondParticle {
  double x;
  double y;
  double speed;
  double size;
  double rotation;
  double rotationSpeed;

  DiamondParticle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
  });
}

class DiamondPainter extends CustomPainter {
  final List<DiamondParticle> diamonds;

  DiamondPainter(this.diamonds);

  @override
  void paint(Canvas canvas, Size size) {
    for (var diamond in diamonds) {
      final position = Offset(
        diamond.x * size.width,
        diamond.y * size.height,
      );

      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(diamond.rotation);

      // Draw diamond shadow
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawCircle(
        const Offset(2, 2),
        diamond.size / 2,
        shadowPaint,
      );

      // Draw diamond body (blue/cyan gradient for diamonds)
      final diamondRect = Rect.fromCircle(
        center: Offset.zero,
        radius: diamond.size / 2,
      );

      const gradient = RadialGradient(
        colors: [
          Color(0xFF00BFFF), // Deep Sky Blue
          Color(0xFF00E5FF), // Cyan
          Color(0xFFE0F7FA), // Very light cyan
        ],
        stops: [0.0, 0.7, 1.0],
      );

      final diamondPaint = Paint()
        ..shader = gradient.createShader(diamondRect)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset.zero, diamond.size / 2, diamondPaint);

      // Draw diamond border
      final borderPaint = Paint()
        ..color = const Color(0xFFB2EBF2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawCircle(Offset.zero, diamond.size / 2 - 1, borderPaint);

      // Draw inner shine
      final shinePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(-diamond.size * 0.15, -diamond.size * 0.15),
        diamond.size * 0.2,
        shinePaint,
      );

      // Draw diamond symbol in center
      final textPainter = TextPainter(
        text: const TextSpan(
          text: '💎',
          style: TextStyle(fontSize: 16),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(DiamondPainter oldDelegate) => true;
}