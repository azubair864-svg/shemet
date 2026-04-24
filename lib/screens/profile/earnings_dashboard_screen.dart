import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/user_provider.dart';
import '../../services/diamond_service.dart';
import 'withdrawal_screen.dart';

/// ⭐⭐⭐ PRODUCTION-READY HOST EARNINGS DASHBOARD ⭐⭐⭐
/// Comprehensive earnings overview for hosts
/// Features: Total earnings, breakdown by source, charts, history
class EarningsDashboardScreen extends StatefulWidget {
  const EarningsDashboardScreen({super.key});

  @override
  State<EarningsDashboardScreen> createState() => _EarningsDashboardScreenState();
}

class _EarningsDashboardScreenState extends State<EarningsDashboardScreen>
    with SingleTickerProviderStateMixin {
  final DiamondService _diamondService = DiamondService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late TabController _tabController;

  bool _isLoading = true;
  int _totalDiamonds = 0;
  int _totalEarningsUSD = 0;
  int _pendingWithdrawal = 0;
  int _withdrawnTotal = 0;

  // Earnings breakdown
  int _giftEarnings = 0;
  int _callEarnings = 0;
  int _liveStreamEarnings = 0;
  int _otherEarnings = 0;

  // Period stats
  int _todayEarnings = 0;
  int _weekEarnings = 0;
  int _monthEarnings = 0;

  // Transaction history
  List<Map<String, dynamic>> _recentTransactions = [];

  // Time period filter
  final String _selectedPeriod = 'all';

  @override
  void initState() {
    super.initState();
    
    _tabController = TabController(length: 3, vsync: this);
    _loadEarningsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEarningsData() async {
    

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.currentUser?.uid;

    if (userId == null) {
      
      setState(() => _isLoading = false);
      return;
    }

    

    try {
      setState(() => _isLoading = true);

      // Step 1: Get total diamond balance
      
      _totalDiamonds = await _diamondService.getDiamondBalance(userId);
      

      // Step 2: Get earnings breakdown
      
      await _loadEarningsBreakdown(userId);

      // Step 3: Get withdrawal stats
      
      await _loadWithdrawalStats(userId);

      // Step 4: Get period earnings
      
      await _loadPeriodEarnings(userId);

      // Step 5: Get recent transactions
      
      await _loadRecentTransactions(userId);

      // Calculate total USD (100 diamonds = $1)
      _totalEarningsUSD = (_totalDiamonds + _withdrawnTotal) ~/ 100;

      setState(() => _isLoading = false);

      
      
      
      
      
      
      
      
    } catch (e) {
      
      
      
      
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadEarningsBreakdown(String userId) async {
    

    try {
      final earningsRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('diamond_transactions');

      // Gift earnings
      final giftSnapshot = await earningsRef
          .where('type', isEqualTo: 'gift_received')
          .get();

      _giftEarnings = 0;
      for (var doc in giftSnapshot.docs) {
        _giftEarnings += (doc.data()['amount'] as num?)?.toInt() ?? 0;
      }
      

      // Call earnings
      final callSnapshot = await earningsRef
          .where('type', isEqualTo: 'call_earning')
          .get();

      _callEarnings = 0;
      for (var doc in callSnapshot.docs) {
        _callEarnings += (doc.data()['amount'] as num?)?.toInt() ?? 0;
      }
      

      // Live stream earnings (tips during streams)
      final liveSnapshot = await earningsRef
          .where('type', isEqualTo: 'live_stream_gift')
          .get();

      _liveStreamEarnings = 0;
      for (var doc in liveSnapshot.docs) {
        _liveStreamEarnings += (doc.data()['amount'] as num?)?.toInt() ?? 0;
      }
      

      // Other earnings
      _otherEarnings = _totalDiamonds - _giftEarnings - _callEarnings - _liveStreamEarnings;
      if (_otherEarnings < 0) _otherEarnings = 0;
      
    } catch (e) {
      
    }
  }

  Future<void> _loadWithdrawalStats(String userId) async {
    

    try {
      final withdrawalsRef = _firestore
          .collection('withdrawals')
          .where('userId', isEqualTo: userId);

      // Pending withdrawals
      final pendingSnapshot = await withdrawalsRef
          .where('status', isEqualTo: 'pending')
          .get();

      _pendingWithdrawal = 0;
      for (var doc in pendingSnapshot.docs) {
        _pendingWithdrawal += (doc.data()['diamonds'] as num?)?.toInt() ?? 0;
      }
      

      // Completed withdrawals
      final completedSnapshot = await withdrawalsRef
          .where('status', isEqualTo: 'completed')
          .get();

      _withdrawnTotal = 0;
      for (var doc in completedSnapshot.docs) {
        _withdrawnTotal += (doc.data()['diamonds'] as num?)?.toInt() ?? 0;
      }
      
    } catch (e) {
      
    }
  }

  Future<void> _loadPeriodEarnings(String userId) async {
    

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final startOfWeek = startOfDay.subtract(Duration(days: now.weekday - 1));
      final startOfMonth = DateTime(now.year, now.month, 1);

      final earningsRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('diamond_transactions')
          .where('type', whereIn: ['gift_received', 'call_earning', 'live_stream_gift']);

      // Today's earnings
      final todaySnapshot = await earningsRef
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();

      _todayEarnings = 0;
      for (var doc in todaySnapshot.docs) {
        _todayEarnings += (doc.data()['amount'] as num?)?.toInt() ?? 0;
      }
      

      // Week earnings
      final weekSnapshot = await earningsRef
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
          .get();

      _weekEarnings = 0;
      for (var doc in weekSnapshot.docs) {
        _weekEarnings += (doc.data()['amount'] as num?)?.toInt() ?? 0;
      }
      

      // Month earnings
      final monthSnapshot = await earningsRef
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .get();

      _monthEarnings = 0;
      for (var doc in monthSnapshot.docs) {
        _monthEarnings += (doc.data()['amount'] as num?)?.toInt() ?? 0;
      }
      
    } catch (e) {
      
    }
  }

  Future<void> _loadRecentTransactions(String userId) async {
    

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('diamond_transactions')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      _recentTransactions = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'type': data['type'] ?? 'unknown',
          'amount': data['amount'] ?? 0,
          'description': data['description'] ?? '',
          'senderName': data['senderName'] ?? '',
          'giftName': data['giftName'] ?? '',
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        };
      }).toList();

      
    } catch (e) {
      
    }
  }

  @override
  Widget build(BuildContext context) {
    

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text(
          'Earnings Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadEarningsData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Breakdown'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.amber),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildBreakdownTab(),
                _buildHistoryTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    

    return RefreshIndicator(
      onRefresh: _loadEarningsData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main earnings card
            _buildMainEarningsCard(),
            const SizedBox(height: 20),

            // Quick stats
            _buildQuickStats(),
            const SizedBox(height: 20),

            // Period earnings
            _buildPeriodEarnings(),
            const SizedBox(height: 20),

            // Withdrawal button
            _buildWithdrawButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildMainEarningsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF4834DF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Total Balance',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.diamond, color: Colors.amber, size: 36),
              const SizedBox(width: 8),
              Text(
                NumberFormat('#,###').format(_totalDiamonds),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '≈ \$${NumberFormat('#,###.00').format(_totalDiamonds / 100)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatColumn('Pending', _pendingWithdrawal, Icons.hourglass_empty),
              Container(
                width: 1,
                height: 40,
                color: Colors.white24,
              ),
              _buildStatColumn('Withdrawn', _withdrawnTotal, Icons.check_circle),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, int value, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(width: 4),
            Text(
              NumberFormat('#,###').format(value),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Earned',
            _totalDiamonds + _withdrawnTotal,
            Icons.trending_up,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'USD Value',
            _totalEarningsUSD,
            Icons.attach_money,
            Colors.amber,
            prefix: '\$',
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, int value, IconData icon, Color color, {String prefix = ''}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$prefix${NumberFormat('#,###').format(value)}',
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodEarnings() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Earnings by Period',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildPeriodRow('Today', _todayEarnings, Colors.green),
          const SizedBox(height: 12),
          _buildPeriodRow('This Week', _weekEarnings, Colors.blue),
          const SizedBox(height: 12),
          _buildPeriodRow('This Month', _monthEarnings, Colors.purple),
        ],
      ),
    );
  }

  Widget _buildPeriodRow(String label, int value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 16,
              ),
            ),
          ],
        ),
        Row(
          children: [
            const Icon(Icons.diamond, color: Colors.amber, size: 16),
            const SizedBox(width: 4),
            Text(
              NumberFormat('#,###').format(value),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWithdrawButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const WithdrawalScreen()),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amber,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet),
            SizedBox(width: 8),
            Text(
              'Withdraw Diamonds',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownTab() {
    

    final total = _giftEarnings + _callEarnings + _liveStreamEarnings + _otherEarnings;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Pie chart representation
          _buildEarningsChart(total),
          const SizedBox(height: 24),

          // Breakdown list
          _buildBreakdownItem(
            'Gift Earnings',
            _giftEarnings,
            total,
            Icons.card_giftcard,
            Colors.pink,
          ),
          const SizedBox(height: 12),
          _buildBreakdownItem(
            'Call Earnings',
            _callEarnings,
            total,
            Icons.phone_in_talk,
            Colors.green,
          ),
          const SizedBox(height: 12),
          _buildBreakdownItem(
            'Live Stream Tips',
            _liveStreamEarnings,
            total,
            Icons.live_tv,
            Colors.red,
          ),
          const SizedBox(height: 12),
          _buildBreakdownItem(
            'Other',
            _otherEarnings,
            total,
            Icons.more_horiz,
            Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsChart(int total) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text(
            'Earnings Distribution',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Simple circular representation
                CustomPaint(
                  size: const Size(180, 180),
                  painter: _EarningsChartPainter(
                    giftPercentage: total > 0 ? _giftEarnings / total : 0.25,
                    callPercentage: total > 0 ? _callEarnings / total : 0.25,
                    livePercentage: total > 0 ? _liveStreamEarnings / total : 0.25,
                    otherPercentage: total > 0 ? _otherEarnings / total : 0.25,
                  ),
                ),
                // Center text
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.diamond, color: Colors.amber, size: 32),
                    const SizedBox(height: 4),
                    Text(
                      NumberFormat('#,###').format(total),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Total Earned',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownItem(
    String label,
    int amount,
    int total,
    IconData icon,
    Color color,
  ) {
    final percentage = total > 0 ? (amount / total * 100).toStringAsFixed(1) : '0.0';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: total > 0 ? amount / total : 0,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.diamond, color: Colors.amber, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    NumberFormat('#,###').format(amount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                '$percentage%',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    

    if (_recentTransactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No transaction history',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEarningsData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _recentTransactions.length,
        itemBuilder: (context, index) {
          final transaction = _recentTransactions[index];
          return _buildTransactionItem(transaction);
        },
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final type = transaction['type'] as String;
    final amount = transaction['amount'] as int;
    final createdAt = transaction['createdAt'] as DateTime;
    final senderName = transaction['senderName'] as String;
    final giftName = transaction['giftName'] as String;

    IconData icon;
    Color color;
    String title;
    String subtitle;

    switch (type) {
      case 'gift_received':
        icon = Icons.card_giftcard;
        color = Colors.pink;
        title = 'Gift Received';
        subtitle = giftName.isNotEmpty ? '$giftName from $senderName' : 'From $senderName';
        break;
      case 'call_earning':
        icon = Icons.phone_in_talk;
        color = Colors.green;
        title = 'Call Earning';
        subtitle = senderName.isNotEmpty ? 'Call with $senderName' : 'Video/Voice call';
        break;
      case 'live_stream_gift':
        icon = Icons.live_tv;
        color = Colors.red;
        title = 'Live Stream Gift';
        subtitle = giftName.isNotEmpty ? '$giftName from $senderName' : 'During live stream';
        break;
      case 'withdrawal':
        icon = Icons.account_balance_wallet;
        color = Colors.orange;
        title = 'Withdrawal';
        subtitle = 'To bank account';
        break;
      default:
        icon = Icons.diamond;
        color = Colors.amber;
        title = 'Diamond Transaction';
        subtitle = transaction['description'] ?? '';
    }

    final isPositive = type != 'withdrawal';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isPositive ? '+' : '-',
                    style: TextStyle(
                      color: isPositive ? Colors.green : Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Icon(Icons.diamond, color: Colors.amber, size: 14),
                  const SizedBox(width: 2),
                  Text(
                    NumberFormat('#,###').format(amount.abs()),
                    style: TextStyle(
                      color: isPositive ? Colors.green : Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _formatDate(createdAt),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
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

/// Custom painter for earnings distribution chart
class _EarningsChartPainter extends CustomPainter {
  final double giftPercentage;
  final double callPercentage;
  final double livePercentage;
  final double otherPercentage;

  _EarningsChartPainter({
    required this.giftPercentage,
    required this.callPercentage,
    required this.livePercentage,
    required this.otherPercentage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = 24.0;
    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    double startAngle = -1.5708; // Start from top (-90 degrees in radians)

    // Gift earnings (pink)
    if (giftPercentage > 0) {
      paint.color = Colors.pink;
      final sweepAngle = giftPercentage * 6.2832; // 2 * pi
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }

    // Call earnings (green)
    if (callPercentage > 0) {
      paint.color = Colors.green;
      final sweepAngle = callPercentage * 6.2832;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }

    // Live stream earnings (red)
    if (livePercentage > 0) {
      paint.color = Colors.red;
      final sweepAngle = livePercentage * 6.2832;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }

    // Other earnings (grey)
    if (otherPercentage > 0) {
      paint.color = Colors.grey;
      final sweepAngle = otherPercentage * 6.2832;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
