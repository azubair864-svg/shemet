import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// ⭐⭐⭐ HOST EARNINGS DISPLAY WIDGET ⭐⭐⭐
/// Reusable widget for displaying host earnings
/// Shows current earnings, pending withdrawals, earnings history, diamond to cash conversion
class HostEarningsWidget extends StatefulWidget {
  final String hostId;
  final bool showWithdrawButton;
  final bool compact;
  final VoidCallback? onWithdrawTap;
  final VoidCallback? onViewDetailsTap;

  const HostEarningsWidget({
    super.key,
    required this.hostId,
    this.showWithdrawButton = true,
    this.compact = false,
    this.onWithdrawTap,
    this.onViewDetailsTap,
  });

  @override
  State<HostEarningsWidget> createState() => _HostEarningsWidgetState();
}

class _HostEarningsWidgetState extends State<HostEarningsWidget> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  int _currentDiamonds = 0;
  int _pendingWithdrawal = 0;
  int _totalEarned = 0;
  int _totalWithdrawn = 0;

  // Today's earnings
  int _todayEarnings = 0;

  // Recent transactions for preview
  List<Map<String, dynamic>> _recentTransactions = [];

  @override
  void initState() {
    super.initState();
    
    
    
    _loadEarningsData();
  }

  Future<void> _loadEarningsData() async {
    

    setState(() => _isLoading = true);

    try {
      // Step 1: Get current diamond balance
      
      final userDoc = await _firestore.collection('users').doc(widget.hostId).get();
      _currentDiamonds = (userDoc.data()?['diamonds'] as num?)?.toInt() ?? 0;
      

      // Step 2: Get pending withdrawals
      
      final pendingSnapshot = await _firestore
          .collection('withdrawals')
          .where('userId', isEqualTo: widget.hostId)
          .where('status', isEqualTo: 'pending')
          .get();

      _pendingWithdrawal = 0;
      for (var doc in pendingSnapshot.docs) {
        _pendingWithdrawal += (doc.data()['diamonds'] as num?)?.toInt() ?? 0;
      }
      

      // Step 3: Get total withdrawn
      
      final withdrawnSnapshot = await _firestore
          .collection('withdrawals')
          .where('userId', isEqualTo: widget.hostId)
          .where('status', isEqualTo: 'completed')
          .get();

      _totalWithdrawn = 0;
      for (var doc in withdrawnSnapshot.docs) {
        _totalWithdrawn += (doc.data()['diamonds'] as num?)?.toInt() ?? 0;
      }
      

      // Step 4: Calculate total earned
      _totalEarned = _currentDiamonds + _totalWithdrawn;
      

      // Step 5: Get today's earnings
      
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final todaySnapshot = await _firestore
          .collection('users')
          .doc(widget.hostId)
          .collection('diamond_transactions')
          .where('type', whereIn: ['gift_received', 'call_earning', 'live_stream_gift'])
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();

      _todayEarnings = 0;
      for (var doc in todaySnapshot.docs) {
        _todayEarnings += (doc.data()['amount'] as num?)?.toInt() ?? 0;
      }
      

      // Step 6: Get recent transactions
      
      final recentSnapshot = await _firestore
          .collection('users')
          .doc(widget.hostId)
          .collection('diamond_transactions')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      _recentTransactions = recentSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'type': data['type'] ?? 'unknown',
          'amount': data['amount'] ?? 0,
          'senderName': data['senderName'] ?? '',
          'giftName': data['giftName'] ?? '',
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        };
      }).toList();
      

      setState(() => _isLoading = false);

      
    } catch (e) {
      
      
      
      
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    
    
    

    if (_isLoading) {
      return _buildLoadingState();
    }

    if (widget.compact) {
      return _buildCompactView();
    }

    return _buildFullView();
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: Colors.amber),
      ),
    );
  }

  Widget _buildCompactView() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF4834DF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Earnings',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              if (widget.onViewDetailsTap != null)
                GestureDetector(
                  onTap: widget.onViewDetailsTap,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Details',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white.withValues(alpha: 0.8),
                        size: 12,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Diamond balance
          Row(
            children: [
              const Icon(Icons.diamond, color: Colors.amber, size: 28),
              const SizedBox(width: 8),
              Text(
                _formatNumber(_currentDiamonds),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // USD conversion
          Text(
            '≈ \$${(_currentDiamonds / 100).toStringAsFixed(2)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),

          // Today's earnings
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.today, color: Colors.greenAccent, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Today: +${_formatNumber(_todayEarnings)}',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullView() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with gradient
          _buildHeader(),

          // Stats row
          _buildStatsRow(),

          // Pending withdrawal alert (if any)
          if (_pendingWithdrawal > 0) _buildPendingAlert(),

          // Recent transactions
          _buildRecentTransactions(),

          // Withdraw button
          if (widget.showWithdrawButton) _buildWithdrawButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF4834DF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Current Balance',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              if (widget.onViewDetailsTap != null)
                GestureDetector(
                  onTap: widget.onViewDetailsTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View All',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward, color: Colors.white, size: 14),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Main balance
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.diamond, color: Colors.amber, size: 40),
              const SizedBox(width: 12),
              Text(
                NumberFormat('#,###').format(_currentDiamonds),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // USD conversion
          _buildConversionDisplay(),
          const SizedBox(height: 20),

          // Today's earnings highlight
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.trending_up, color: Colors.greenAccent, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Today: +${_formatNumber(_todayEarnings)} diamonds',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversionDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '💵',
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(width: 8),
          Text(
            '\$${NumberFormat('#,###.00').format(_currentDiamonds / 100)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '(100💎 = \$1)',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              'Total Earned',
              _formatNumber(_totalEarned),
              Icons.diamond,
              Colors.amber,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatItem(
              'Withdrawn',
              _formatNumber(_totalWithdrawn),
              Icons.check_circle,
              Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatItem(
              'Pending',
              _formatNumber(_pendingWithdrawal),
              Icons.hourglass_empty,
              Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPendingAlert() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.orange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pending Withdrawal',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatNumber(_pendingWithdrawal)} diamonds being processed',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions() {
    if (_recentTransactions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            'No recent transactions',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activity',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...(_recentTransactions.take(3).map((transaction) {
            return _buildTransactionItem(transaction);
          })),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final type = transaction['type'] as String;
    final amount = transaction['amount'] as int;
    final createdAt = transaction['createdAt'] as DateTime;
    final senderName = transaction['senderName'] as String;

    IconData icon;
    Color color;
    String title;

    switch (type) {
      case 'gift_received':
        icon = Icons.card_giftcard;
        color = Colors.pink;
        title = senderName.isNotEmpty ? 'Gift from $senderName' : 'Gift received';
        break;
      case 'call_earning':
        icon = Icons.phone_in_talk;
        color = Colors.green;
        title = senderName.isNotEmpty ? 'Call with $senderName' : 'Call earning';
        break;
      case 'live_stream_gift':
        icon = Icons.live_tv;
        color = Colors.red;
        title = senderName.isNotEmpty ? 'Stream gift from $senderName' : 'Stream gift';
        break;
      default:
        icon = Icons.diamond;
        color = Colors.amber;
        title = 'Diamond earned';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatTime(createdAt),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '+',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Icon(Icons.diamond, color: Colors.amber, size: 14),
              const SizedBox(width: 2),
              Text(
                _formatNumber(amount),
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawButton() {
    final canWithdraw = _currentDiamonds >= 1000; // Minimum 1000 diamonds to withdraw

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canWithdraw ? widget.onWithdrawTap : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: canWithdraw ? Colors.amber : Colors.grey,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: Colors.grey.withValues(alpha: 0.3),
                disabledForegroundColor: Colors.white54,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    color: canWithdraw ? Colors.black : Colors.white54,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    canWithdraw ? 'Withdraw Diamonds' : 'Min. 1,000 diamonds to withdraw',
                    style: TextStyle(
                      fontSize: canWithdraw ? 16 : 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!canWithdraw)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'You need ${_formatNumber(1000 - _currentDiamonds)} more diamonds',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return NumberFormat('#,###').format(number);
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }
}

/// ⭐ Mini earnings badge for profile cards
class HostEarningsBadge extends StatelessWidget {
  final int diamonds;
  final bool showUsd;

  const HostEarningsBadge({
    super.key,
    required this.diamonds,
    this.showUsd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.diamond, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            _formatNumber(diamonds),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (showUsd) ...[
            const SizedBox(width: 6),
            Text(
              '(\$${(diamonds / 100).toStringAsFixed(0)})',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return NumberFormat('#,###').format(number);
  }
}

/// ⭐ Earnings summary card for dashboard
class HostEarningsSummaryCard extends StatelessWidget {
  final int todayEarnings;
  final int weekEarnings;
  final int monthEarnings;
  final double growthPercentage;
  final VoidCallback? onTap;

  const HostEarningsSummaryCard({
    super.key,
    required this.todayEarnings,
    required this.weekEarnings,
    required this.monthEarnings,
    this.growthPercentage = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPositiveGrowth = growthPercentage >= 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.amber.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.diamond, color: Colors.amber, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Earnings Overview',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isPositiveGrowth ? Colors.green : Colors.red)
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositiveGrowth ? Icons.trending_up : Icons.trending_down,
                        color: isPositiveGrowth ? Colors.green : Colors.red,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${isPositiveGrowth ? '+' : ''}${growthPercentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: isPositiveGrowth ? Colors.green : Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Stats
            Row(
              children: [
                Expanded(
                  child: _buildPeriodStat('Today', todayEarnings, Colors.green),
                ),
                Expanded(
                  child: _buildPeriodStat('This Week', weekEarnings, Colors.blue),
                ),
                Expanded(
                  child: _buildPeriodStat('This Month', monthEarnings, Colors.purple),
                ),
              ],
            ),

            if (onTap != null) ...[
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Tap for details →',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodStat(String label, int value, Color color) {
    return Column(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _formatNumber(value),
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return NumberFormat('#,###').format(number);
  }
}
