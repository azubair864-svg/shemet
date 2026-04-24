import 'package:flutter/material.dart';
import 'dart:ui';
import '../../core/constants/app_colors.dart';

class PartyEndScreen extends StatelessWidget {
  final Map<String, dynamic> stats;

  const PartyEndScreen({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    // Aggregating Stats
    final String duration = stats['duration'] ?? '00:00:00';
    final int audiences = stats['totalVisitors'] ?? 0;
    final int giftEarnings = stats['giftEarnings'] ?? 0;
    final int gameEarnings = stats['gameEarnings'] ?? 0;
    final int totalEarnings = giftEarnings + gameEarnings;

    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;

    return Scaffold(
      backgroundColor: Colors.black, // Dark Base
      body: Stack(
        children: [
          // 1. Premium Black Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF000000), // Pure Black
                  Color(0xFF141414), // Soft Black
                  Color(0xFF0F0F1A), // Very Deep Void
                ],
              ),
            ),
          ),

          // 2. Ambient Glow (Subtle Gold/Purple Haze)
          Positioned(
            top: -150,
            right: -100,
            child: _buildGlowOrb(300, const Color(0xFFFFD700).withOpacity(0.15)), // Gold Glow
          ),
           Positioned(
            bottom: -100,
            left: -50,
            child: _buildGlowOrb(250, AppColors.primary.withOpacity(0.1)), // Pink Glow
          ),

          // 3. Main Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  SizedBox(height: screenHeight * 0.04),

                  // Header: Minimalist & Spaced
                  const Text(
                    'SESSION COMPLETED',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6, // WIDE spacing for premium look
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Thin Gold Accent Line
                  Container(
                    width: 40,
                    height: 1.5,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFFD700), Colors.transparent]),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.06),

                  // Hero Section: Glowing Earnings Ring
                  _buildHeroEarnings(totalEarnings),

                  SizedBox(height: screenHeight * 0.08),

                  // Stats Grid (Glassmorphism)
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.5,
                      children: [
                        _buildGlassStatCard(
                          'DURATION',
                          duration,
                          Icons.timer_outlined,
                          Colors.cyanAccent,
                        ),
                        _buildGlassStatCard(
                          'AUDIENCE',
                          audiences.toString(),
                          Icons.people_outline,
                          Colors.greenAccent,
                        ),
                        _buildGlassStatCard(
                          'GIFT VALUE',
                          '$giftEarnings',
                          Icons.card_giftcard,
                          const Color(0xFFFF4081),
                        ),
                        _buildGlassStatCard(
                          'GAME WON',
                          '$gameEarnings',
                          Icons.videogame_asset_outlined,
                          const Color(0xFFFFD700),
                        ),
                      ],
                    ),
                  ),

                  // Bottom Action
                  Padding(
                    padding: const EdgeInsets.only(bottom: 40.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent, // Gradient bg
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(27),
                            side: BorderSide(color: Colors.white.withOpacity(0.2), width: 1),
                          ),
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1A1A1A), Color(0xFF2C2C2C)], // Matte Black Gradient
                            ),
                            borderRadius: BorderRadius.circular(27),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            child: const Text(
                              'RETURN TO HOME',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                color: Color(0xFFFFD700), // Gold Text
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlowOrb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.4),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.6),
            blurRadius: 100, // Heavy blur for ambient light
            spreadRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildHeroEarnings(int total) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer Glow Ring
        Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.1), width: 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withOpacity(0.05),
                blurRadius: 40,
                spreadRadius: 0,
              ),
            ],
          ),
        ),
        
        // Inner Circle
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A1A1A), Colors.black],
            ),
            boxShadow: [
               BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 10,
                offset: const Offset(5, 5),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(-5, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.stars_rounded, color: Color(0xFFFFD700), size: 36), // Gold Star
              const SizedBox(height: 8),
              Text(
                '$total',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  fontFamily: "Courier", // Monospaced for numbers looks techy
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'TOTAL EARNINGS',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGlassStatCard(String label, String value, IconData icon, Color accentColor) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Reduced padding
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min, // Use min size
                children: [
                  Container(
                    padding: const EdgeInsets.all(6), // Reduced padding
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: accentColor, size: 14), // Smaller icon
                  ),
                  const Spacer(),
                  FittedBox( // Ensure text fits
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18, // Slightly smaller font
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 9, // Smaller font
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
