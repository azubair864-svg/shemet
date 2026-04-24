import 'package:flutter/material.dart';
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/diamond_service.dart';
import 'refund_request_screen.dart';

/// ⭐⭐⭐ PRODUCTION-READY PAYMENT HISTORY SCREEN ⭐⭐⭐
/// Shows all payment transactions with filtering and details
/// Features: Transaction list, filters, stats summary, refund requests
class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen>
    with SingleTickerProviderStateMixin {
  final DiamondService _diamondService = DiamondService();
  late TabController _tabController;

  List<Map<String, dynamic>> _allPayments = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _enableScreenshotProtection();
    _tabController = TabController(length: 3, vsync: this);
    _loadPaymentHistory();
  }

  Future<void> _enableScreenshotProtection() async {
    await FlutterWindowManagerPlus.addFlags(FlutterWindowManagerPlus.FLAG_SECURE);
  }

  @override
  void dispose() {
    _disableScreenshotProtection();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _disableScreenshotProtection() async {
    await FlutterWindowManagerPlus.clearFlags(FlutterWindowManagerPlus.FLAG_SECURE);
  }

  Future<void> _loadPaymentHistory() async {
    
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        
        setState(() => _isLoading = false);
        return;
      }

      // Load purchase transactions from DiamondService
      final transactions = await _diamondService.getDiamondTransactions(
        userId: user.uid,
        type: 'purchase',
      );
      

      // Convert to format expected by UI
      final payments = transactions.map((t) => {
        'id': t['id'],
        'status': t['status'] ?? 'completed',
        'amount': ((t['priceValue'] ?? t['price']) as num?)?.toDouble() ?? 0.0,
        'priceLabel': t['priceLabel'],
        'currencyCode': t['currencyCode'],
        'diamonds': t['amount'] ?? 0,
        'bonus': t['bonus'] ?? 0,
        'packageName': t['packageName'] ?? t['productId'] ?? 'Diamond Purchase',
        'paymentMethod': t['paymentMethod'] ?? 'Google Play',
        'transactionId': t['transactionId'] ?? t['id'],
        'productId': t['productId'],
        'source': t['source'],
        'createdAt': t['timestamp'],
      }).toList();

      // Calculate stats
      int completedCount = payments.length; 
      int totalDiamonds = 0;

      for (var p in payments) {
         totalDiamonds += (p['diamonds'] as int);
      }

      setState(() {
        _allPayments = payments;
        _stats = {
          'totalPurchases': payments.length,
          'totalDiamonds': totalDiamonds,
          'completedCount': completedCount,
          'pendingCount': 0,
          'refundedCount': 0,
        };
        _isLoading = false;
      });
    } catch (e) {
      
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _paymentsForTab(String tab) {
    Iterable<Map<String, dynamic>> payments = _allPayments;

    if (tab == 'completed') {
      payments = payments.where((p) => p['status'] == 'completed');
    } else if (tab == 'refunded') {
      payments = payments.where(
        (p) => p['status'] == 'refunded' || p['status'] == 'refund_requested',
      );
    }

    if (_selectedFilter != 'all') {
      payments = payments.where((p) => p['status'] == _selectedFilter);
    }

    return payments.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F23),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          'Payment History',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.blue.withValues(alpha: 0.35),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.shop_2_outlined,
                  color: Colors.blue,
                  size: 10,
                ),
                SizedBox(width: 6),
                Text(
                  'GOOGLE PLAY',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Completed'),
            Tab(text: 'Refunded'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : RefreshIndicator(
              onRefresh: _loadPaymentHistory,
              child: Column(
                children: [
                  // Stats summary
                  _buildStatsSummary(),

                  // Filter chips
                  _buildFilterChips(),

                  // Payments list
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPaymentsList(_paymentsForTab('all')),
                        _buildPaymentsList(_paymentsForTab('completed')),
                        _buildPaymentsList(_paymentsForTab('refunded')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsSummary() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D2D44), Color(0xFF1E1E32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem(
                icon: Icons.receipt_long,
                label: 'Total Purchases',
                value: '${_stats['totalPurchases'] ?? 0}',
                color: Colors.blue,
              ),
              _statItem(
                icon: Icons.diamond_outlined,
                label: 'Diamonds Bought',
                value: '${_stats['totalDiamonds'] ?? 0}',
                color: Colors.blueAccent,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _miniStat('Total Purchases', _stats['totalPurchases'] ?? 0, Colors.blue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
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

  Widget _miniStat(String label, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: $count',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      {'id': 'all', 'label': 'All', 'icon': Icons.list},
      {'id': 'completed', 'label': 'Completed', 'icon': Icons.check_circle},
      {'id': 'pending', 'label': 'Pending', 'icon': Icons.hourglass_empty},
      {'id': 'refunded', 'label': 'Refunded', 'icon': Icons.replay},
    ];

    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter['id'];

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    filter['icon'] as IconData,
                    size: 16,
                    color: isSelected ? Colors.black : Colors.white70,
                  ),
                  const SizedBox(width: 6),
                  Text(filter['label'] as String),
                ],
              ),
              onSelected: (selected) {
                
                setState(() => _selectedFilter = filter['id'] as String);
              },
              backgroundColor: const Color(0xFF16213E),
              selectedColor: Colors.amber,
              labelStyle: TextStyle(
                color: isSelected ? Colors.black : Colors.white70,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? Colors.amber : Colors.white24,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentsList(List<Map<String, dynamic>> payments) {
    if (payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 80,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No payments found',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your payment history will appear here',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: payments.length,
      itemBuilder: (context, index) {
        final payment = payments[index];
        return _buildPaymentCard(payment);
      },
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final status = payment['status'] ?? 'unknown';
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);
    final amountLabel = _displayAmountLabel(payment);
    final diamonds = payment['diamonds'] ?? 0;
    final date = payment['createdAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(
            payment['createdAt'].millisecondsSinceEpoch)
        : DateTime.now();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showPaymentDetails(payment),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    // Icon
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(statusIcon, color: statusColor, size: 24),
                    ),
                    const SizedBox(width: 12),

                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            payment['packageName'] ?? 'Coin Purchase',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDate(date),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Amount and coins
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const SizedBox(height: 12),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.diamond,
                                color: Colors.blueAccent, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '+$diamonds',
                              style: const TextStyle(
                                color: Colors.blueAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 12),

                // Status row
                Row(
                  children: [
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, color: statusColor, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            _formatStatus(status),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),

                    // Payment ID
                    Text(
                      'ID: ${_truncateId(payment['id'] ?? '')}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      case 'refunded':
        return Colors.blue;
      case 'refund_requested':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle;
      case 'pending':
        return Icons.hourglass_empty;
      case 'failed':
        return Icons.cancel;
      case 'refunded':
        return Icons.replay;
      case 'refund_requested':
        return Icons.hourglass_top;
      default:
        return Icons.help_outline;
    }
  }

  String _formatStatus(String status) {
    return status
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _truncateId(String id) {
    if (id.length <= 8) return id;
    return '${id.substring(0, 8)}...';
  }

  void _showPaymentDetails(Map<String, dynamic> payment) {
    
    
    
    

    final status = payment['status'] ?? 'unknown';
    final statusColor = _getStatusColor(status);
    final amountLabel = _displayAmountLabel(payment);
    final diamonds = payment['diamonds'] ?? 0;
    final bonus = payment['bonus'] ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(_getStatusIcon(status),
                                color: statusColor, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  payment['packageName'] ?? 'Diamond Purchase',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _formatStatus(status),
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white54),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Amount card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16213E),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            const SizedBox.shrink(),
                            const SizedBox.shrink(),
                            Column(
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.diamond,
                                        color: Colors.blueAccent, size: 24),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${diamonds + bonus}',
                                      style: const TextStyle(
                                        color: Colors.blueAccent,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Diamonds',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Transaction details
                      _detailSection('Transaction Details', [
                        _detailRow('Payment ID', payment['id'] ?? 'N/A'),
                        _detailRow('Date', payment['createdAt'] != null
                            ? _formatFullDate(DateTime.fromMillisecondsSinceEpoch(
                                payment['createdAt'].millisecondsSinceEpoch))
                            : 'N/A'),
                        _detailRow(
                          'Payment Method',
                          _formatPaymentMethod(
                            payment['paymentMethod'] as String?,
                          ),
                        ),
                        _detailRow('Transaction ID', payment['transactionId'] ?? 'N/A'),
                        if ((payment['productId'] as String?)?.isNotEmpty == true)
                          _detailRow('Product ID', payment['productId'] as String),
                      ]),
                      const SizedBox(height: 20),

                      // Purchase breakdown
                      _detailSection('Purchase Breakdown', [
                        _detailRow('Base Diamonds', '$diamonds'),
                        if (bonus > 0) _detailRow('Bonus Diamonds', '+$bonus', valueColor: Colors.green),
                        _detailRow('Total Diamonds', '${diamonds + bonus}', isBold: true, valueColor: Colors.blueAccent),
                      ]),
                      const SizedBox(height: 24),

                      // Actions
                      if (status == 'completed') ...[
                        // Refund button (if eligible)
                        _buildRefundButton(payment),
                        const SizedBox(height: 12),
                      ],

                      // Download receipt
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            
                            // Download receipt
                          },
                          icon: const Icon(Icons.download),
                          label: const Text('Download Receipt'),
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
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRefundButton(Map<String, dynamic> payment) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _requestRefund(payment),
        icon: const Icon(Icons.replay),
        label: const Text('Open Google Play Refund Options'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Future<void> _requestRefund(Map<String, dynamic> payment) async {
    
    

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Request Refund?',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'We will open Google Play order history so you can request the refund there.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Google Play decides refund eligibility and handles the final refund result.',
                      style: TextStyle(
                        color: Colors.orange.shade200,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Open Google Play'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RefundRequestScreen(paymentId: payment['id']),
          ),
        );
      }
    }

    
  }

  Widget _detailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value,
      {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatFullDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _displayAmountLabel(Map<String, dynamic> payment) {
    final priceLabel = payment['priceLabel'] as String?;
    if (priceLabel != null && priceLabel.trim().isNotEmpty) {
      return priceLabel;
    }

    final amount = ((payment['amount'] ?? 0.0) as num).toDouble();
    final currencyCode = payment['currencyCode'] as String?;
    if (currencyCode != null && currencyCode.trim().isNotEmpty) {
      return '$currencyCode ${amount.toStringAsFixed(2)}';
    }
    return amount.toStringAsFixed(2);
  }

  String _buildTotalSpentLabel(
    List<Map<String, dynamic>> payments,
    double totalSpent,
  ) {
    final currencyCodes = payments
        .map((payment) => (payment['currencyCode'] as String?)?.trim() ?? '')
        .where((code) => code.isNotEmpty)
        .toSet();

    if (currencyCodes.length == 1) {
      return '${currencyCodes.first} ${totalSpent.toStringAsFixed(2)}';
    }

    return totalSpent.toStringAsFixed(2);
  }

  String _formatPaymentMethod(String? paymentMethod) {
    if (paymentMethod == null || paymentMethod.isEmpty) {
      return 'Google Play';
    }

    return paymentMethod
        .split('_')
        .map((segment) {
          if (segment.isEmpty) {
            return segment;
          }
          return segment[0].toUpperCase() + segment.substring(1);
        })
        .join(' ');
  }
}
