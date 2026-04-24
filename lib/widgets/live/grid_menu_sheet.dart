
import 'dart:ui';
import 'package:flutter/material.dart';

class GridMenuSheet extends StatelessWidget {
  final VoidCallback onJoinPressed;
  final VoidCallback onMessagesPressed;
  final VoidCallback onSharePressed;
  final VoidCallback onTopUpPressed;
  final VoidCallback? onSettingsPressed;

  const GridMenuSheet({
    super.key,
    required this.onJoinPressed,
    required this.onMessagesPressed,
    required this.onSharePressed,
    required this.onTopUpPressed,
    this.onSettingsPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200, // Reduced from 320 to 200 (Compact)
      decoration: const BoxDecoration(
        color: Colors.transparent, 
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 1. Ultra-Premium Glass Background
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0F1020).withOpacity(0.95),
                    const Color(0xFF050510).withOpacity(0.98),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.1), width: 0.5),
                ),
              ),
            ),
          ),

          // 2. Content
          Column(
            children: [
              // Handle Bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 12), // Reduced spacing
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title removed to save space or kept very small? Keeping it small.
              // Actually for ultra compact, removing title might be better or keeping it very minimal.
              // Let's keep it but with less padding.
              const Padding(
                padding: EdgeInsets.only(bottom: 16), // Reduced from 24
                child: Text(
                  'More Actions',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13, // Slightly smaller
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // Buttons Grid
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16), // Tighter horizontal
                  child: GridView.count(
                    crossAxisCount: 4, 
                    crossAxisSpacing: 12, // Tighter spacing
                    mainAxisSpacing: 0,
                    childAspectRatio: 0.85, // Slightly taller for labels
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    children: [
                      // 1. JOIN
                      _buildGridButton(
                        label: 'Join',
                        icon: Icons.record_voice_over_rounded, // Better "Join Seat" icon
                        gradientColors: [const Color(0xFF9C27B0), const Color(0xFF673AB7)],
                        onTap: onJoinPressed,
                      ),

                      // 2. MESSAGES
                      _buildGridButton(
                        label: 'Messages',
                        icon: Icons.forum_rounded, // Premium "Chat" icon
                        gradientColors: [const Color(0xFFFF1493), const Color(0xFFFF69B4)],
                        onTap: onMessagesPressed,
                        badgeCount: 3,
                      ),

                      // 3. SHARE
                      _buildGridButton(
                        label: 'Share',
                        icon: Icons.ios_share_rounded, // Premium "Upward" share
                        gradientColors: [const Color(0xFFFF5722), const Color(0xFFFF8C00)],
                        onTap: onSharePressed,
                      ),

                      // 4. TOP UP
                      _buildGridButton(
                        label: 'Top Up',
                        icon: Icons.diamond_rounded, // Filled "Premium" diamond
                        gradientColors: [const Color(0xFFFFD700), const Color(0xFFFFA000)],
                        onTap: onTopUpPressed,
                      ),

                      if (onSettingsPressed != null)
                        _buildGridButton(
                          label: 'Settings',
                          icon: Icons.settings_rounded,
                          gradientColors: [const Color(0xFF607D8B), const Color(0xFF455A64)],
                          onTap: onSettingsPressed!,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildGridButton({
    required String label,
    required IconData icon,
    required List<Color> gradientColors,
    required VoidCallback onTap,
    int? badgeCount,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 3D Premium Button
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. Shadow Layer (Glow)
                Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: gradientColors.last.withOpacity(0.4),
                        blurRadius: 16,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                ),

                // 2. Main 3D Sphere
                Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradientColors,
                      stops: const [0.1, 0.9],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.15),
                      width: 1,
                    ),
                    boxShadow: [
                      // Inner Light (Top Left)
                      BoxShadow(
                        color: Colors.white.withOpacity(0.3),
                        offset: const Offset(-2, -2),
                        blurRadius: 4,
                        blurStyle: BlurStyle.inner, // Inset effect workaround
                      ),
                      // Inner Shadow (Bottom Right)
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        offset: const Offset(2, 2),
                        blurRadius: 4,
                       //  blurStyle: BlurStyle.inner, // Inset effect workaround not standard in Flutter BoxShadow directly without package or custom painter
                       // Standard BoxShadow is outer. 
                       // For simple Inner Shadow effect we use separate containers or custom painter.
                       // Let's stick to gradient for depth for now to keep it simple but vibrant.
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.15),
                          Colors.transparent,
                          Colors.black.withOpacity(0.1),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Stack(
                         alignment: Alignment.center,
                         children: [
                            // Icon Shadow for 3D feel
                            Transform.translate(
                              offset: const Offset(1, 2),
                              child: Icon(
                                icon,
                                color: Colors.black.withOpacity(0.3),
                                size: 30, 
                              ),
                            ),
                            // Main Icon
                            Icon(
                              icon,
                              color: Colors.white,
                              size: 30, // Large Icon
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                         ],
                      ),
                    ),
                  ),
                ),
                
                 // 3. Specular Highlight (Gloss)
                Positioned(
                  top: 10,
                  right: 15,
                  child: Container(
                    width: 12,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: const BorderRadius.all(Radius.elliptical(12, 6)),
                    ),
                    transform: Matrix4.rotationZ(-0.5),
                  ),
                ),


                // Badge
                if (badgeCount != null)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3D00), // Vibrant Red Orange
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                       constraints: const BoxConstraints(
                        minWidth: 22,
                        minHeight: 22,
                      ),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 6),

          // Label
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.95),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              shadows: [
                 Shadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
