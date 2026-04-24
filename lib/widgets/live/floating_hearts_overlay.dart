import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class FloatingHeartsOverlay extends StatefulWidget {
  final StreamController<void>? triggerStream;

  const FloatingHeartsOverlay({super.key, this.triggerStream});

  @override
  State<FloatingHeartsOverlay> createState() => _FloatingHeartsOverlayState();
}

class _FloatingHeartsOverlayState extends State<FloatingHeartsOverlay>
    with TickerProviderStateMixin {
  final List<_HeartData> _hearts = [];
  final math.Random _random = math.Random();
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.triggerStream?.stream.listen((_) {
      _addHeart();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    for (var heart in _hearts.toList()) {
      heart.controller.dispose();
    }
    super.dispose();
  }

  void _addHeart() {
    if (!mounted) return;

    final controller = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    final heart = _HeartData(
      controller: controller,
      color: Colors.primaries[_random.nextInt(Colors.primaries.length)]
          .withOpacity(0.9),
      xOffset: _random.nextDouble() * 120 - 60,
      size: 24.0 + _random.nextDouble() * 16,
    );

    setState(() {
      _hearts.add(heart);
    });

    controller.forward().then((_) {
      if (mounted) {
        setState(() {
          _hearts.remove(heart);
        });
        controller.dispose();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: _hearts.map((heart) {
        return AnimatedBuilder(
          animation: heart.controller,
          builder: (context, child) {
            final progress = heart.controller.value;
            // Float upwards and fade out
            final bottom = 120 + (progress * 500);
            final opacity = 1.0 - (progress * 1.2).clamp(0.0, 1.0);
            
            // Horizontal sway + natural float
            final horizontalSway = math.sin(progress * math.pi * 3) * 30;

            return Positioned(
              bottom: bottom,
              right: 60 + horizontalSway + heart.xOffset,
              child: Opacity(
                opacity: opacity,
                child: Hero(
                  tag: 'heart_${heart.hashCode}',
                  child: Icon(
                    Icons.favorite,
                    color: heart.color,
                    size: heart.size,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }).toList(),
    );
  }
}

class _HeartData {
  final AnimationController controller;
  final Color color;
  final double xOffset;
  final double size;

  _HeartData({
    required this.controller,
    required this.color,
    required this.xOffset,
    required this.size,
  });
}
