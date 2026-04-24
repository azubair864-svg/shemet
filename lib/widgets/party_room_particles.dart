import 'dart:math';
import 'package:flutter/material.dart';

class PartyRoomParticles extends StatefulWidget {
  final int particleCount;
  final Color particleColor;

  const PartyRoomParticles({
    super.key,
    this.particleCount = 30,
    this.particleColor = Colors.white,
  });

  @override
  State<PartyRoomParticles> createState() => _PartyRoomParticlesState();
}

class _PartyRoomParticlesState extends State<PartyRoomParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _initializeParticles();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  void _initializeParticles() {
    for (int i = 0; i < widget.particleCount; i++) {
      _particles.add(Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: _random.nextDouble() * 3 + 1,
        speed: _random.nextDouble() * 0.5 + 0.2,
        opacity: _random.nextDouble() * 0.5 + 0.2,
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        _updateParticles();
        return CustomPaint(
          painter: ParticlePainter(
            particles: _particles,
            color: widget.particleColor,
          ),
          size: Size.infinite,
        );
      },
    );
  }

  void _updateParticles() {
    for (var particle in _particles) {
      particle.y -= particle.speed * 0.001;
      if (particle.y < 0) {
        particle.y = 1.0;
        particle.x = _random.nextDouble();
      }
    }
  }
}

class Particle {
  double x;
  double y;
  final double size;
  final double speed;
  final double opacity;

  Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final Color color;

  ParticlePainter({
    required this.particles,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      final paint = Paint()
        ..color = color.withValues(alpha: particle.opacity)
        ..style = PaintingStyle.fill;

      final position = Offset(
        particle.x * size.width,
        particle.y * size.height,
      );

      // Draw star shape
      _drawStar(canvas, position, particle.size, paint, particle.opacity);
    }
  }

  void _drawStar(Canvas canvas, Offset center, double size, Paint paint, double opacity) {
    final path = Path();
    final double radius = size;
    final int points = 5;

    for (int i = 0; i < points * 2; i++) {
      final double angle = (i * pi) / points - pi / 2;
      final double r = i.isEven ? radius : radius / 2;
      final double x = center.dx + r * cos(angle);
      final double y = center.dy + r * sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    path.close();
    canvas.drawPath(path, paint);

    // Add glow effect
    final glowPaint = Paint()
      ..color = color.withValues(alpha: opacity * 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    canvas.drawPath(path, glowPaint);
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) => true;
}