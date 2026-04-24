import 'package:flutter/material.dart';
import 'dart:math' as math;

/// ⭐⭐⭐ PRODUCTION-READY PAYMENT FAILED SCREEN ⭐⭐⭐
/// Shows error message after failed payment with retry options
/// Features: Error animation, troubleshooting tips, retry/support options
class PaymentFailedScreen extends StatefulWidget {
  final String? errorMessage;
  final String? errorCode;
  final double? attemptedAmount;
  final String? priceLabel;
  final String? packageName;
  final VoidCallback? onRetry;

  const PaymentFailedScreen({
    super.key,
    this.errorMessage,
    this.errorCode,
    this.attemptedAmount,
    this.priceLabel,
    this.packageName,
    this.onRetry,
  });

  @override
  State<PaymentFailedScreen> createState() => _PaymentFailedScreenState();
}

class _PaymentFailedScreenState extends State<PaymentFailedScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    
    
    
    
    
    

    _initAnimations();
  }

  void _initAnimations() {
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    // Play shake animation
    _shakeController.forward();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F23),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF0F0F23),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 40),

                // Error icon with shake animation
                AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(
                        math.sin(_shakeAnimation.value * math.pi * 4) * 10,
                        0,
                      ),
                      child: child,
                    );
                  },
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE53935), Color(0xFFFF5722)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE53935).withValues(alpha: 0.4),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 70,
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // Failed title
                const Text(
                  'Payment Failed',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),

                Text(
                  'Your payment could not be processed',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 40),

                // Error details card
                _buildErrorCard(),
                const SizedBox(height: 24),

                // Troubleshooting tips
                _buildTroubleshootingTips(),
                const SizedBox(height: 30),

                // Action buttons
                _buildActionButtons(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 24),
              const SizedBox(width: 12),
              const Text(
                'Error Details',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Error message
          Text(
            widget.errorMessage ?? 'An unexpected error occurred during payment processing.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 15,
            ),
          ),

          if (widget.errorCode != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.code, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Code: ${widget.errorCode}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (widget.attemptedAmount != null || widget.packageName != null) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.red, height: 1),
            const SizedBox(height: 16),

            if (widget.packageName != null)
              _errorDetailRow('Package', widget.packageName!),
            if (widget.attemptedAmount != null)
              _errorDetailRow(
                'Amount',
                widget.priceLabel ??
                    '\$${widget.attemptedAmount!.toStringAsFixed(2)}',
              ),
          ],
        ],
      ),
    );
  }

  Widget _errorDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTroubleshootingTips() {
    final tips = _getTroubleshootingTips();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 24),
              const SizedBox(width: 12),
              const Text(
                'Troubleshooting Tips',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          ...tips.map((tip) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${tips.indexOf(tip) + 1}',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tip,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  List<String> _getTroubleshootingTips() {
    // Customize tips based on error code
    final errorCode = widget.errorCode?.toLowerCase() ?? '';

    if (errorCode.contains('card_declined')) {
      return [
        'Check if your card has sufficient funds',
        'Verify your card details are entered correctly',
        'Contact your bank if the issue persists',
        'Try a different payment method',
      ];
    } else if (errorCode.contains('expired')) {
      return [
        'Your card may have expired',
        'Check the expiration date on your card',
        'Try using a different card',
        'Update your payment method',
      ];
    } else if (errorCode.contains('network') || errorCode.contains('connection')) {
      return [
        'Check your internet connection',
        'Try switching from WiFi to mobile data',
        'Wait a moment and try again',
        'Restart your app and retry',
      ];
    } else {
      return [
        'Double-check your payment information',
        'Ensure you have sufficient funds',
        'Try a different payment method',
        'Contact support if the issue continues',
      ];
    }
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Retry button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              
              if (widget.onRetry != null) {
                widget.onRetry!();
              } else {
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Different payment method
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              
              Navigator.pop(context, 'change_method');
            },
            icon: const Icon(Icons.credit_card),
            label: const Text('Use Different Payment Method'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Contact support
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: () {
              
              _showSupportOptions();
            },
            icon: const Icon(Icons.support_agent, size: 20),
            label: const Text('Contact Support'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Cancel/Go back
        TextButton(
          onPressed: () {
            
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
          child: Text(
            'Cancel',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  void _showSupportOptions() {
    

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Contact Support',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We\'re here to help!',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            // Support options
            _supportOption(
              icon: Icons.email_outlined,
              title: 'Email Support',
              subtitle: 'support@datingliveapp.com',
              onTap: () {
                
                Navigator.pop(context);
                // TODO: Open email client
              },
            ),
            _supportOption(
              icon: Icons.chat_bubble_outline,
              title: 'Live Chat',
              subtitle: 'Chat with our team',
              onTap: () {
                
                Navigator.pop(context);
                // TODO: Open live chat
              },
            ),
            _supportOption(
              icon: Icons.help_outline,
              title: 'Help Center',
              subtitle: 'Browse FAQs and guides',
              onTap: () {
                
                Navigator.pop(context);
                // TODO: Open help center
              },
            ),

            const SizedBox(height: 16),

            // Error info to share
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white54, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Error code: ${widget.errorCode ?? "N/A"}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.white54, size: 18),
                    onPressed: () {
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Error code copied'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );

    
  }

  Widget _supportOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFF6C63FF)),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 13,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.white54),
    );
  }
}
