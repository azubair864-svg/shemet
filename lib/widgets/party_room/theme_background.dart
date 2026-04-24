import 'package:flutter/material.dart';
import 'dart:math' as math;

class ThemeBackground extends StatefulWidget {
  final String themeName;
  final bool showParticles;
  final bool showCastle;

  const ThemeBackground({
    super.key,
    required this.themeName,
    this.showParticles = true,
    this.showCastle = false,
  });

  @override
  State<ThemeBackground> createState() => _ThemeBackgroundState();
}

class _ThemeBackgroundState extends State<ThemeBackground> with TickerProviderStateMixin {
  late AnimationController _auroraController;
  late AnimationController _pulseController;
  
  // Mesh Gradient Points
  late List<Offset> _meshPoints;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _auroraController = AnimationController(
        vsync: this, duration: const Duration(seconds: 20))..repeat();
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
    
    _generateMeshPoints();
  }

  void _generateMeshPoints() {
    _meshPoints = List.generate(6, (index) => Offset(
      _random.nextDouble(), _random.nextDouble()
    ));
  }

  @override
  void dispose() {
    _auroraController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // Define Premium Gradient Themes
  List<Color> _getThemeColors(String theme) {
    switch (theme.toLowerCase()) {
      case 'gold':
        return [
          const Color(0xFF1A0F00), // Deep Dark Brown
          const Color(0xFF422006), // Rich Brown
          const Color(0xFF8F6B29), // Muted Gold
          const Color(0xFFD4AF37), // Classic Gold
          const Color(0xFFFFD700), // Bright Gold
        ];
      case 'purple': // "Midnight Luxury"
        return [
          const Color(0xFF0D0221), // Void Black
          const Color(0xFF240046), // Deep Indigo
          const Color(0xFF3C096C), // Royal Purple
          const Color(0xFF7B2CBF), // Vivid Violet
          const Color(0xFF9D4EDD), // Bright Orchid
        ];
      case 'blue': // "Ocean Depth"
        return [
          const Color(0xFF001219), // Deep Teal Black
          const Color(0xFF001D3D), // Oxford Blue
          const Color(0xFF003566), // Royal Blue
          const Color(0xFF006494), // Bright Azure
          const Color(0xFF4895EF), // Sky Blue
        ];
      case 'romantic': // "Love Haze"
        return [
          const Color(0xFF2B0515), // Deep Cherry
          const Color(0xFF590D22), // Burgundy
          const Color(0xFF800F2F), // Crimson
          const Color(0xFFA4133C), // Ruby
          const Color(0xFFFF4D6D), // Hot Pink
        ];
      case 'cyber': // "Neon City"
        return [
          const Color(0xFF050505), // Pure Black
          const Color(0xFF0B132B), // Navy
          const Color(0xFF1C2541), // Gunmetal
          const Color(0xFF3A506B), // Steel Blue
          const Color(0xFF00F5D4), // Cyan Neon
        ];
      default:
        return [
           const Color(0xFF0D0221), const Color(0xFF240046), const Color(0xFF7B2CBF)
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _getThemeColors(widget.themeName);

    return Stack(
      children: [
        // 1. Base Layer: Animated Mesh Gradient
        AnimatedBuilder(
          animation: _auroraController,
          builder: (context, child) {
            return CustomPaint(
              painter: MeshGradientPainter(
                colors: colors,
                progress: _auroraController.value,
                meshPoints: _meshPoints,
              ),
              size: Size.infinite,
            );
          },
        ),

        // 2. Texture Overlay (Noise)
        Opacity(
          opacity: 0.05,
          child: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/noise_texture.png'), // Placeholder, will fail gracefully if missing
                fit: BoxFit.cover,
                repeat: ImageRepeat.repeat,
              ),
            ),
          ),
        ),

        // 3. Floating Orb Effects (Specific per theme)
        if (widget.showParticles) ...[
           // Bottom-Left Glow
           Positioned(
             bottom: -100, left: -50,
             child: _buildGlowOrb(colors.last.withOpacity(0.3), 300),
           ),
           // Top-Right Glow
           Positioned(
             top: -100, right: -50,
             child: _buildGlowOrb(colors[2].withOpacity(0.3), 250),
           ),
        ],

        // 4. Particle System (Subtle dust/stars)
        if (widget.showParticles)
          Positioned.fill(
            child: PremiumParticleSystem(
              color: colors.last,
              controller: _pulseController,
            ),
          ),
          
        // 5. Castle / Thematic Image (Optional)
        if (widget.showCastle)
           Positioned(
             bottom: 0,
             left: 0, 
             right: 0,
             child: Opacity(
               opacity: 0.8,
               child: Image.asset(
                 'assets/images/room_themes/${widget.themeName.toLowerCase()}_bg.png',
                 fit: BoxFit.contain,
                 alignment: Alignment.bottomCenter,
                 errorBuilder: (c, o, s) => const SizedBox.shrink(), // Hides if missing
               ),
             ),
           ),
      ],
    );
  }

  Widget _buildGlowOrb(Color color, double size) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: size * (0.9 + _pulseController.value * 0.1),
          height: size * (0.9 + _pulseController.value * 0.1),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                 color,
                 color.withOpacity(0.0),
              ],
              stops: const [0.2, 1.0],
            ),
          ),
        );
      }
    );
  }
}

// ---------------------------------------------------------------------------
// PAINTERS & SUB-WIDGETS
// ---------------------------------------------------------------------------

class MeshGradientPainter extends CustomPainter {
  final List<Color> colors;
  final double progress;
  final List<Offset> meshPoints;

  MeshGradientPainter({
    required this.colors, 
    required this.progress,
    required this.meshPoints
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Fill background with darkest color
    canvas.drawColor(colors.first, BlendMode.srcOver);

    // Draw Aurora Curves
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);

    for (int i = 0; i < 3; i++) {
       // Use colors from the palette sequentially
       paint.color = colors[(i + 1) % colors.length].withOpacity(0.4);
       
       final path = Path();
       
       // Calculate dynamic wave based on progress
       final shift = progress * 2 * math.pi;
       final yBase = size.height * (0.3 + i * 0.2);
       
       path.moveTo(0, yBase + math.sin(shift + i) * 50);
       
       path.quadraticBezierTo(
         size.width * 0.5, 
         yBase + math.cos(shift + i * 2) * 100 - 100, 
         size.width, 
         yBase + math.sin(shift + i * 3) * 50
       );
       
       path.lineTo(size.width, size.height);
       path.lineTo(0, size.height);
       path.close();
       
       canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant MeshGradientPainter oldDelegate) => true;
}

class PremiumParticleSystem extends StatelessWidget {
  final Color color;
  final AnimationController controller;

  const PremiumParticleSystem({
    super.key,
    required this.color,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return CustomPaint(
          painter: ParticlePainter(
            color: color, 
            progress: controller.value
          ),
        );
      }
    );
  }
}

class ParticlePainter extends CustomPainter {
  final Color color;
  final double progress;
  final math.Random _random = math.Random(42); // Seeded for consistency

  ParticlePainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 40; i++) {
      // Create a deterministic but chaotic movement
      final xSeed = _random.nextDouble();
      final ySeed = _random.nextDouble();
      final speed = 0.5 + _random.nextDouble();
      
      double y = (ySeed + progress * speed) % 1.0;
      double x = xSeed + math.sin(progress * 2 * math.pi + i) * 0.05;

      final radius = _random.nextDouble() * 2 + 1;
      
      // Opacity fade in/out based on Y position (fade at top/bottom)
      double alpha = 1.0;
      if (y < 0.1) alpha = y * 10;
      if (y > 0.9) alpha = (1.0 - y) * 10;

      paint.color = color.withOpacity(0.3 * alpha);
      canvas.drawCircle(Offset(x * size.width, y * size.height), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ParticlePainter oldDelegate) => true;
}
