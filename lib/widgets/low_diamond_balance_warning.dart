import 'package:flutter/material.dart';
import '../screens/coins/diamond_purchase_screen.dart'; // Will be renamed later

/// ⭐⭐⭐ PRODUCTION-READY LOW DIAMOND BALANCE WARNING ⭐⭐⭐
/// Shows warning when user's diamond balance is low
/// Features: Customizable threshold, multiple display modes, quick purchase
class LowDiamondBalanceWarning extends StatelessWidget {
  final int currentBalance;
  final int warningThreshold;
  final int requiredAmount;
  final VoidCallback? onDismiss;
  final bool showPurchaseButton;
  final WarningDisplayMode displayMode;

  const LowDiamondBalanceWarning({
    super.key,
    required this.currentBalance,
    this.warningThreshold = 100,
    this.requiredAmount = 0,
    this.onDismiss,
    this.showPurchaseButton = true,
    this.displayMode = WarningDisplayMode.banner,
  });

  @override
  Widget build(BuildContext context) {
    // Don't show if balance is above threshold and no specific requirement
    if (currentBalance >= warningThreshold && requiredAmount == 0) {
      return const SizedBox.shrink();
    }

    // Check if balance is insufficient for required amount
    final isInsufficient = requiredAmount > 0 && currentBalance < requiredAmount;
    final isLow = currentBalance < warningThreshold;

    if (!isInsufficient && !isLow) {
      return const SizedBox.shrink();
    }

    switch (displayMode) {
      case WarningDisplayMode.banner:
        return _buildBanner(context, isInsufficient);
      case WarningDisplayMode.dialog:
        return _buildDialogContent(context, isInsufficient);
      case WarningDisplayMode.inline:
        return _buildInline(context, isInsufficient);
      case WarningDisplayMode.snackbar:
        return const SizedBox.shrink(); // Snackbar is shown via static method
    }
  }

  Widget _buildBanner(BuildContext context, bool isInsufficient) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isInsufficient
              ? [const Color(0xFFE53935), const Color(0xFFFF5722)]
              : [const Color(0xFFFFA726), const Color(0xFFFFB74D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isInsufficient ? Colors.red : Colors.orange).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isInsufficient ? Icons.error_outline : Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isInsufficient ? 'Insufficient Diamonds' : 'Low Balance',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isInsufficient
                          ? 'You need ${requiredAmount - currentBalance} more diamonds'
                          : 'Your balance is running low',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: onDismiss,
                ),
            ],
          ),
          if (showPurchaseButton) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                // Current balance
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('💎', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Text(
                        '$currentBalance',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Purchase button
                ElevatedButton(
                  onPressed: () => _navigateToPurchase(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: isInsufficient ? Colors.red : Colors.orange,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_circle, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Get Diamonds',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInline(BuildContext context, bool isInsufficient) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (isInsufficient ? Colors.red : Colors.orange).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (isInsufficient ? Colors.red : Colors.orange).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isInsufficient ? Icons.error : Icons.warning,
            color: isInsufficient ? Colors.red : Colors.orange,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            isInsufficient
                ? 'Need ${requiredAmount - currentBalance} more diamonds'
                : 'Low balance: $currentBalance diamonds',
            style: TextStyle(
              color: isInsufficient ? Colors.red : Colors.orange,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (showPurchaseButton) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _navigateToPurchase(context),
              child: Text(
                'Top up',
                style: TextStyle(
                  color: isInsufficient ? Colors.red : Colors.orange,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDialogContent(BuildContext context, bool isInsufficient) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: (isInsufficient ? Colors.red : Colors.orange).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text('💎', style: TextStyle(fontSize: 40)),
          ),
        ),
        const SizedBox(height: 20),

        // Title
        Text(
          isInsufficient ? 'Insufficient Diamonds' : 'Low Balance Warning',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        // Message
        Text(
          isInsufficient
              ? 'You need ${requiredAmount - currentBalance} more diamonds to complete this action.'
              : 'Your diamond balance is getting low. Top up to continue enjoying all features.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 20),

        // Current balance
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💎', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Text(
                'Current: $currentBalance',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (requiredAmount > 0) ...[
                const SizedBox(width: 16),
                Text(
                  'Need: $requiredAmount',
                  style: TextStyle(
                    color: Colors.red.shade300,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Buttons
        if (showPurchaseButton)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _navigateToPurchase(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BFFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Get More Diamonds',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _navigateToPurchase(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DiamondPurchaseScreen()),
    );
  }

  /// Show low balance warning as a snackbar
  static void showSnackbar(
    BuildContext context, {
    required int currentBalance,
    int warningThreshold = 100,
    int? requiredAmount,
  }) {
    final isInsufficient = requiredAmount != null && currentBalance < requiredAmount;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isInsufficient ? Colors.red.shade700 : Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            Icon(
              isInsufficient ? Icons.error : Icons.warning,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isInsufficient
                    ? 'Need ${requiredAmount - currentBalance} more diamonds'
                    : 'Low balance: $currentBalance diamonds remaining',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'GET DIAMONDS',
          textColor: Colors.white,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DiamondPurchaseScreen()),
            );
          },
        ),
      ),
    );
  }

  /// Show low balance warning as a dialog
  static Future<void> showWarningDialog(
    BuildContext context, {
    required int currentBalance,
    int warningThreshold = 100,
    int? requiredAmount,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: LowDiamondBalanceWarning(
            currentBalance: currentBalance,
            warningThreshold: warningThreshold,
            requiredAmount: requiredAmount ?? 0,
            displayMode: WarningDisplayMode.dialog,
          ),
        ),
      ),
    );
  }

  /// Check if balance is low and optionally show warning
  static bool checkAndWarn(
    BuildContext context, {
    required int currentBalance,
    int warningThreshold = 100,
    int? requiredAmount,
    bool showWarning = true,
    WarningDisplayMode mode = WarningDisplayMode.snackbar,
  }) {
    final isLow = currentBalance < warningThreshold;
    final isInsufficient = requiredAmount != null && currentBalance < requiredAmount;

    if ((isLow || isInsufficient) && showWarning) {
      switch (mode) {
        case WarningDisplayMode.snackbar:
          showSnackbar(
            context,
            currentBalance: currentBalance,
            warningThreshold: warningThreshold,
            requiredAmount: requiredAmount,
          );
          break;
        case WarningDisplayMode.dialog:
          showWarningDialog(
            context,
            currentBalance: currentBalance,
            warningThreshold: warningThreshold,
            requiredAmount: requiredAmount,
          );
          break;
        default:
          break;
      }
    }

    return isLow || isInsufficient;
  }
}

/// Display modes for the low balance warning
enum WarningDisplayMode {
  banner,    // Full-width banner with icon and button
  dialog,    // Modal dialog content
  inline,    // Compact inline warning
  snackbar,  // Bottom snackbar notification
}
