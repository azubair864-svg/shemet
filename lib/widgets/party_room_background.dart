import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'party_room/category_background.dart'; // Unified Background

class PartyRoomBackground extends StatefulWidget {
  final String theme;
  final bool showParticles;
  final bool showCastle;
  final String? backgroundImage; // Added for sync

  const PartyRoomBackground({
    super.key,
    this.theme = 'purple',
    this.showParticles = true,
    this.showCastle = true,
    this.backgroundImage,
    this.category,
  });

  final String? category;

  @override
  State<PartyRoomBackground> createState() => _PartyRoomBackgroundState();
}

class _PartyRoomBackgroundState extends State<PartyRoomBackground>
    with TickerProviderStateMixin {
  late AnimationController _gradientController;
  late AnimationController _nodeController;
  late AnimationController _particleController;

  @override
  void initState() {
    super.initState();

    _gradientController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();

    _nodeController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _particleController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _gradientController.dispose();
    _nodeController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  bool _hasCustomEffects() {
    return ['gaming', 'romantic', 'party', 'chat'].contains(widget.theme.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base gradient
        Container(
          decoration: BoxDecoration(gradient: _getThemeGradient()),
        ),

        // Animated gradient overlay
        AnimatedBuilder(
          animation: _gradientController,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(
                    math.cos(_gradientController.value * math.pi * 2),
                    math.sin(_gradientController.value * math.pi * 2),
                  ),
                  end: Alignment(
                    -math.cos(_gradientController.value * math.pi * 2),
                    -math.sin(_gradientController.value * math.pi * 2),
                  ),
                  colors: [
                    Colors.white.withOpacity(0.05),
                    Colors.transparent,
                    Colors.black.withOpacity(0.1),
                  ],
                ),
              ),
            );
          },
        ),

        // Diamond lattice pattern (Modern style)
        CustomPaint(
          size: Size.infinite,
          painter: EnhancedDiamondLatticePainter(
            color: Colors.white.withOpacity(0.15),
            lineWidth: 1.5,
          ),
        ),

        // Glowing nodes
        AnimatedBuilder(
          animation: _nodeController,
          builder: (context, child) {
            return CustomPaint(
              size: Size.infinite,
              painter: GlowingNodesPainter(
                progress: _nodeController.value,
                color: _getThemeAccentColor(),
              ),
            );
          },
        ),

        // Theme-specific effects
        _buildThemeEffects(),

        // Enhanced floating particles
        if (widget.showParticles && !_hasCustomEffects())
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, child) {
              return CustomPaint(
                size: Size.infinite,
                painter: EnhancedParticlesPainter(
                  progress: _particleController.value,
                  particleCount: 40,
                ),
              );
            },
          ),

        // Castle silhouette (if enabled)
        if (widget.showCastle)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildEnhancedCastle(),
          ),

        // Vignette effect
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.0,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.3),
              ],
              stops: const [0.5, 1.0],
            ),
          ),
        ),
      ],
    );
  }



// ... imports ...

  Widget _buildThemeEffects() {
     // UNIFIED PREMIUM ARCHITECTURE
     // If a category is selected (Gaming, Music, etc.), use the CategoryBackground
     // The 'theme' (themeColor) will be passed to tint it.
     
     if (widget.category != null && widget.category!.isNotEmpty && widget.category != 'None') {
        return Positioned.fill(
          child: CategoryBackground(
            category: widget.category!,
            themeColor: _getThemeAccentColor(),
            backgroundImage: widget.backgroundImage, // Pass synced image
          ),
        );
     }
     
     // Fallback for Rooms with no category (should be rare) or special legacy themes
     return _buildLegacyThemeEffects();
  }

  Widget _buildLegacyThemeEffects() {
    switch (widget.theme.toLowerCase()) {
      // ... (Keep existing simple color gradients if needed, or redirect them too)
      default: return const SizedBox.shrink(); 
    }
  }

  Widget _buildEnhancedCastle() {
    return AnimatedBuilder(
      animation: _gradientController,
      builder: (context, child) {
        final glowIntensity = (math.sin(_gradientController.value * math.pi * 2) + 1) / 2;
        return Container(
          height: 200,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                _getThemeAccentColor().withOpacity(0.3),
                _getThemeAccentColor().withOpacity(0.1),
                Colors.transparent,
              ],
            ),
          ),
          child: CustomPaint(
            painter: EnhancedCastlePainter(
              glowIntensity: glowIntensity,
              color: _getThemeAccentColor(),
            ),
            size: const Size(double.infinity, 200),
          ),
        );
      },
    );
  }


  LinearGradient _getThemeGradient() {
    switch (widget.theme.toLowerCase()) {
      case 'pink':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF69B4), Color(0xFFE91E63), Color(0xFF880E4F)],
        );
      case 'blue':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2196F3), Color(0xFF1565C0), Color(0xFF0D47A1)],
        );
      case 'orange':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF9800), Color(0xFFE65100), Color(0xFFBF360C)],
        );
      case 'green':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4CAF50), Color(0xFF2E7D32), Color(0xFF1B5E20)],
        );
      case 'gaming':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
        );
      case 'romantic':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF6B9D), Color(0xFFC06C84), Color(0xFF6C5B7B)],
        );
      case 'party':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF00FF), Color(0xFF9D00FF), Color(0xFF4B0082)],
        );
      case 'chat':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9C27B0), Color(0xFF7B1FA2), Color(0xFF4A148C)],
        );
      default: // purple
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9B6FD7), Color(0xFF6A1B9A), Color(0xFF4A148C)],
        );
    }
  }

  Color _getThemeAccentColor() {
    switch (widget.theme.toLowerCase()) {
      case 'pink': return const Color(0xFFFF69B4);
      case 'blue': return const Color(0xFF2196F3);
      case 'orange': return const Color(0xFFFF9800);
      case 'green': return const Color(0xFF4CAF50);
      case 'gaming': return const Color(0xFF00FFFF);
      case 'romantic': return const Color(0xFFFF6B9D);
      case 'party': return const Color(0xFFFF00FF);
      case 'chat': return const Color(0xFF9C27B0);
      default: return const Color(0xFF9B6FD7);
    }
  }
}

// Enhanced Diamond Lattice Painter (Modern style)
class EnhancedDiamondLatticePainter extends CustomPainter {
  final Color color;
  final double lineWidth;

  EnhancedDiamondLatticePainter({required this.color, required this.lineWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke;

    const double spacing = 80;
    const double diamondSize = 60;

    // Draw diamond grid
    for (double y = -diamondSize; y < size.height + diamondSize; y += spacing) {
      for (double x = -diamondSize; x < size.width + diamondSize; x += spacing) {
        final path = Path();
        path.moveTo(x, y - diamondSize / 2);
        path.lineTo(x + diamondSize / 2, y);
        path.lineTo(x, y + diamondSize / 2);
        path.lineTo(x - diamondSize / 2, y);
        path.close();
        canvas.drawPath(path, paint);
      }
    }

    // Diagonal crosshatch
    final diagonalPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = lineWidth * 0.5
      ..style = PaintingStyle.stroke;

    for (double i = -size.width; i < size.width * 2; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), diagonalPaint);
      canvas.drawLine(Offset(size.width - i, 0), Offset(size.width - i - size.height, size.height), diagonalPaint);
    }
  }

  @override
  bool shouldRepaint(EnhancedDiamondLatticePainter oldDelegate) => false;
}

// Glowing Nodes Painter (Modern style)
class GlowingNodesPainter extends CustomPainter {
  final double progress;
  final Color color;

  GlowingNodesPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const double spacing = 80;
    final random = math.Random(42);

    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        final randomOffset = random.nextDouble();
        final glowIntensity = (math.sin((progress + randomOffset) * math.pi * 2) + 1) / 2;

        if (glowIntensity > 0.7) {
          final paint = Paint()
            ..shader = RadialGradient(
              colors: [
                color.withOpacity(glowIntensity * 0.6),
                color.withOpacity(glowIntensity * 0.3),
                Colors.transparent,
              ],
            ).createShader(Rect.fromCircle(center: Offset(x, y), radius: 20));

          canvas.drawCircle(Offset(x, y), 20, paint);

          final centerPaint = Paint()
            ..color = Colors.white.withOpacity(glowIntensity * 0.8)
            ..style = PaintingStyle.fill;

          canvas.drawCircle(Offset(x, y), 3, centerPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(GlowingNodesPainter oldDelegate) => true;
}

// Enhanced Particles Painter
class EnhancedParticlesPainter extends CustomPainter {
  final double progress;
  final int particleCount;

  EnhancedParticlesPainter({required this.progress, required this.particleCount});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(123);

    for (int i = 0; i < particleCount; i++) {
      final baseX = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final speed = 0.1 + random.nextDouble() * 0.2;
      final floatX = random.nextDouble() * 20 - 10;

      final x = baseX + math.sin(progress * math.pi * 2 + i) * floatX;
      final y = (baseY + progress * size.height * speed) % (size.height + 50) - 50;

      final opacity = (math.sin(progress * math.pi * 2 + i * 0.5) + 1) / 2;
      final particleSize = 2.0 + random.nextDouble() * 3;

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withOpacity(opacity * 0.8),
            Colors.white.withOpacity(opacity * 0.3),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(x, y), radius: particleSize * 2));

      canvas.drawCircle(Offset(x, y), particleSize * 2, paint);
    }
  }

  @override
  bool shouldRepaint(EnhancedParticlesPainter oldDelegate) => true;
}

// Enhanced Castle Painter
class EnhancedCastlePainter extends CustomPainter {
  final double glowIntensity;
  final Color color;

  EnhancedCastlePainter({required this.glowIntensity, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = color.withOpacity(glowIntensity * 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    final path = Path();
    final width = size.width;
    final height = size.height;

    // Center tower
    path.moveTo(width * 0.4, height);
    path.lineTo(width * 0.4, height * 0.3);
    path.lineTo(width * 0.35, height * 0.25);
    path.lineTo(width * 0.35, height * 0.2);
    path.lineTo(width * 0.45, height * 0.2);
    path.lineTo(width * 0.45, height * 0.25);
    path.lineTo(width * 0.6, height * 0.25);
    path.lineTo(width * 0.6, height * 0.3);
    path.lineTo(width * 0.6, height);
    path.close();

    // Left tower
    path.moveTo(width * 0.15, height);
    path.lineTo(width * 0.15, height * 0.5);
    path.lineTo(width * 0.1, height * 0.45);
    path.lineTo(width * 0.1, height * 0.4);
    path.lineTo(width * 0.2, height * 0.4);
    path.lineTo(width * 0.2, height * 0.45);
    path.lineTo(width * 0.25, height * 0.5);
    path.lineTo(width * 0.25, height);
    path.close();

    // Right tower
    path.moveTo(width * 0.75, height);
    path.lineTo(width * 0.75, height * 0.45);
    path.lineTo(width * 0.7, height * 0.4);
    path.lineTo(width * 0.7, height * 0.35);
    path.lineTo(width * 0.8, height * 0.35);
    path.lineTo(width * 0.8, height * 0.4);
    path.lineTo(width * 0.85, height * 0.45);
    path.lineTo(width * 0.85, height);
    path.close();

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);

    // Glowing windows
    final windowPaint = Paint()
      ..color = color.withOpacity(glowIntensity * 0.6)
      ..style = PaintingStyle.fill;

    canvas.drawRect(Rect.fromLTWH(width * 0.45, height * 0.5, 10, 15), windowPaint);
    canvas.drawRect(Rect.fromLTWH(width * 0.52, height * 0.5, 10, 15), windowPaint);
    canvas.drawRect(Rect.fromLTWH(width * 0.17, height * 0.6, 8, 12), windowPaint);
    canvas.drawRect(Rect.fromLTWH(width * 0.77, height * 0.55, 8, 12), windowPaint);
  }

  @override
  bool shouldRepaint(EnhancedCastlePainter oldDelegate) =>
      oldDelegate.glowIntensity != glowIntensity;
}