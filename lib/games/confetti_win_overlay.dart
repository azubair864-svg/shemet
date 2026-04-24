import 'dart:math';
import 'package:flutter/material.dart';

class ConfettiWinOverlay extends StatefulWidget {
  final bool showWin;
  final Widget child;

  const ConfettiWinOverlay({super.key, required this.showWin, required this.child});

  @override
  State<ConfettiWinOverlay> createState() => _ConfettiWinOverlayState();
}

class _ConfettiWinOverlayState extends State<ConfettiWinOverlay> with TickerProviderStateMixin {
  final List<_ConfettiParticle> _particles = [];
  final Random _rnd = Random();
  late AnimationController _mainCtrl;

  @override
  void initState() {
    super.initState();
    _mainCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _mainCtrl.addListener(() {
      setState(() {
        for (var p in _particles) {
          p.update();
        }
      });
    });
  }

  @override
  void didUpdateWidget(ConfettiWinOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showWin && !oldWidget.showWin) {
      _triggerConfetti();
    }
  }

  void _triggerConfetti() {
    _particles.clear();
    // Generate 60 gold coins/confetti pieces bursting from the center
    for (int i = 0; i < 60; i++) {
       double angle = _rnd.nextDouble() * pi * 2;
       double speed = 5 + _rnd.nextDouble() * 15;
       _particles.add(_ConfettiParticle(
           x: 0, 
           y: 0, 
           vx: cos(angle) * speed, 
           vy: sin(angle) * speed - 10, // Initial upward burst
           color: _rnd.nextBool() ? Colors.amber : Colors.yellowAccent,
           size: 10 + _rnd.nextDouble() * 15
       ));
    }
    _mainCtrl.forward(from: 0);
  }

  @override
  void dispose() {
    _mainCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_mainCtrl.isAnimating)
          Positioned.fill(
            child: CustomPaint(
              painter: _ConfettiPainter(_particles),
            ),
          )
      ],
    );
  }
}

class _ConfettiParticle {
  double x, y, vx, vy;
  Color color;
  double size;

  _ConfettiParticle({required this.x, required this.y, required this.vx, required this.vy, required this.color, required this.size});

  void update() {
    x += vx;
    y += vy;
    vy += 0.8; // Gravity
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;

  _ConfettiPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (var p in particles) {
      final paint = Paint()..color = p.color;
      canvas.drawCircle(center + Offset(p.x, p.y), p.size / 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
