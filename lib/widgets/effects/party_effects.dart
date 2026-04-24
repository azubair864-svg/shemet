import 'package:flutter/material.dart';
import 'dart:math';

class PartyEffects extends StatefulWidget {
  const PartyEffects({super.key});

  @override
  State<PartyEffects> createState() => _PartyEffectsState();
}

class _PartyEffectsState extends State<PartyEffects> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<PartyParticle> _particles;

  @override
  void initState() {
    super.initState();
    _particles = List.generate(35, (index) => PartyParticle());
    _controllers = List.generate(
      _particles.length,
          (index) => AnimationController(
        vsync: this,
        duration: Duration(seconds: _particles[index].duration),
      )..repeat(),
    );
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(
        _particles.length,
            (index) => AnimatedBuilder(
          animation: _controllers[index],
          builder: (context, child) {
            final particle = _particles[index];
            final progress = _controllers[index].value;

            // Spiral falling motion
            final spiral = cos(progress * pi * 6) * particle.spiralRadius;

            return Positioned(
              left: particle.startX + spiral,
              top: particle.startY + (particle.endY - particle.startY) * progress,
              child: Opacity(
                opacity: (1 - progress * 0.7).clamp(0.0, 1.0),
                child: Transform.rotate(
                  angle: progress * pi * 8,
                  child: Container(
                    width: particle.size,
                    height: particle.size,
                    decoration: BoxDecoration(
                      color: particle.color,
                      shape: particle.isCircle ? BoxShape.circle : BoxShape.rectangle,
                      boxShadow: [
                        BoxShadow(
                          color: particle.color.withOpacity(0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class PartyParticle {
  late double startX;
  late double startY;
  late double endY;
  late double size;
  late double spiralRadius;
  late Color color;
  late int duration;
  late bool isCircle;

  PartyParticle() {
    final random = Random();
    startX = random.nextDouble() * 400;
    startY = -50;
    endY = 900;
    size = 8 + random.nextDouble() * 12;
    spiralRadius = 30 + random.nextDouble() * 40;
    duration = 3 + random.nextInt(4);
    isCircle = random.nextBool();

    final colors = [
      const Color(0xFFFF00FF),
      const Color(0xFF00FFFF),
      const Color(0xFFFFFF00),
      const Color(0xFFFF0080),
      const Color(0xFF00FF80),
      const Color(0xFF8000FF),
    ];

    color = colors[random.nextInt(colors.length)];
  }
}