import 'dart:ui';
import 'package:flutter/material.dart';

class PartyRoomBottomBar extends StatelessWidget {
  final bool isHost;
  final bool isSeated;
  final VoidCallback onChatPressed;
  final VoidCallback onGamePressed;
  final VoidCallback onGiftPressed;
  final VoidCallback onSettingsPressed;
  final VoidCallback onClosePressed;
  final VoidCallback? onJoinSeatPressed; // Kept for audience
  final VoidCallback? onSharePressed;
  final VoidCallback? onTopUpPressed;
  final bool isMicOn;
  final bool isVideoOn;
  final VoidCallback? onMicPressed;
  final VoidCallback? onVideoPressed;
  final VoidCallback? onPkPressed;

  const PartyRoomBottomBar({
    super.key,
    required this.isHost,
    required this.isSeated,
    required this.onChatPressed,
    required this.onGamePressed,
    required this.onGiftPressed,
    required this.onSettingsPressed,
    required this.onClosePressed,
    this.onJoinSeatPressed,
    this.onSharePressed,
    this.onTopUpPressed,
    this.isMicOn = false,
    this.isVideoOn = false,
    this.onMicPressed,
    this.onVideoPressed,
    this.onPkPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, // Push to corners
          children: [
            // 1. LEFT ISLE: Circular Chat Button
            _buildChatButton(),

            // 2. RIGHT ISLE: Action Dock (Game | Gift | Grid | Close or Join)
            _buildActionDock(),
          ],
        ),
      ),
    );
  }

  Widget _buildChatButton() {
    return GestureDetector(
      onTap: onChatPressed,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.chat_bubble_outline,
              color: Colors.white.withOpacity(0.9),
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionDock() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 4), // Compact padding
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. GAME ICON
              _buildIconButton(
                icon: Icons.sports_esports,
                onTap: onGamePressed,
                color: const Color(0xFFFFB300), // Amber color for joystick
              ),

              // 2. GIFT ICON (Gold/Premium) - ONLY for audience
              if (!isHost)
                _buildIconButton(
                  icon: Icons.card_giftcard,
                  onTap: onGiftPressed,
                  isPremium: true, // Special styling
                ),

              // 3. GRID (More/Settings) Menu - THIS WILL NOW OPEN THE 4-BUTTON MENU
              _buildIconButton(icon: Icons.widgets, onTap: onSettingsPressed),

              // 4. ACTION or CLOSE
              if (!isSeated && !isHost && onJoinSeatPressed != null)
                _buildIconButton(
                  icon: Icons.event_seat,
                  onTap: onJoinSeatPressed!,
                  color: Colors.purpleAccent,
                )
              else
                _buildIconButton(icon: Icons.close, onTap: onClosePressed),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isPremium = false,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, // Touch target
        height: 44,
        color: Colors.transparent,
        alignment: Alignment.center,
        child: isPremium
            ? ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    Color(0xFFFFD700),
                    Color(0xFFFF8C00),
                  ], // Gold Gradient
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: Icon(icon, color: Colors.white, size: 26),
              )
            : Icon(
                icon,
                color: color ?? Colors.white.withOpacity(0.9),
                size: 26, // Slightly larger standard icons
              ),
      ),
    );
  }
}
