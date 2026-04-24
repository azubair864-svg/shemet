import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';
import 'dart:ui';
import '../models/gift_model.dart';

/// ⭐⭐⭐ PRODUCTION-READY GIFT ANIMATION OVERLAY ⭐⭐⭐
/// Full-screen gift animation effects for live streaming and chat
/// Features: Lottie animations, particle effects
class GiftAnimationOverlay extends StatefulWidget {
  final Widget child;

  const GiftAnimationOverlay({
    super.key,
    required this.child,
  });

  /// Show gift animation globally
  static void showGiftAnimation(
    BuildContext context, {
    required GiftModel gift,
    required String senderName,
    required String senderId,      // NEW
    required String currentUserId, // NEW
    String? senderPhoto,
    int comboCount = 1,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _GiftAnimationWidget(
        gift: gift,
        senderName: senderName,
        senderId: senderId,
        currentUserId: currentUserId,
        senderPhoto: senderPhoto,
        comboCount: comboCount,
        onComplete: () {
          overlayEntry.remove();
        },
      ),
    );

    overlay.insert(overlayEntry);
  }

  @override
  State<GiftAnimationOverlay> createState() => _GiftAnimationOverlayState();
}

class _GiftAnimationOverlayState extends State<GiftAnimationOverlay> {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Internal animation widget
class _GiftAnimationWidget extends StatefulWidget {
  final GiftModel gift;
  final String senderName;
  final String senderId;
  final String currentUserId;
  final String? senderPhoto;
  final int comboCount;
  final VoidCallback onComplete;

  const _GiftAnimationWidget({
    required this.gift,
    required this.senderName,
    required this.senderId,
    required this.currentUserId,
    this.senderPhoto,
    required this.comboCount,
    required this.onComplete,
  });

  @override
  State<_GiftAnimationWidget> createState() => _GiftAnimationWidgetState();
}

class _GiftAnimationWidgetState extends State<_GiftAnimationWidget>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  bool _showLottie = false;
  Timer? _autoCloseTimer;
  bool get isFromMe => widget.senderId == widget.currentUserId;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimation();
  }

  void _initializeAnimations() {
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
  }

  void _startAnimation() {
    _scaleController.forward();

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _showLottie = true);
    });

    final duration = widget.gift.isBigGift
        ? const Duration(seconds: 4)
        : const Duration(seconds: 2);

    _autoCloseTimer = Timer(duration, () => _closeAnimation());
  }

  void _closeAnimation() {
    if (mounted) {
      _fadeController.forward().then((_) => widget.onComplete());
    }
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    _scaleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Material(
            color: Colors.transparent,
            child: Stack(
              children: [
                if (widget.gift.isBigGift)
                  GestureDetector(
                    onTap: _closeAnimation,
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: Colors.black.withOpacity(0.6),
                    ),
                  ),

                Center(
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: widget.gift.isBigGift
                        ? _buildFullScreenGift()
                        : _buildSmallGiftNotification(),
                  ),
                ),

                if (widget.comboCount > 1)
                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.35,
                    right: 40,
                    child: _buildComboCounter(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFullScreenGift() {
    final glowColor = isFromMe ? const Color(0xFFFFD700) : _getGiftGlowColor();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Lottie / Emoji Center
        Container(
          width: 350,
          height: 350,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: glowColor.withOpacity(0.4),
                blurRadius: 60,
                spreadRadius: 25,
              ),
            ],
          ),
          child: _showLottie && widget.gift.animationUrl != null
              ? Lottie.network(
                  widget.gift.animationUrl!,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => _buildEmojiAnimation(),
                )
              : _buildEmojiAnimation(),
        ),

        const SizedBox(height: 20),

        // Premium Name Label
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: isFromMe 
                ? [const Color(0xFFFFD700), const Color(0xFFFFA000)] 
                : [Colors.white, glowColor],
          ).createShader(bounds),
          child: Text(
            widget.gift.name.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w900,
              letterSpacing: 6,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // "SENDER" Glass Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.senderPhoto != null)
                CircleAvatar(
                  radius: 18,
                  backgroundImage: NetworkImage(widget.senderPhoto!),
                )
              else
                CircleAvatar(
                  radius: 18,
                  backgroundColor: glowColor.withOpacity(0.3),
                  child: const Icon(Icons.person, size: 20, color: Colors.white),
                ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isFromMe ? 'GIFT FROM YOU' : 'SENT BY ${widget.senderName}',
                    style: TextStyle(
                      color: isFromMe ? const Color(0xFFFFD700) : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    '${widget.gift.effectivePrice} Diamonds',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSmallGiftNotification() {
    final glowColor = isFromMe ? const Color(0xFFFFD700) : const Color(0xFF9B6FD7);

    return Container(
      margin: const EdgeInsets.only(top: 150),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: glowColor.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.senderPhoto != null)
                CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(widget.senderPhoto!),
                )
              else
                CircleAvatar(
                  radius: 20,
                  backgroundColor: glowColor.withOpacity(0.2),
                  child: const Icon(Icons.person, color: Colors.white70, size: 20),
                ),
              const SizedBox(width: 14),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isFromMe ? 'YOU SENT' : widget.senderName,
                    style: TextStyle(
                      color: isFromMe ? const Color(0xFFFFD700) : Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    widget.gift.name,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              _buildEmojiAnimation(size: 40),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComboCounter() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF4500)]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.orange.withOpacity(0.4), blurRadius: 15, spreadRadius: 2)
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.flash_on_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 6),
                Text(
                  'x${widget.comboCount}',
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmojiAnimation({double size = 150}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 700),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Text(
            widget.gift.emoji,
            style: TextStyle(fontSize: widget.gift.isBigGift ? size : size),
          ),
        );
      },
    );
  }

  Color _getGiftGlowColor() {
    switch (widget.gift.category) {
      case 'luxury': return const Color(0xFFFFD700);
      case 'romantic': return const Color(0xFFFF69B4);
      case 'fun': return const Color(0xFF00CED1);
      default: return const Color(0xFF9B6FD7);
    }
  }
}

// Extension for easier onTap handling
extension OnTapWidget on Widget {
  Widget onTap(VoidCallback function) {
    return GestureDetector(
      onTap: function,
      child: this,
    );
  }
}
