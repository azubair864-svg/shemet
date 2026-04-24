import 'package:flutter/material.dart';
import 'dart:math';

class ChatEffects extends StatefulWidget {
  const ChatEffects({super.key});

  @override
  State<ChatEffects> createState() => _ChatEffectsState();
}

class _ChatEffectsState extends State<ChatEffects> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<ChatParticle> _particles;

  @override
  void initState() {
    super.initState();
    _particles = List.generate(20, (index) => ChatParticle());
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

            // Gentle floating motion
            final float = sin(progress * pi * 2) * 20;

            return Positioned(
              left: particle.startX,
              top: particle.startY + (particle.endY - particle.startY) * progress + float,
              child: Opacity(
                opacity: (sin(progress * pi)).clamp(0.0, 1.0),
                child: particle.isBubble
                    ? _buildChatBubble(particle)
                    : Text(
                  particle.icon,
                  style: TextStyle(
                    fontSize: particle.size,
                    shadows: [
                      Shadow(
                        color: particle.color.withOpacity(0.4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildChatBubble(ChatParticle particle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: particle.color.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: particle.color.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Text(
        '💬',
        style: TextStyle(fontSize: particle.size * 0.7),
      ),
    );
  }
}

class ChatParticle {
  late double startX;
  late double startY;
  late double endY;
  late double size;
  late String icon;
  late Color color;
  late int duration;
  late bool isBubble;

  ChatParticle() {
    final random = Random();
    startX = random.nextDouble() * 400;
    startY = 700 + random.nextDouble() * 100;
    endY = -100;
    size = 16 + random.nextDouble() * 16;
    duration = 6 + random.nextInt(4);
    isBubble = random.nextDouble() > 0.6;

    final icons = ['😊', '😂', '❤️', '👍', '🎉', '✨', '🌟', '😍', '🔥', '💯'];
    final colors = [
      const Color(0xFF9C27B0),
      const Color(0xFF7B1FA2),
      const Color(0xFFAB47BC),
      const Color(0xFF8E24AA),
    ];

    icon = icons[random.nextInt(icons.length)];
    color = colors[random.nextInt(colors.length)];
  }
}