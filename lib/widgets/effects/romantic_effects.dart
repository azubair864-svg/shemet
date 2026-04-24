import 'package:flutter/material.dart';
import 'dart:math';

class RomanticEffects extends StatefulWidget {
  const RomanticEffects({super.key});

  @override
  State<RomanticEffects> createState() => _RomanticEffectsState();
}

class _RomanticEffectsState extends State<RomanticEffects> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<RomanticParticle> _particles;

  @override
  void initState() {
    super.initState();
    _particles = List.generate(25, (index) => RomanticParticle());
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

            // Floating wave motion
            final wave = sin(progress * pi * 4) * 30;

            return Positioned(
              left: particle.startX + wave,
              top: particle.startY + (particle.endY - particle.startY) * progress,
              child: Opacity(
                opacity: (1 - progress * 0.8).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 1 - progress * 0.3,
                  child: Text(
                    particle.icon,
                    style: TextStyle(
                      fontSize: particle.size,
                      shadows: [
                        Shadow(
                          color: particle.color.withOpacity(0.6),
                          blurRadius: 15,
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

class RomanticParticle {
  late double startX;
  late double startY;
  late double endY;
  late double size;
  late String icon;
  late Color color;
  late int duration;

  RomanticParticle() {
    final random = Random();
    startX = random.nextDouble() * 400;
    startY = 600 + random.nextDouble() * 200;
    endY = -100;
    size = 18 + random.nextDouble() * 18;
    duration = 5 + random.nextInt(5);

    final icons = ['💕', '💖', '💗', '💓', '💞', '💝', '🌹', '✨', '💐', '🦋'];
    final colors = [
      const Color(0xFFFF69B4),
      const Color(0xFFFF1493),
      const Color(0xFFFFB6C1),
      const Color(0xFFFFC0CB),
    ];

    icon = icons[random.nextInt(icons.length)];
    color = colors[random.nextInt(colors.length)];
  }
}