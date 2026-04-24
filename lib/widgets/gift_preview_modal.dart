import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../models/gift_model.dart';
import '../screens/coins/diamond_purchase_screen.dart';

/// ⭐⭐⭐ PRODUCTION-READY GIFT PREVIEW MODAL ⭐⭐⭐
/// Shows detailed gift preview before sending
/// Features: Animation preview, price info, combo selector, send button
class GiftPreviewModal extends StatefulWidget {
  final GiftModel gift;
  final int userCoinBalance;
  final Function(GiftModel gift, int comboCount) onSendGift;
  final VoidCallback? onClose;

  const GiftPreviewModal({
    super.key,
    required this.gift,
    required this.userCoinBalance,
    required this.onSendGift,
    this.onClose,
  });

  @override
  State<GiftPreviewModal> createState() => _GiftPreviewModalState();

  /// Show gift preview as a bottom sheet
  static Future<void> show(
    BuildContext context, {
    required GiftModel gift,
    required int userCoinBalance,
    required Function(GiftModel gift, int comboCount) onSendGift,
  }) async {
    
    
    
    
    

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => GiftPreviewModal(
        gift: gift,
        userCoinBalance: userCoinBalance,
        onSendGift: onSendGift,
      ),
    );
  }
}

class _GiftPreviewModalState extends State<GiftPreviewModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  int _selectedCombo = 1;
  bool _isAnimating = false;

  // Combo options
  final List<int> _comboOptions = [1, 5, 10, 50, 99];

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // Auto-play animation preview
    _playAnimationPreview();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _playAnimationPreview() {
    
    setState(() => _isAnimating = true);
    _animationController.forward().then((_) {
      _animationController.reset();
      setState(() => _isAnimating = false);
    });
  }

  int get _totalPrice => widget.gift.price * _selectedCombo;

  bool get _canAfford => widget.userCoinBalance >= _totalPrice;

  @override
  Widget build(BuildContext context) {
    
    
    
    

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text(
                  'Gift Preview',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () {
                    widget.onClose?.call();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white12),

          // Gift preview area
          _buildGiftPreview(),

          // Gift info
          _buildGiftInfo(),

          // Combo selector
          _buildComboSelector(),

          // Price summary
          _buildPriceSummary(),

          // Send button
          _buildSendButton(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildGiftPreview() {
    return Container(
      height: 200,
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getCategoryColor(widget.gift.category).withValues(alpha: 0.2),
            _getCategoryColor(widget.gift.category).withValues(alpha: 0.05),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getCategoryColor(widget.gift.category).withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background particles for luxury gifts
          if (widget.gift.isBigGift) _buildParticleEffect(),

          // Main gift display
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Gift animation/emoji
              if (widget.gift.animationUrl != null && widget.gift.animationUrl!.isNotEmpty)
                SizedBox(
                  width: 100,
                  height: 100,
                  child: Lottie.network(
                    widget.gift.animationUrl!,
                    controller: _animationController,
                    errorBuilder: (context, error, stackTrace) {
                      
                      return _buildEmojiDisplay();
                    },
                  ),
                )
              else
                _buildEmojiDisplay(),

              const SizedBox(height: 12),

              // Gift name with glow effect for luxury
              Text(
                widget.gift.name,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  shadows: widget.gift.isBigGift
                      ? [
                          Shadow(
                            color: _getCategoryColor(widget.gift.category),
                            blurRadius: 20,
                          ),
                        ]
                      : null,
                ),
              ),
            ],
          ),

          // Replay button
          Positioned(
            bottom: 10,
            right: 10,
            child: IconButton(
              icon: Icon(
                Icons.replay,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              onPressed: _playAnimationPreview,
              tooltip: 'Replay animation',
            ),
          ),

          // Category badge
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getCategoryColor(widget.gift.category),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.gift.category.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Big gift badge
          if (widget.gift.isBigGift)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.amber, Colors.orange],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'BIG GIFT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
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

  Widget _buildEmojiDisplay() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final scale = 1.0 + (_animationController.value * 0.2);
        return Transform.scale(
          scale: _isAnimating ? scale : 1.0,
          child: Text(
            widget.gift.emoji,
            style: const TextStyle(fontSize: 72),
          ),
        );
      },
    );
  }

  Widget _buildParticleEffect() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(200, 200),
          painter: _ParticlePainter(
            progress: _animationController.value,
            color: _getCategoryColor(widget.gift.category),
          ),
        );
      },
    );
  }

  Widget _buildGiftInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Price per gift
          Expanded(
            child: _buildInfoCard(
              'Price',
              '${widget.gift.price}',
              Icons.monetization_on,
              Colors.amber,
            ),
          ),
          const SizedBox(width: 12),

          // Diamonds earned by receiver
          Expanded(
            child: _buildInfoCard(
              'Receiver Gets',
              '${widget.gift.price ~/ 2}',
              Icons.diamond,
              Colors.cyan,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComboSelector() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Combo',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: _comboOptions.map((combo) {
              final isSelected = _selectedCombo == combo;
              final canAffordCombo = widget.userCoinBalance >= (widget.gift.price * combo);

              return Expanded(
                child: GestureDetector(
                  onTap: canAffordCombo
                      ? () {
                          
                          setState(() => _selectedCombo = combo);
                        }
                      : null,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.amber
                          : canAffordCombo
                              ? const Color(0xFF16213E)
                              : const Color(0xFF16213E).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Colors.amber
                            : canAffordCombo
                                ? Colors.white24
                                : Colors.white12,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'x$combo',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.black
                                : canAffordCombo
                                    ? Colors.white
                                    : Colors.white38,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (combo > 1) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${widget.gift.price * combo}',
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.black54
                                  : canAffordCombo
                                      ? Colors.amber
                                      : Colors.white24,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceSummary() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _canAfford
            ? Colors.green.withValues(alpha: 0.15)
            : Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _canAfford
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          // User balance
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Balance',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.monetization_on, color: Colors.amber, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.userCoinBalance}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),

          // Arrow
          Icon(
            Icons.arrow_forward,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const Spacer(),

          // Total cost
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Total Cost',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.monetization_on, color: Colors.amber, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '$_totalPrice',
                    style: TextStyle(
                      color: _canAfford ? Colors.green : Colors.red,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _canAfford
              ? () {
                  
                  Navigator.pop(context);
                  widget.onSendGift(widget.gift, _selectedCombo);
                }
              : () {
                  
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DiamondPurchaseScreen()),
                  );
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: _canAfford ? Colors.amber : Colors.red.shade400,
            foregroundColor: _canAfford ? Colors.black : Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _canAfford ? Icons.send : Icons.add_circle,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                _canAfford
                    ? 'Send ${widget.gift.name} ${_selectedCombo > 1 ? "x$_selectedCombo" : ""}'
                    : 'Get More Coins',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'romantic':
        return Colors.pink;
      case 'luxury':
        return Colors.purple;
      case 'fun':
        return Colors.orange;
      case 'celebration':
        return Colors.blue;
      case 'special':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }
}

/// Particle effect painter for luxury gifts
class _ParticlePainter extends CustomPainter {
  final double progress;
  final Color color;

  _ParticlePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.3 * (1 - progress))
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Draw expanding circles
    for (int i = 0; i < 3; i++) {
      final delay = i * 0.2;
      final adjustedProgress = ((progress - delay) % 1.0).clamp(0.0, 1.0);
      final radius = maxRadius * adjustedProgress;

      paint.color = color.withValues(alpha: 0.2 * (1 - adjustedProgress));
      canvas.drawCircle(center, radius, paint);
    }

    // Draw sparkles
    final sparkleCount = 8;
    for (int i = 0; i < sparkleCount; i++) {
      final angle = (i / sparkleCount) * 3.14159 * 2;
      final distance = maxRadius * 0.6 * progress;
      final x = center.dx + distance * (angle).cos();
      final y = center.dy + distance * (angle).sin();

      paint.color = color.withValues(alpha: (1 - progress) * 0.8);
      canvas.drawCircle(Offset(x, y), 3 * (1 - progress), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Extension for cos and sin using dart:math
extension DoubleExtension on double {
  double cos() => math.cos(this);
  double sin() => math.sin(this);
}
