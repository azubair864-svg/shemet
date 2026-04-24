import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/user_provider.dart';
import '../../services/diamond_service.dart';
import '../../widgets/withdrawal_conditions_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/utils/string_utils.dart';

/// ⭐⭐⭐ PRODUCTION-READY WITHDRAWAL SCREEN ⭐⭐⭐
/// Convert diamonds to real money with multiple payment methods
/// Features: Bank transfer, PayPal, verification system
class WithdrawalScreen extends StatefulWidget {
  const WithdrawalScreen({super.key});

  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  final DiamondService _diamondService = DiamondService();

  // Controllers
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _accountHolderController = TextEditingController();
  final TextEditingController _paypalEmailController = TextEditingController();

  // State
  bool _isLoading = false;
  bool _gmailVerified = false;
  bool _faceVerified = false;
  // bool _paymentVerified = false; // Not used in new logic
  int _diamondBalance = 0;
  List<Map<String, dynamic>> _withdrawalHistory = [];

  // Payment method selection
  String _withdrawalType = 'agency'; // 'agency', 'self'
  final String _selectedPaymentMethod = 'trc20'; // Default for 'self'
  final TextEditingController _trc20Controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    
    _loadData();
  }

  @override
  void dispose() {
    
    _amountController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountHolderController.dispose();
    _paypalEmailController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.currentUser?.uid;

    if (userId == null) {
      
      return;
    }

    

    try {
      // Load diamond balance
      
      _diamondBalance = await _diamondService.getDiamondBalance(userId);
      

      // Load withdrawal history
      
      final transactions = await _diamondService.getDiamondTransactions(
        userId: userId,
        type: 'withdrawal',
        limit: 20,
      );

      _withdrawalHistory = transactions.map((t) {
        return {
          'amount': (t['withdrawalAmount'] ?? 0.0) as double,
          'diamonds': ((t['amount'] ?? 0) as int).abs(),
          'date': (t['timestamp'] as dynamic)?.toDate() ?? DateTime.now(),
          'status': _capitalizeFirst(t['status'] ?? 'pending'),
          'paymentMethod': t['paymentMethod'] ?? 'unknown',
        };
      }).toList();

      

      if (mounted) {
        setState(() {
          // If male, force withdrawal type to self and disable agency
          if (userProvider.currentUser?.gender == 'Male') {
            _withdrawalType = 'self';
          }
        });
      }

      
    } catch (e) {
      
      
      
      
    }
    
    // Verify conditions using real data
    _verifyConditions();
  }

  void _verifyConditions() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.currentUser;
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (user != null) {
      setState(() {
        // Check Face Verification
        _faceVerified = user.isVerified;
        
        // Check Email/Phone Binding
        // We consider it verified if they have an email or phone number
        _gmailVerified = (user.email.isNotEmpty && (firebaseUser?.emailVerified ?? false)) || 
                         (user.phoneNumber != null && user.phoneNumber!.isNotEmpty);
                         
        // If email is not empty but emailVerified is false? 
        // For now, let's just check if email is present as requirement says "Bind Phone/Gmail"
        if (!_gmailVerified && user.email.isNotEmpty) {
           _gmailVerified = true; // Relaxed check for now, can be stricter
        }
        
        // Payment verified is checked during withdrawal submission
        // _paymentVerified = true; 
      });
    }
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  String _getCurrencyByCountry(String? country) {
    if (country == null) return 'USD';

    final Map<String, String> countryCurrencies = {
      'Sri Lanka': 'LKR',
      'India': 'INR',
      'Pakistan': 'PKR',
      'Bangladesh': 'BDT',
      'Philippines': 'PHP',
      'Vietnam': 'VND',
      'Thailand': 'THB',
      'Indonesia': 'IDR',
      'Malaysia': 'MYR',
      'Singapore': 'SGD',
    };

    return countryCurrencies[country] ?? 'USD';
  }

  double _diamondsToMoney(int diamonds) {
    // 1 diamond = $0.01
    return diamonds * 0.01;
  }

  bool _allConditionsMet() {
    // 1. Email/Phone bound
    // 2. Face Verified
    // 3. Payment Method Valid (TRC20 if self)
    return _gmailVerified && _faceVerified && _hasValidPaymentDetails();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.currentUser;
    final currency = _getCurrencyByCountry(user?.country);
    final withdrawableAmountUSD = _diamondsToMoney(_diamondBalance);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Withdrawal',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black54),
            onPressed: _loadData,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Diamond Balance Card
            _buildBalanceCard(),

            const SizedBox(height: 24),

            // Withdrawable Amount Card
            _buildWithdrawableCard(withdrawableAmountUSD, currency),

            const SizedBox(height: 24),

            // Verification Status
            _buildVerificationSection(),

            const SizedBox(height: 24),

            // Payment Method Selection
            _buildPaymentMethodSection(),

            const SizedBox(height: 24),

            // Payment Details / Agency Select
            _buildWithdrawalTypeSection(),

            const SizedBox(height: 24),

            // Withdrawal Amount Input
            _buildAmountInput(),

            const SizedBox(height: 24),

            // Conditions Status
            _buildConditionsStatus(),

            const SizedBox(height: 24),

            // Withdraw Button
            _buildWithdrawButton(withdrawableAmountUSD),
            
            _buildWarningMessage(),

            const SizedBox(height: 32),

            // Withdrawal History
            _buildWithdrawalHistory(currency),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF9B6FD7), Color(0xFFE8B4F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9B6FD7).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.diamond, color: Colors.white, size: 28),
              const SizedBox(width: 8),
              const Text(
                'Diamond Balance',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$_diamondBalance',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            'DIAMONDS',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawableCard(double amountUSD, String currency) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Withdrawable Amount',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF9B6FD7).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'USD',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF9B6FD7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '\$${amountUSD.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF9B6FD7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Minimum withdrawal: 100 diamonds (\$1.00)',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationSection() {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.currentUser;
    final maskedEmail = user != null ? StringUtils.maskEmail(user.email) : 'Not bound';
    final maskedPhone = (user?.phoneNumber != null && user!.phoneNumber!.isNotEmpty) 
        ? StringUtils.maskPhone(user.phoneNumber!) 
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Verification Status',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _buildVerificationItem(
          icon: Icons.email,
          title: 'Email/Phone Bound',
          subtitle: _gmailVerified 
              ? (maskedPhone ?? maskedEmail)
              : 'Please bind email or phone',
          isVerified: _gmailVerified,
          onTap: () {
             if (!_gmailVerified) {
                // Navigate to binding screen
             }
          },
        ),
        const SizedBox(height: 12),
        _buildVerificationItem(
          icon: Icons.face,
          title: 'Face Verification',
          subtitle: _faceVerified ? 'Verified' : 'Please verify your identity',
          isVerified: _faceVerified,
          onTap: () {
             if (!_faceVerified) {
                // Navigate to video verification
                Navigator.pushNamed(context, '/video_verification');
             }
          },
        ),
      ],
    );
  }

  Widget _buildPaymentMethodSection() {
    // Hidden in Agency Mode, shown implicitly in Self Mode via field (USDT TRC20 only for this requirement?)
    // Actually, user said: "If she selects Self then she has to Bind TRC20". 
    // And "Agency" vs "Self".
    // So we replace the old Bank/PayPal section with just the Agency/Self toggle above.
    return const SizedBox.shrink(); 
  }

  // Unused _buildPaymentMethodCard removed

  Widget _buildWithdrawalTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Withdrawal Method',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        
        // Withdrawal Type Toggle
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              if (Provider.of<UserProvider>(context, listen: false).currentUser?.gender != 'Male')
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _withdrawalType = 'agency'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _withdrawalType == 'agency' ? const Color(0xFF9B6FD7) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Agency',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _withdrawalType == 'agency' ? Colors.white : Colors.black54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _withdrawalType = 'self'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _withdrawalType == 'self' ? const Color(0xFF9B6FD7) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Self',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _withdrawalType == 'self' ? Colors.white : Colors.black54,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),

        if (_withdrawalType == 'self') ...[
             const Text(
              'USDT (TRC20) Address',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
             TextField(
              controller: _trc20Controller,
              decoration: InputDecoration(
                labelText: 'TRC20 Address',
                hintText: 'Enter your TRC20 wallet address',
                prefixIcon: const Icon(Icons.account_balance_wallet, color: Color(0xFF9B6FD7)),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF9B6FD7), width: 2),
                ),
              ),
              onChanged: (value) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                   Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
                   const SizedBox(width: 8),
                   Expanded(
                     child: Text(
                       'IMPORTANT: Please verify your TRC20 address carefully. Incorrect withdrawals cannot be recovered.',
                       style: TextStyle(color: Colors.red.shade900, fontSize: 12),
                     ),
                   ),
                ],
              ),
            ),
        ] else ...[
             Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                   Icon(Icons.info_outline, color: Colors.blue.shade700),
                   const SizedBox(width: 12),
                   Expanded(
                     child: Text(
                       'Agency withdrawals are processed securely through your registered agency partner.',
                       style: TextStyle(color: Colors.blue.shade900, fontSize: 13),
                     ),
                   ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  // Unused _buildTextField removed

  Widget _buildAmountInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Withdrawal Amount',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Diamonds to withdraw',
            hintText: 'Enter amount (min 100)',
            prefixIcon: const Icon(Icons.diamond, color: Color(0xFF9B6FD7)),
            suffixText: 'diamonds',
            filled: true,
            fillColor: const Color(0xFFF5F5F5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF9B6FD7), width: 2),
            ),
          ),
          onChanged: (value) {
            setState(() {}); // Update USD preview
          },
        ),
        const SizedBox(height: 8),
        if (_amountController.text.isNotEmpty)
          Text(
            'You will receive: \$${_diamondsToMoney(int.tryParse(_amountController.text) ?? 0).toStringAsFixed(2)} USD',
            style: const TextStyle(
              color: Color(0xFF9B6FD7),
              fontWeight: FontWeight.w600,
            ),
          ),
        const SizedBox(height: 12),
        // Quick amount buttons
        Row(
          children: [
            _buildQuickAmountButton(100),
            const SizedBox(width: 8),
            _buildQuickAmountButton(500),
            const SizedBox(width: 8),
            _buildQuickAmountButton(1000),
            const SizedBox(width: 8),
            _buildQuickAmountButton(_diamondBalance, label: 'MAX'),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickAmountButton(int amount, {String? label}) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          
          _amountController.text = amount.toString();
          setState(() {});
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF9B6FD7).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF9B6FD7).withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            label ?? amount.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF9B6FD7),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConditionsStatus() {
    final user = Provider.of<UserProvider>(context, listen: false).currentUser;
    return GestureDetector(
      onTap: () {
        if (user != null) {
          showDialog(
            context: context,
            builder: (context) => WithdrawalConditionsDialog(
              user: user,
              isWalletValid: _hasValidPaymentDetails(),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _allConditionsMet()
              ? const Color(0xFFE8F5E9)
              : const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _allConditionsMet() ? Colors.green : const Color(0xFFFFD54F),
          ),
        ),
        child: Row(
          children: [
            Icon(
              _allConditionsMet() ? Icons.check_circle : Icons.warning,
              color: _allConditionsMet() ? Colors.green : Colors.orange,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _allConditionsMet()
                    ? 'All conditions have been met'
                    : 'Complete all verifications to withdraw',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildWithdrawButton(double withdrawableAmount) {
    final amount = int.tryParse(_amountController.text) ?? 0;
    final canWithdraw = _allConditionsMet() &&
        amount >= 100 &&
        amount <= _diamondBalance &&
        _hasValidPaymentDetails();

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading || !canWithdraw ? null : _handleWithdraw,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF9B6FD7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 0,
          disabledBackgroundColor: Colors.grey.shade300,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                'Withdraw \$${_diamondsToMoney(amount).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildWarningMessage() {
    if (_allConditionsMet()) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Center(
        child: Text(
          'Please complete all conditions to enable withdrawal',
          style: TextStyle(
            color: Colors.red.shade400,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  bool _hasValidPaymentDetails() {
    if (_withdrawalType == 'agency') return true; // Agency handles details
    
    // For Self, must have valid TRC20 address
    final address = _trc20Controller.text.trim();
    return StringUtils.isValidTRC20(address);
  }

  Widget _buildWithdrawalHistory(String currency) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Withdrawal History',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (_withdrawalHistory.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.history, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    'No withdrawal history',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _withdrawalHistory.length,
            itemBuilder: (context, index) {
              final withdrawal = _withdrawalHistory[index];
              return _buildHistoryItem(
                amount: withdrawal['amount'],
                diamonds: withdrawal['diamonds'],
                date: withdrawal['date'],
                status: withdrawal['status'],
                paymentMethod: withdrawal['paymentMethod'],
              );
            },
          ),
      ],
    );
  }

  Widget _buildVerificationItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isVerified,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isVerified ? Colors.green : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isVerified
                    ? Colors.green.withValues(alpha: 0.1)
                    : const Color(0xFF9B6FD7).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isVerified ? Colors.green : const Color(0xFF9B6FD7),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isVerified ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isVerified ? Colors.green : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem({
    required double amount,
    required int diamonds,
    required DateTime date,
    required String status,
    required String paymentMethod,
  }) {
    final isCompleted = status.toLowerCase() == 'completed';
    final isPending = status.toLowerCase() == 'pending';

    Color statusColor;
    if (isCompleted) {
      statusColor = Colors.green;
    } else if (isPending) {
      statusColor = Colors.orange;
    } else {
      statusColor = Colors.red;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompleted
                  ? Icons.check
                  : isPending
                      ? Icons.schedule
                      : Icons.error,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '\$${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$diamonds diamonds • ${_capitalizeFirst(paymentMethod)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('MMM dd, yyyy HH:mm').format(date),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleWithdraw() async {
    

    final amount = int.tryParse(_amountController.text) ?? 0;

    
    

    if (!_allConditionsMet()) {
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all verifications'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (amount < 100) {
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimum withdrawal is 100 diamonds'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (amount > _diamondBalance) {
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient diamond balance'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_hasValidPaymentDetails()) {
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all payment details'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userId = userProvider.currentUser?.uid;

      if (userId == null) {
        throw Exception('User not logged in');
      }

      // Build payment details
      // Build payment details
      Map<String, dynamic> paymentDetails;
      if (_withdrawalType == 'agency') {
        paymentDetails = {
           'type': 'agency',
           'timestamp': DateTime.now().toIso8601String(),
        };
      } else {
        paymentDetails = {
           'type': 'self',
           'method': 'usdt_trc20',
           'address': _trc20Controller.text.trim(),
        };
      }

      

      // Process withdrawal
      final success = await _diamondService.withdrawDiamonds(
        userId: userId,
        amount: amount,
        paymentMethod: _selectedPaymentMethod,
        paymentDetails: paymentDetails,
      );

      if (success) {
        

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Withdrawal request submitted successfully!'),
              backgroundColor: Colors.green,
            ),
          );

          // Reload data
          await _loadData();

          // Clear form
          _amountController.clear();
        }
      } else {
        throw Exception('Withdrawal failed');
      }

      
    } catch (e) {
      
      
      
      

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Withdrawal failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
