
import 'dart:ui';
import 'package:flutter/material.dart';

class GameSelectionWidget extends StatefulWidget {
  final Function(String) onGameSelected;

  const GameSelectionWidget({super.key, required this.onGameSelected});

  @override
  State<GameSelectionWidget> createState() => _GameSelectionWidgetState();
}

class _GameSelectionWidgetState extends State<GameSelectionWidget> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 50 * _slideAnimation.value), // Subtle slide up
          child: Opacity(
            opacity: (1.0 - _slideAnimation.value).clamp(0.0, 1.0),
            child: Wrap( // Wrap to allow bottom sheet to size to content
              children: [
                Container(
                 // Compact Height - Only takes necessary space
                  margin: const EdgeInsets.only(left: 12, right: 12, bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85), // Dark glass
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min, // Wrap content
                          children: [
                            // 1. Cute Header with close button
                            Padding(
                              padding: const EdgeInsets.only(left: 12, right: 8, bottom: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '🕹️ Play Games',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.95),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.pinkAccent.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.pinkAccent.withOpacity(0.5)),
                                        ),
                                        child: const Text(
                                          'NEW',
                                          style: TextStyle(
                                            color: Colors.pinkAccent,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  GestureDetector(
                                    onTap: () => Navigator.pop(context),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, color: Colors.white70, size: 16),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // 2. Horizontal Scroll List
                            SizedBox(
                              height: 100, // Compact height for icons + text
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                children: [
                                  _buildCuteGameIcon(
                                    context,
                                    id: 'aviator',
                                    name: 'Aviator',
                                    imagePath: 'assets/images/games/aviator.png',
                                    color: const Color(0xFFFF5252),
                                  ),
                                  _buildCuteGameIcon(
                                    context,
                                    id: 'racing',
                                    name: 'Racing',
                                    imagePath: 'assets/images/games/race_game.png',
                                    color: const Color(0xFFFFA726),
                                  ),
                                  _buildCuteGameIcon(
                                    context,
                                    id: 'dice',
                                    name: 'Dice',
                                    imagePath: 'assets/images/games/royal_dice.png',
                                    color: const Color(0xFFE040FB),
                                  ),
                                  // Can add more games here seamlessly
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCuteGameIcon(
    BuildContext context, {
    required String id,
    required String name,
    required String imagePath,
    required Color color,
    bool isComingSoon = false,
  }) {
    return GestureDetector(
      onTap: isComingSoon
          ? null
          : () {
              Navigator.pop(context); // Close safely
              widget.onGameSelected(id);
            },
      child: Container(
        width: 80, // Fixed width for alignment
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            // Icon Circle
            Stack(
              alignment: Alignment.center,
              children: [
                // Outer Glow/Border
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withOpacity(0.8),
                        color.withOpacity(0.3),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.25),
                        blurRadius: 8,
                        spreadRadius: 1,
                        offset: const Offset(0, 3)
                      ),
                    ],
                  ),
                ),
                
                // Image content
                Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    color: Colors.black, // Background for transparent PNGs
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: Opacity(
                      opacity: isComingSoon ? 0.5 : 1.0,
                      child: Image.asset(
                        imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.games,
                          color: color,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ),

                // Coming Soon Lock Overlay
                if (isComingSoon)
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.lock, color: Colors.white, size: 24),
                    ),
                  ),
                
                // Ripple Effect/Interaction could go here
              ],
            ),
            
            const SizedBox(height: 8),

            // Game Name
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isComingSoon ? Colors.white54 : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 2)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
