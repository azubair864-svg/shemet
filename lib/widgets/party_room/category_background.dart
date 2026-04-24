import 'package:flutter/material.dart';
import 'dart:math' as math;
// For ImageFilter
import 'package:sensors_plus/sensors_plus.dart'; // For Parallax
// For 3D Tilt

class CategoryBackground extends StatefulWidget {
  final String category;
  final Color themeColor;
  final String? backgroundImage; // Added for sync

  const CategoryBackground({
    super.key,
    required this.category,
    required this.themeColor,
    this.backgroundImage,
  });

  @override
  _CategoryBackgroundState createState() => _CategoryBackgroundState();
}

class _CategoryBackgroundState extends State<CategoryBackground>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _pulseController; // For "Voice Pulse" simulation
  late String _backgroundImage;

  // Gyroscope Data
  double _xTilt = 0.0;
  double _yTilt = 0.0;

  // Touch Ripples
  final List<_Ripple> _ripples = [];

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      duration: const Duration(seconds: 10), // Long cycle for ambient moves
      vsync: this,
    )..repeat();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true); // Simulates breathing/voice

    if (widget.backgroundImage != null && widget.backgroundImage!.isNotEmpty) {
      _backgroundImage = widget.backgroundImage!;
    } else {
      _selectRandomImage();
    }
    _listenToSensors();
  }

  void _selectRandomImage() {
    final random = math.Random();
    final isOption1 = random.nextBool();
    final suffix = isOption1 ? '_1.png' : '_2.png';

    String prefix = 'chat_bg';
    switch (widget.category.toLowerCase()) {
      case 'gaming':
        prefix = 'gamming_bg';
        break;
      case 'music':
        prefix = 'music_bg';
        break;
      case 'dating':
      case 'romantic':
        prefix = 'romantic_bg';
        break;
      case 'pk':
        prefix = 'pk_bg';
        break;
      case 'chat':
        prefix = 'chat_bg';
        break;
    }

    _backgroundImage = 'assets/images/$prefix$suffix';
  }

  void _listenToSensors() {
    // Basic Gyroscope Parallax
    // We try/catch in case sensors are unavailable (e.g. simulator)
    try {
      gyroscopeEvents.listen((GyroscopeEvent event) {
        if (mounted) {
          setState(() {
            // Smooth damping
            _xTilt += event.y * 0.5; // Y rotation affects X tilt
            _yTilt += event.x * 0.5; // X rotation affects Y tilt

            // Clamp values so image doesn't fly off
            _xTilt = _xTilt.clamp(-5.0, 5.0);
            _yTilt = _yTilt.clamp(-5.0, 5.0);
          });
        }
      });
    } catch (e) {
      debugPrint('Sensors not available: $e');
    }
  }

  void _addRipple(TapDownDetails details) {
    setState(() {
      _ripples.add(
        _Ripple(
          position: details.localPosition,
          controller:
              AnimationController(
                  duration: const Duration(milliseconds: 1000),
                  vsync: this,
                )
                ..forward().then((_) {
                  _ripples.removeWhere((r) => r.controller.isCompleted);
                }),
        ),
      );
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    for (var r in _ripples) {
      r.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Theme Feature Detection (Color -> Feature)
    final themeFeature = _getThemeFeature(widget.themeColor);

    return GestureDetector(
      onTapDown: _addRipple,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ============================================
          // LAYER 1: BASE IMAGE + PARALLAX
          // ============================================
          Container(color: Colors.black), // Safety BG
          AnimatedBuilder(
            animation: _mainController, // Just to rebuild if needed
            builder: (context, child) {
              return Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // Perspective
                  ..rotateX(_yTilt * 0.01)
                  ..rotateY(_xTilt * 0.01),
                alignment: Alignment.center,
                child: Transform.scale(
                  scale: 1.01, // Reduced zoom from 1.03 for maximum visibility
                  child: Image.asset(
                    _backgroundImage,
                    fit: BoxFit.cover,
                    // CINEMATIC TINT LAYER 1 (Overlay)
                    color: widget.themeColor.withOpacity(0.4),
                    colorBlendMode: BlendMode.overlay,
                    errorBuilder: (c, e, s) =>
                        Container(color: widget.themeColor.withOpacity(0.2)),
                  ),
                ),
              );
            },
          ),

          // CINEMATIC TINT LAYER 2 (Color Enforcement)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  widget.themeColor.withOpacity(0.1),
                  widget.themeColor.withOpacity(0.4), // Darker bottom
                ],
              ),
            ),
          ),

          // ============================================
          // LAYER 2: CATEGORY EFFECT (3D)
          // ============================================
          AnimatedBuilder(
            animation: _mainController,
            builder: (context, child) {
              return CustomPaint(
                painter: _getCategoryPainter(
                  widget.category,
                  widget.themeColor,
                  _mainController.value,
                ),
                size: Size.infinite,
              );
            },
          ),

          // ============================================
          // LAYER 3: THEME FEATURE (Specific Particles)
          // ============================================
          AnimatedBuilder(
            animation: _mainController,
            builder: (context, child) {
              return CustomPaint(
                painter: _getThemeParticlePainter(
                  themeFeature,
                  widget.themeColor,
                  _mainController.value,
                ),
                size: Size.infinite,
              );
            },
          ),

          // ============================================
          // LAYER 4: GOD RAYS (Volumetric Lighting)
          // ============================================
          AnimatedBuilder(
            animation: _mainController,
            builder: (context, child) {
              return CustomPaint(
                painter: GodRaysPainter(
                  color: widget.themeColor,
                  progress: _mainController.value,
                ),
                size: Size.infinite,
              );
            },
          ),

          // ============================================
          // LAYER 5: INTERACTIVE RIPPLES
          // ============================================
          ..._ripples.map((ripple) {
            return AnimatedBuilder(
              animation: ripple.controller,
              builder: (context, child) {
                final progress = ripple.controller.value;
                final opacity = 1.0 - progress;
                final radius = progress * 200;

                return Positioned(
                  left: ripple.position.dx - radius,
                  top: ripple.position.dy - radius,
                  child: IgnorePointer(
                    child: Container(
                      width: radius * 2,
                      height: radius * 2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.themeColor.withOpacity(opacity),
                          width: 4,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }),

          // ============================================
          // LAYER 6: VOICE PULSE VIGNETTE
          // ============================================
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius:
                        1.5 +
                        (_pulseController.value * 0.1), // Expands/Contracts
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(
                        0.3 + (_pulseController.value * 0.2),
                      ),
                    ],
                    stops: const [0.5, 1.0],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Helper to determine feature from color
  String _getThemeFeature(Color color) {
    // Rough color matching
    final r = color.red;
    final g = color.green;
    final b = color.blue;

    if (r > 200 && g > 150) return 'gold_embers'; // Gold/Orange
    if (b > 200 && g > 200) return 'ice_snow'; // Cyan/Blue
    if (b > 200) return 'ice_snow'; // Blue
    if (g > 200 && r < 100) return 'matrix_code'; // Green
    if (r > 200 && b > 100) return 'rose_petals'; // Pink/Red
    if (r > 100 && b > 200) return 'nebula_mist'; // Purple
    return 'nebula_mist'; // Default fallback
  }

  CustomPainter _getCategoryPainter(
    String category,
    Color color,
    double progress,
  ) {
    switch (category.toLowerCase()) {
      case 'gaming':
        return GamingGlitchPainter(color: color, progress: progress);
      case 'music':
        return MusicWavePainter(color: color, progress: progress);
      case 'dating':
      case 'romantic':
        return RomanticHeartPainter(color: color, progress: progress);
      case 'pk':
        return PKBattlePainter(color: color, progress: progress);
      case 'chat':
      default:
        return ChatAmbientPainter(color: color, progress: progress);
    }
  }

  CustomPainter _getThemeParticlePainter(
    String feature,
    Color color,
    double progress,
  ) {
    switch (feature) {
      case 'gold_embers':
        return EmbersPainter(color: color, progress: progress);
      case 'ice_snow':
        return SnowPainter(color: color, progress: progress);
      case 'matrix_code':
        return MatrixPainter(color: color, progress: progress);
      case 'rose_petals':
        return PetalsPainter(color: color, progress: progress);
      case 'nebula_mist':
      default:
        return NebulaPainter(color: color, progress: progress);
    }
  }
}

class _Ripple {
  final Offset position;
  final AnimationController controller;
  _Ripple({required this.position, required this.controller});
}

// ============================================
// PAINTERS (Category + Theme)
// ============================================

// --- GOD RAYS (Common) ---
class GodRaysPainter extends CustomPainter {
  final Color color;
  final double progress;
  GodRaysPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withOpacity(0.0),
          color.withOpacity(0.15),
          color.withOpacity(0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final center = Offset(size.width / 2, size.height / 2);

    // Draw 3 rotating beams
    for (int i = 0; i < 3; i++) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate((progress * math.pi * 2) + (i * math.pi / 1.5));
      canvas.drawRect(
        Rect.fromLTWH(-50, -size.height, 100, size.height * 2),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant GodRaysPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// --- THEME PARTICLES ---

class EmbersPainter extends CustomPainter {
  // Gold
  final Color color;
  final double progress;
  EmbersPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(123);
    final paint = Paint()
      ..color = Colors.amber.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 30; i++) {
      final x = random.nextDouble() * size.width;
      // Float UP
      final startY = size.height + 20;
      final speed = 100 + random.nextDouble() * 200;
      final y = (startY - (progress * speed + i * 50)) % (size.height + 50);

      canvas.drawCircle(Offset(x, y), random.nextDouble() * 2 + 1, paint);
    }
  }

  @override
  bool shouldRepaint(covariant EmbersPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class SnowPainter extends CustomPainter {
  // Blue
  final Color color;
  final double progress;
  SnowPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(456);
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 40; i++) {
      final x =
          (random.nextDouble() * size.width + math.sin(progress * 5 + i) * 20) %
          size.width;
      // Float DOWN
      final startY = -20.0;
      final speed = 50 + random.nextDouble() * 100;
      final y = (startY + (progress * speed + i * 30)) % size.height;

      canvas.drawCircle(Offset(x, y), random.nextDouble() * 2 + 1, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SnowPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class MatrixPainter extends CustomPainter {
  // Green
  final Color color;
  final double progress;
  MatrixPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(789);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < 15; i++) {
      final x = random.nextDouble() * size.width;
      final speed = 200.0;
      final y = (-50 + (progress * speed + i * 100)) % (size.height + 50);

      final char = random.nextBool() ? "1" : "0";
      textPainter.text = TextSpan(
        text: char,
        style: TextStyle(
          color: color.withOpacity(0.4),
          fontSize: 14,
          fontFamily: 'Courier',
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x, y));
    }
  }

  @override
  bool shouldRepaint(covariant MatrixPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class PetalsPainter extends CustomPainter {
  // Pink
  final Color color;
  final double progress;
  PetalsPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(321);
    final paint = Paint()
      ..color = color.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 10; i++) {
      final x =
          (random.nextDouble() * size.width + math.sin(progress * 2 + i) * 50) %
          size.width;
      final startY = -50.0;
      final y = (startY + (progress * 100 + i * 80)) % size.height;

      // Draw oval petal
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * math.pi + i);
      canvas.drawOval(const Rect.fromLTWH(0, 0, 8, 12), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant PetalsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class NebulaPainter extends CustomPainter {
  // Purple
  final Color color;
  final double progress;
  NebulaPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader =
          RadialGradient(
            colors: [color.withOpacity(0.3), Colors.transparent],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width / 2, size.height),
              radius: size.width,
            ),
          );

    // Pulsing bottom fog
    final pulse = 1.0 + math.sin(progress * math.pi * 2) * 0.1;
    canvas.save();
    canvas.translate(size.width / 2, size.height);
    canvas.scale(pulse, pulse);
    canvas.drawCircle(Offset.zero, size.width * 0.8, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant NebulaPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// --- CATEGORY PAINTERS (Reused + Enhanced) ---

class GamingGlitchPainter extends CustomPainter {
  final Color color;
  final double progress;
  GamingGlitchPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random((progress * 20).floor()); // Twitch every frame

    // Hexagon Grid Overlay
    // (Simplified honeycomb effect)
    final hexPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 50) {
      for (double x = 0; x < size.width; x += 50) {
        if ((x / 50 + y / 50).floor() % 2 == 0) continue; // Checkerboardish
        canvas.drawCircle(Offset(x, y), 10, hexPaint);
      }
    }

    // Scanline
    final scanY = (progress * size.height * 2) % size.height;
    canvas.drawRect(
      Rect.fromLTWH(0, scanY, size.width, 2),
      Paint()..color = color.withOpacity(0.8),
    );

    // Glitch Blocks
    if (random.nextDouble() > 0.7) {
      final r = Rect.fromLTWH(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
        100,
        10,
      );
      canvas.drawRect(r, Paint()..color = color.withOpacity(0.7));
    }
  }

  @override
  bool shouldRepaint(covariant GamingGlitchPainter oldDelegate) => true;
}

class MusicWavePainter extends CustomPainter {
  final Color color;
  final double progress;
  MusicWavePainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.8)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final path = Path();

    // Mirrored wave
    for (double x = 0; x <= size.width; x += 10) {
      final y =
          size.height / 2 +
          math.sin(x / 30 + progress * 10) * 50 * math.sin(progress * 5);
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);

    // Beat circles
    final beat = (math.sin(progress * 20) + 1) / 2;
    if (beat > 0.8) {
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        beat * 100,
        Paint()
          ..color = color.withOpacity(0.2)
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant MusicWavePainter oldDelegate) => true;
}

class RomanticHeartPainter extends CustomPainter {
  final Color color;
  final double progress;
  RomanticHeartPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(12345);
    final paint = Paint()..color = color.withOpacity(0.5);
    for (int i = 0; i < 8; i++) {
      final x = random.nextDouble() * size.width;
      final y =
          (size.height + 50) -
          ((progress * size.height * 0.5 + i * 100) % (size.height + 100));
      canvas.drawCircle(Offset(x, y), 5 + random.nextDouble() * 5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant RomanticHeartPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class PKBattlePainter extends CustomPainter {
  final Color color;
  final double progress;
  PKBattlePainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if ((progress * 15).floor() % 5 != 0) return; // Flash
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(size.width / 2, 0);
    double cx = size.width / 2;
    double cy = 0;
    final r = math.Random();
    while (cy < size.height) {
      cy += 20 + r.nextDouble() * 20;
      cx += (r.nextDouble() - 0.5) * 50;
      path.lineTo(cx, cy);
    }
    canvas.drawPath(path, paint);
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(0.5)
        ..strokeWidth = 10
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant PKBattlePainter oldDelegate) => true;
}

class ChatAmbientPainter extends CustomPainter {
  final Color color;
  final double progress;
  ChatAmbientPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withOpacity(0.2);
    final x = size.width / 2 + math.sin(progress * math.pi) * 100;
    canvas.drawCircle(Offset(x, size.height / 2), 150, paint);
  }

  @override
  bool shouldRepaint(covariant ChatAmbientPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
