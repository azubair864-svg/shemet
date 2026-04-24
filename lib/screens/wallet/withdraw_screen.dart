import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/user_provider.dart';
import '../../services/withdraw_service.dart';
import '../../widgets/withdrawal_conditions_dialog.dart';
import '../../core/utils/string_utils.dart';
import 'dart:ui';

class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final WithdrawService _withdrawService = WithdrawService();
  final double _exchangeRate = 0.01; // Example: 100 points = $1

  String _selectedMethod = 'Self';
  bool _isLoading = false;
  
  @override
  void dispose() {
    _amountController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _handleWithdraw() async {
    final amountText = _amountController.text;
    final double? amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.currentUser;
    if (user == null) return;

    if (!user.isVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete Face Verification first.'), backgroundColor: Colors.red),
      );
      return;
    }

    if ((user.phoneNumber == null || user.phoneNumber!.isEmpty) && 
        user.email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please link your Phone Number or Email to withdraw.'), backgroundColor: Colors.red),
      );
      return;
    }

    // New: TRC 20 Validation for 'Self'
    if (_selectedMethod == 'Self') {
      final address = _addressController.text.trim();
      if (!StringUtils.isValidTRC20(address)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid TRC 20 Wallet Address'), backgroundColor: Colors.red),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    // Call the Secure Backend Service
    final result = await _withdrawService.requestWithdrawal(
      amount: amount,
      method: _selectedMethod,
      methodDetails: {
        'account': user.email.isNotEmpty ? user.email : (user.phoneNumber ?? ''),
        if (_selectedMethod == 'Self') 'trc20Address': _addressController.text.trim(),
      },
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${result['message']}'),
          backgroundColor: Colors.green,
        ),
      );
      _amountController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${result['message']}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleAll() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final points = userProvider.currentUser?.earningsBeans ?? 0;
    final maxAmount = points * _exchangeRate;
    setState(() {
      _amountController.text = maxAmount.toStringAsFixed(2);
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.currentUser;
    final points = user?.earningsBeans ?? 0;
    final withdrawableAmount = points * _exchangeRate;

    // Condition Check
    final address = _addressController.text.trim();
    final bool isWalletValid = _selectedMethod == 'Agency' || StringUtils.isValidTRC20(address);
    final bool isContactVerified = user?.email.isNotEmpty == true || (user?.phoneNumber?.isNotEmpty ?? false);
    final bool isFaceVerified = user?.isVerified ?? false;
    final bool allConditionsMet = isContactVerified && isFaceVerified && isWalletValid;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: const Text(
          'Withdraw',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // 1. Premium Dynamic Background
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.8, -0.6),
                radius: 1.5,
                colors: [Color(0xFF1F1235), Colors.black],
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const SizedBox(height: 10),
                
                // === Main Withdrawal Card ===
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Coin Decoration (Background Layer)
                          _buildCoinDecoration(),

                          // Main Glass Container
                          ClipPath(
                            clipper: WithdrawCardShape(),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                              child: Container(
                                margin: const EdgeInsets.only(top: 20),
                                padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(32),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 30,
                                      offset: const Offset(0, 15),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabelRow(Icons.monetization_on_rounded, 'Withdrawal amount'),
                                    const SizedBox(height: 20),
                                    
                                    // Amount Input
                                    _buildAmountInput(),
                                    
                                    const SizedBox(height: 12),
                                    
                                    // Withdrawable Balance Info
                                    _buildBalanceRow(withdrawableAmount),
                                    
                                    const SizedBox(height: 32),
                                    
                                    // Withdraw Button
                                    _buildWithdrawButton(allConditionsMet),
                                    
                                    if (!allConditionsMet)
                                      _buildConditionWarning(),
                                    
                                    const SizedBox(height: 32),
                                    
                                    // Settings Header
                                    _buildSectionHeader('WITHDRAWAL SETTINGS'),
                                    const SizedBox(height: 12),

                                    // Method Selection
                                    _buildMethodSelector(context),

                                    // TRC 20 Input
                                    if (_selectedMethod == 'Self')
                                      _buildAddressInput(),

                                    // Conditions Trigger
                                    _buildConditionsTrigger(context, user, isWalletValid),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // === Withdraw History Card ===
                      _buildHistorySection(context, user),
                      
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoinDecoration() {
    return Positioned(
      right: 15,
      top: -10,
      child: SizedBox(
        width: 120,
        height: 70,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Positioned(left: 0, bottom: 0, child: _buildCoin(45)),
            Positioned(right: 0, bottom: 0, child: _buildCoin(45)),
            Positioned(top: 0, child: _buildCoin(55, isMain: true)),
          ],
        ),
      ),
    );
  }

  Widget _buildLabelRow(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.amber.withValues(alpha: 0.6), size: 16),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Colors.white24,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildAmountInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                '\$',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.black45,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.black, // BLACK TEXT as requested
                    letterSpacing: -1,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '0.00',
                    hintStyle: TextStyle(color: Colors.black12),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceRow(double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Withdrawable \$ ${amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        GestureDetector(
          onTap: _handleAll,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'MAX',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWithdrawButton(bool canWithdraw) {
    return Container(
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: canWithdraw 
          ? const LinearGradient(colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)])
          : null,
        color: canWithdraw ? null : Colors.white.withValues(alpha: 0.05),
        boxShadow: canWithdraw ? [
          BoxShadow(
            color: const Color(0xFF4A00E0).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ] : [],
      ),
      child: ElevatedButton(
        onPressed: (_isLoading || !canWithdraw) ? null : _handleWithdraw,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : Text(
                'Withdraw Now',
                style: TextStyle(
                  color: canWithdraw ? Colors.white : Colors.white24,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }

  Widget _buildConditionWarning() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, color: Colors.red.shade300, size: 14),
            const SizedBox(width: 6),
            Text(
              'Complete all conditions to enable',
              style: TextStyle(
                color: Colors.red.shade300,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white24,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildMethodSelector(BuildContext context) {
    return _buildPremiumTile(
      icon: Icons.account_balance_rounded,
      title: 'Withdraw to',
      trailing: _selectedMethod,
      accentColor: Colors.blueAccent,
      onTap: () => _showMethodPicker(context),
    );
  }

  void _showMethodPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              _buildPickerTile('Self', () {
                setState(() => _selectedMethod = 'Self');
                Navigator.pop(context);
              }, _selectedMethod == 'Self'),
              if (userProvider.currentUser?.gender != 'Male')
                _buildPickerTile('Agency', () {
                  setState(() => _selectedMethod = 'Agency');
                  Navigator.pop(context);
                }, _selectedMethod == 'Agency'),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPickerTile(String title, VoidCallback onTap, bool isSelected) {
    return ListTile(
      title: Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500)),
      trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.blueAccent) : null,
      onTap: onTap,
    );
  }

  Widget _buildAddressInput() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _addressController,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black), // BLACK TEXT as requested
        decoration: InputDecoration(
          hintText: 'Enter TRC 20 Wallet Address',
          hintStyle: TextStyle(color: Colors.black26, fontSize: 12),
          border: InputBorder.none,
          icon: Icon(Icons.account_balance_wallet_outlined, size: 16, color: Colors.purple.shade400),
          isDense: true,
        ),
        onChanged: (value) => setState(() {}),
      ),
    );
  }

  Widget _buildConditionsTrigger(BuildContext context, user, bool isValid) {
    return _buildPremiumTile(
      icon: Icons.verified_user_rounded,
      title: 'Security Conditions',
      trailing: 'Verify',
      accentColor: Colors.greenAccent,
      onTap: () {
        if (user != null) {
          showDialog(
            context: context,
            builder: (context) => WithdrawalConditionsDialog(
              user: user,
              isWalletValid: isValid,
            ),
          );
        }
      },
    );
  }

  Widget _buildHistorySection(BuildContext context, user) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader('WITHDRAW HISTORY'),
              _buildHistoryFilter(),
            ],
          ),
          const SizedBox(height: 24),
          if (user != null)
             StreamBuilder<List<Map<String, dynamic>>>(
              stream: _withdrawService.getWithdrawHistoryStream(user.uid),
              builder: (context, snapshot) {
                if (snapshot.hasError || snapshot.connectionState == ConnectionState.waiting || (snapshot.data ?? []).isEmpty) {
                  return _buildHistoryPlaceholder(snapshot);
                }
                
                final history = snapshot.data!;
                return ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: history.length,
                  separatorBuilder: (c, i) => Divider(color: Colors.white.withValues(alpha: 0.05), height: 32),
                  itemBuilder: (context, index) => _buildHistoryItem(history[index]),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Text('JANUARY', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900)),
          SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white38, size: 14),
        ],
      ),
    );
  }

  Widget _buildHistoryPlaceholder(AsyncSnapshot snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(strokeWidth: 2)));
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.history_toggle_off_rounded, color: Colors.white.withValues(alpha: 0.1), size: 48),
            const SizedBox(height: 16),
            Text('No records found', style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> item) {
    final date = item['createdAtDate'] as DateTime? ?? DateTime.now();
    final formattedDate = DateFormat('MMM dd, yyyy HH:mm').format(date);
    final status = item['status'] ?? 'pending';
    final isCompleted = status == 'completed';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '\$${item['amount'] ?? 0}',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                '${item['method']}: ${item['methodDetails']?['account'] ?? ''}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3), 
                  fontSize: 11,
                  overflow: TextOverflow.ellipsis,
                ),
                maxLines: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formattedDate, 
              style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 10),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isCompleted ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(color: isCompleted ? Colors.greenAccent : Colors.orangeAccent, fontSize: 9, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPremiumTile({
    required IconData icon,
    required String title,
    String? trailing,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.01)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(icon, color: accentColor, size: 18),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              ),
              if (trailing != null)
                Text(trailing, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withValues(alpha: 0.1), size: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoin(double size, {bool isMain = false}) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isMain 
              ? [const Color(0xFFFFD700), const Color(0xFFB8860B)] 
              : [const Color(0xFFDAA520), const Color(0xFF8B7500)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.3),
            blurRadius: isMain ? 12 : 8,
            offset: const Offset(2, 4),
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Center(
        child: Text(
          '\$',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontWeight: FontWeight.w900,
            fontSize: size * 0.5,
            shadows: const [Shadow(color: Colors.black26, blurRadius: 4)],
          ),
        ),
      ),
    );
  }
}

class WithdrawCardShape extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final double radius = 32.0;
    final double dropHeight = 60.0; 
    final double tabStartX = size.width * 0.38;
    final double transitionWidth = 110.0; 
    final double tabEndX = tabStartX + transitionWidth;

    path.moveTo(0, radius);
    path.quadraticBezierTo(0, 0, radius, 0);
    path.lineTo(tabStartX, 0);

    path.cubicTo(
      tabStartX + (transitionWidth * 0.65), 0,
      tabEndX - (transitionWidth * 0.65), dropHeight,
      tabEndX, dropHeight,
    );

    path.lineTo(size.width - radius, dropHeight);
    path.arcToPoint(Offset(size.width, dropHeight + radius), radius: Radius.circular(radius), clockwise: true);
    path.lineTo(size.width, size.height - radius);
    path.quadraticBezierTo(size.width, size.height, size.width - radius, size.height);
    path.lineTo(radius, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - radius);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
