import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'dart:ui';

class WithdrawalConditionsDialog extends StatelessWidget {
  final UserModel user;
  final bool isWalletValid;

  const WithdrawalConditionsDialog({
    super.key,
    required this.user,
    this.isWalletValid = true,
  });

  @override
  Widget build(BuildContext context) {
    // Gmail/Phone Condition: Check if at least one is linked
    final isContactVerified = user.email.isNotEmpty || (user.phoneNumber?.isNotEmpty ?? false);

    // Face Verification Condition
    final isFaceVerified = user.isVerified;

    int completedSteps = 0;
    if (isContactVerified) completedSteps++;
    if (isFaceVerified) completedSteps++;
    if (isWalletValid) completedSteps++;

    final allConditionsMet = completedSteps == 3;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(36),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
            border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Gradient Banner / Header
              _buildHeader(completedSteps),

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    const Text(
                      'Withdrawal Conditions',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'To ensure your safety, please complete all security verifications before withdrawing.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Condition Items
                    _buildPremiumConditionCard(
                      context: context,
                      icon: Icons.contact_mail_rounded,
                      title: 'Linked Contact',
                      subtitle: isContactVerified ? 'Verified Account' : 'Action Required',
                      isMet: isContactVerified,
                      onTap: () => Navigator.pushNamed(context, '/edit_profile'),
                    ),
                    const SizedBox(height: 16),
                    _buildPremiumConditionCard(
                      context: context,
                      icon: Icons.face_unlock_rounded,
                      title: 'Face Verification',
                      subtitle: isFaceVerified ? 'Identity Confirmed' : 'Action Required',
                      isMet: isFaceVerified,
                      onTap: () => Navigator.pushNamed(context, '/video_verification'),
                    ),
                    const SizedBox(height: 16),
                    _buildPremiumConditionCard(
                      context: context,
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'Wallet Setup',
                      subtitle: isWalletValid ? 'TRC20 Linked' : 'Address Required',
                      isMet: isWalletValid,
                      // Wallet setup usually happens on the withdraw screen itself
                    ),

                    const SizedBox(height: 32),

                    // Progress Text
                    if (!allConditionsMet)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_outline_rounded, color: Colors.orange.shade400, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Please complete all steps to unlock',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Action Button
                    _buildActionButton(context, allConditionsMet),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int completedSteps) {
    return Container(
      width: double.infinity,
      height: 140,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Decorative Circles
          Positioned(
            right: -20,
            top: -20,
            child: CircleAvatar(
              radius: 60,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          Positioned(
            left: -10,
            bottom: -30,
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
            ),
          ),

          // Icon and Progress
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                ),
                child: const Icon(Icons.security_rounded, color: Colors.white, size: 42),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'SECURITY PROGRESS: $completedSteps/3',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumConditionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isMet,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: isMet ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isMet ? Colors.green.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isMet ? Colors.green.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: isMet 
                    ? const LinearGradient(colors: [Color(0xFF00B09B), Color(0xFF96C93D)])
                    : LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade300]),
                borderRadius: BorderRadius.circular(15),
                boxShadow: isMet ? [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ] : [],
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isMet ? Colors.black87 : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isMet ? Colors.green.shade600 : Colors.blue.shade400,
                    ),
                  ),
                ],
              ),
            ),
            if (isMet)
              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28)
            else if (onTap != null)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.blue, size: 12),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, bool allMet) {
    return Container(
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A00E0).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () => Navigator.pop(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: const Text(
          'Understood',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}