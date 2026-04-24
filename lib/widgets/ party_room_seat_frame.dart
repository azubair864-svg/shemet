import 'package:flutter/material.dart';

class PartyRoomSeatFrame extends StatelessWidget {
  final Widget child;
  final String frameType; // 'none', 'host', 'vip', 'top_contributor'
  final bool showGlow;

  const PartyRoomSeatFrame({
    super.key,
    required this.child,
    this.frameType = 'none',
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    if (frameType == 'none') {
      return child;
    }

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Outer glow
        if (showGlow)
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _getFrameColor().withOpacity(0.4),
                  blurRadius: 16,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),

        // Decorative outer ring
        Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              width: 2.5,
              color: _getFrameColor(),
            ),
          ),
        ),

        // Inner decorative ring
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              width: 1,
              color: Colors.white.withOpacity(0.3),
            ),
          ),
        ),

        // Decorative dots (for special frames)
        if (frameType == 'host' || frameType == 'top_contributor')
          ..._buildDecorativeDots(),

        // Child content
        child,

        // Frame ornaments (corners/decorations)
        if (frameType == 'host') ..._buildHostOrnaments(),
        if (frameType == 'vip') ..._buildVipOrnaments(),
      ],
    );
  }

  Color _getFrameColor() {
    switch (frameType) {
      case 'host':
        return const Color(0xFFFFD700); // Gold
      case 'vip':
        return const Color(0xFF9B6FD7); // Purple
      case 'top_contributor':
        return const Color(0xFFFF69B4); // Pink
      default:
        return Colors.white;
    }
  }

  List<Widget> _buildDecorativeDots() {
    return [
      Positioned(
        top: 5,
        child: _buildDot(),
      ),
      Positioned(
        bottom: 5,
        child: _buildDot(),
      ),
      Positioned(
        left: 5,
        child: _buildDot(),
      ),
      Positioned(
        right: 5,
        child: _buildDot(),
      ),
    ];
  }

  Widget _buildDot() {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _getFrameColor(),
        boxShadow: [
          BoxShadow(
            color: _getFrameColor().withOpacity(0.6),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildHostOrnaments() {
    return [
      // Top ornament
      Positioned(
        top: -8,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
            ),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withOpacity(0.6),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.star,
            color: Colors.white,
            size: 12,
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildVipOrnaments() {
    return [
      // Side ornaments
      Positioned(
        left: -6,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF9B6FD7), Color(0xFFFF69B4)],
            ),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9B6FD7).withOpacity(0.6),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ),
      Positioned(
        right: -6,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF9B6FD7), Color(0xFFFF69B4)],
            ),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9B6FD7).withOpacity(0.6),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ),
    ];
  }
}