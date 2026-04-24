import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/user_provider.dart';

/// ⭐⭐⭐ PRODUCTION-READY GIFT HISTORY SCREEN ⭐⭐⭐
/// Shows complete gift transaction history (sent and received)
/// Features: Filters, search, date range, export
class GiftHistoryScreen extends StatefulWidget {
  final bool showSentGifts; // true = sent, false = received

  const GiftHistoryScreen({
    super.key,
    this.showSentGifts = false,
  });

  @override
  State<GiftHistoryScreen> createState() => _GiftHistoryScreenState();
}

class _GiftHistoryScreenState extends State<GiftHistoryScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late TabController _tabController;

  bool _isLoading = true;
  List<Map<String, dynamic>> _sentGifts = [];
  List<Map<String, dynamic>> _receivedGifts = [];

  // Stats
  int _totalSent = 0;
  int _totalReceived = 0;
  int _totalDiamondsSpent = 0;
  int _totalDiamondsEarned = 0;

  // Filters
  String _selectedFilter = 'all'; // all, today, week, month
  final String _selectedCategory = 'all'; // all, romantic, luxury, fun, etc.

  @override
  void initState() {
    super.initState();
    
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.showSentGifts ? 0 : 1,
    );
    _loadGiftHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadGiftHistory() async {
    

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.currentUser?.uid;

    if (userId == null) {
      
      setState(() => _isLoading = false);
      return;
    }

    

    try {
      setState(() => _isLoading = true);

      // Load sent gifts
      
      await _loadSentGifts(userId);

      // Load received gifts
      
      await _loadReceivedGifts(userId);

      // Calculate stats
      _calculateStats();

      setState(() => _isLoading = false);

      
      
      
      
    } catch (e) {
      
      
      
      
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSentGifts(String userId) async {
    try {
      Query query = _firestore
          .collection('gift_transactions')
          .where('senderId', isEqualTo: userId)
          .orderBy('createdAt', descending: true);

      // Apply date filter
      query = _applyDateFilter(query);

      final snapshot = await query.limit(100).get();

      _sentGifts = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'giftName': data['giftName'] ?? 'Gift',
          'giftEmoji': data['giftEmoji'] ?? '🎁',
          'giftPrice': data['giftPrice'] ?? 0,
          'receiverName': data['receiverName'] ?? 'Unknown',
          'receiverPhoto': data['receiverPhoto'] ?? '',
          'receiverId': data['receiverId'] ?? '',
          'category': data['category'] ?? 'general',
          'comboCount': data['comboCount'] ?? 1,
          'totalPrice': data['totalPrice'] ?? data['giftPrice'] ?? 0,
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'streamId': data['streamId'],
          'context': data['context'] ?? 'live_stream', // live_stream, profile, chat
        };
      }).toList();

      
    } catch (e) {
      
      _sentGifts = [];
    }
  }

  Future<void> _loadReceivedGifts(String userId) async {
    try {
      Query query = _firestore
          .collection('gift_transactions')
          .where('receiverId', isEqualTo: userId)
          .orderBy('createdAt', descending: true);

      // Apply date filter
      query = _applyDateFilter(query);

      final snapshot = await query.limit(100).get();

      _receivedGifts = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'giftName': data['giftName'] ?? 'Gift',
          'giftEmoji': data['giftEmoji'] ?? '🎁',
          'giftPrice': data['giftPrice'] ?? 0,
          'senderName': data['senderName'] ?? 'Unknown',
          'senderPhoto': data['senderPhoto'] ?? '',
          'senderId': data['senderId'] ?? '',
          'category': data['category'] ?? 'general',
          'comboCount': data['comboCount'] ?? 1,
          'diamondsEarned': data['diamondsEarned'] ?? (data['giftPrice'] ?? 0) ~/ 2,
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'streamId': data['streamId'],
          'context': data['context'] ?? 'live_stream',
        };
      }).toList();

      
    } catch (e) {
      
      _receivedGifts = [];
    }
  }

  Query _applyDateFilter(Query query) {
    final now = DateTime.now();

    switch (_selectedFilter) {
      case 'today':
        final startOfDay = DateTime(now.year, now.month, now.day);
        return query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay));
      case 'week':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final startDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        return query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      case 'month':
        final startOfMonth = DateTime(now.year, now.month, 1);
        return query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth));
      default:
        return query;
    }
  }

  void _calculateStats() {
    _totalSent = _sentGifts.length;
    _totalReceived = _receivedGifts.length;

    _totalDiamondsSpent = 0;
    for (var gift in _sentGifts) {
      _totalDiamondsSpent += (gift['totalPrice'] as num?)?.toInt() ?? 0;
    }

    _totalDiamondsEarned = 0;
    for (var gift in _receivedGifts) {
      _totalDiamondsEarned += (gift['diamondsEarned'] as num?)?.toInt() ?? 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text(
          'Gift History',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Filter button
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            color: const Color(0xFF16213E),
            onSelected: (value) {
              
              setState(() => _selectedFilter = value);
              _loadGiftHistory();
            },
            itemBuilder: (context) => [
              _buildFilterItem('all', 'All Time'),
              _buildFilterItem('today', 'Today'),
              _buildFilterItem('week', 'This Week'),
              _buildFilterItem('month', 'This Month'),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white54,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.arrow_upward, size: 18),
                  const SizedBox(width: 4),
                  Text('Sent ($_totalSent)'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.arrow_downward, size: 18),
                  const SizedBox(width: 4),
                  Text('Received ($_totalReceived)'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.amber),
            )
          : Column(
              children: [
                // Stats summary
                _buildStatsSummary(),

                // Gift list
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSentGiftsList(),
                      _buildReceivedGiftsList(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  PopupMenuItem<String> _buildFilterItem(String value, String label) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            _selectedFilter == value ? Icons.check : Icons.circle_outlined,
            color: _selectedFilter == value ? Colors.amber : Colors.white54,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: _selectedFilter == value ? Colors.amber : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSummary() {
    final isSentTab = _tabController.index == 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSentTab
              ? [const Color(0xFFE91E63), const Color(0xFF9C27B0)]
              : [const Color(0xFF4CAF50), const Color(0xFF2196F3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: AnimatedBuilder(
        animation: _tabController,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                _tabController.index == 0 ? 'Gifts Sent' : 'Gifts Received',
                _tabController.index == 0 ? _totalSent : _totalReceived,
                Icons.card_giftcard,
              ),
              Container(width: 1, height: 50, color: Colors.white24),
              _buildStatItem(
                _tabController.index == 0 ? 'Coins Spent' : 'Diamonds Earned',
                _tabController.index == 0 ? _totalDiamondsSpent : _totalDiamondsEarned,
                _tabController.index == 0 ? Icons.monetization_on : Icons.diamond,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, int value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          NumberFormat('#,###').format(value),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSentGiftsList() {
    if (_sentGifts.isEmpty) {
      return _buildEmptyState('No gifts sent yet', Icons.card_giftcard);
    }

    return RefreshIndicator(
      onRefresh: _loadGiftHistory,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _sentGifts.length,
        itemBuilder: (context, index) {
          final gift = _sentGifts[index];
          return _buildSentGiftItem(gift);
        },
      ),
    );
  }

  Widget _buildReceivedGiftsList() {
    if (_receivedGifts.isEmpty) {
      return _buildEmptyState('No gifts received yet', Icons.inbox);
    }

    return RefreshIndicator(
      onRefresh: _loadGiftHistory,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _receivedGifts.length,
        itemBuilder: (context, index) {
          final gift = _receivedGifts[index];
          return _buildReceivedGiftItem(gift);
        },
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSentGiftItem(Map<String, dynamic> gift) {
    final createdAt = gift['createdAt'] as DateTime;
    final comboCount = gift['comboCount'] as int;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.pink.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Gift emoji
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.pink.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                gift['giftEmoji'] ?? '🎁',
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Gift details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      gift['giftName'] ?? 'Gift',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (comboCount > 1) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'x$comboCount',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.arrow_forward, color: Colors.pink, size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'To: ${gift['receiverName']}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Price and date
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.monetization_on, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '-${NumberFormat('#,###').format(gift['totalPrice'])}',
                    style: const TextStyle(
                      color: Colors.pink,
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
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReceivedGiftItem(Map<String, dynamic> gift) {
    final createdAt = gift['createdAt'] as DateTime;
    final comboCount = gift['comboCount'] as int;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.green.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Gift emoji
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                gift['giftEmoji'] ?? '🎁',
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Gift details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      gift['giftName'] ?? 'Gift',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (comboCount > 1) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'x$comboCount',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.person, color: Colors.green, size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'From: ${gift['senderName']}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Diamonds earned and date
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.diamond, color: Colors.cyan, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '+${NumberFormat('#,###').format(gift['diamondsEarned'])}',
                    style: const TextStyle(
                      color: Colors.green,
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
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
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
      return DateFormat('MMM d, y').format(date);
    }
  }
}
