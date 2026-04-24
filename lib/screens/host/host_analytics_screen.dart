import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

/// ⭐⭐⭐ PRODUCTION-READY HOST ANALYTICS SCREEN ⭐⭐⭐
/// Comprehensive analytics for hosts with daily/weekly/monthly stats,
/// viewer analytics, gift breakdown, performance graphs, top supporters
class HostAnalyticsScreen extends StatefulWidget {
  const HostAnalyticsScreen({super.key});

  @override
  State<HostAnalyticsScreen> createState() => _HostAnalyticsScreenState();
}

class _HostAnalyticsScreenState extends State<HostAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  late TabController _tabController;

  bool _isLoading = true;
  String _selectedPeriod = 'week'; // 'day', 'week', 'month', 'all'

  // Earnings data
  int _totalDiamonds = 0;
  int _periodDiamonds = 0;
  double _diamondGrowth = 0;

  // Viewer data
  int _totalViewers = 0;
  int _periodViewers = 0;
  int _uniqueViewers = 0;
  double _viewerGrowth = 0;
  double _avgWatchTime = 0;

  // Stream data
  int _totalStreams = 0;
  int _periodStreams = 0;
  int _totalStreamMinutes = 0;
  double _avgStreamDuration = 0;

  // Gift breakdown
  Map<String, int> _giftBreakdown = {};
  List<Map<String, dynamic>> _topGifts = [];

  // Top supporters
  List<Map<String, dynamic>> _topSupporters = [];

  // Performance data for charts
  List<Map<String, dynamic>> _dailyEarnings = [];
  List<Map<String, dynamic>> _dailyViewers = [];

  // Peak times analysis
  Map<int, int> _peakHours = {};
  Map<int, int> _peakDays = {};

  @override
  void initState() {
    super.initState();
    
    

    _tabController = TabController(length: 4, vsync: this);
    _loadAnalyticsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalyticsData() async {
    
    

    setState(() => _isLoading = true);

    try {
      // Get period date range
      final now = DateTime.now();
      DateTime startDate;

      switch (_selectedPeriod) {
        case 'day':
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 'week':
          startDate = now.subtract(const Duration(days: 7));
          break;
        case 'month':
          startDate = DateTime(now.year, now.month - 1, now.day);
          break;
        default:
          startDate = DateTime(2020); // All time
      }

      

      // Load all data in parallel
      await Future.wait([
        _loadEarningsData(startDate),
        _loadViewerData(startDate),
        _loadStreamData(startDate),
        _loadGiftBreakdown(startDate),
        _loadTopSupporters(startDate),
        _loadDailyData(startDate),
        _loadPeakAnalysis(),
      ]);

      setState(() => _isLoading = false);

      
      
      
      
      
    } catch (e) {
      
      
      
      
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadEarningsData(DateTime startDate) async {
    

    try {
      // Get total diamonds
      final userDoc = await _firestore.collection('users').doc(_currentUserId).get();
      _totalDiamonds = (userDoc.data()?['diamonds'] as num?)?.toInt() ?? 0;

      // Get period earnings
      final earningsSnapshot = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('diamond_transactions')
          .where('type', whereIn: ['gift_received', 'call_earning', 'live_stream_gift'])
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();

      _periodDiamonds = 0;
      for (var doc in earningsSnapshot.docs) {
        _periodDiamonds += (doc.data()['amount'] as num?)?.toInt() ?? 0;
      }

      // Calculate growth (compare to previous period)
      final previousStart = startDate.subtract(startDate.difference(DateTime.now()).abs());
      final previousSnapshot = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('diamond_transactions')
          .where('type', whereIn: ['gift_received', 'call_earning', 'live_stream_gift'])
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(previousStart))
          .where('createdAt', isLessThan: Timestamp.fromDate(startDate))
          .get();

      int previousEarnings = 0;
      for (var doc in previousSnapshot.docs) {
        previousEarnings += (doc.data()['amount'] as num?)?.toInt() ?? 0;
      }

      _diamondGrowth = previousEarnings > 0
          ? ((_periodDiamonds - previousEarnings) / previousEarnings * 100)
          : 0;

      
      
      
    } catch (e) {
      
    }
  }

  Future<void> _loadViewerData(DateTime startDate) async {
    

    try {
      // Get stream viewer stats
      final streamsSnapshot = await _firestore
          .collection('live_streams')
          .where('hostId', isEqualTo: _currentUserId)
          .where('startedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();

      _totalViewers = 0;
      _periodViewers = 0;
      Set<String> uniqueViewerIds = {};
      int totalWatchMinutes = 0;

      for (var doc in streamsSnapshot.docs) {
        final data = doc.data();
        _periodViewers += (data['totalViewers'] as num?)?.toInt() ?? 0;
        _totalViewers += (data['peakViewers'] as num?)?.toInt() ?? 0;
        totalWatchMinutes += (data['totalWatchMinutes'] as num?)?.toInt() ?? 0;

        // Get unique viewers from sub-collection
        final viewersSnapshot = await _firestore
            .collection('live_streams')
            .doc(doc.id)
            .collection('viewers')
            .get();

        for (var viewer in viewersSnapshot.docs) {
          uniqueViewerIds.add(viewer.id);
        }
      }

      _uniqueViewers = uniqueViewerIds.length;
      _avgWatchTime = _periodViewers > 0 ? totalWatchMinutes / _periodViewers : 0;

      // Calculate viewer growth
      final previousStart = startDate.subtract(startDate.difference(DateTime.now()).abs());
      final previousSnapshot = await _firestore
          .collection('live_streams')
          .where('hostId', isEqualTo: _currentUserId)
          .where('startedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(previousStart))
          .where('startedAt', isLessThan: Timestamp.fromDate(startDate))
          .get();

      int previousViewers = 0;
      for (var doc in previousSnapshot.docs) {
        previousViewers += (doc.data()['totalViewers'] as num?)?.toInt() ?? 0;
      }

      _viewerGrowth = previousViewers > 0
          ? ((_periodViewers - previousViewers) / previousViewers * 100)
          : 0;

      
      
      
      
    } catch (e) {
      
    }
  }

  Future<void> _loadStreamData(DateTime startDate) async {
    

    try {
      // Get total streams
      final allStreamsSnapshot = await _firestore
          .collection('live_streams')
          .where('hostId', isEqualTo: _currentUserId)
          .get();

      _totalStreams = allStreamsSnapshot.docs.length;

      // Get period streams
      final periodStreamsSnapshot = await _firestore
          .collection('live_streams')
          .where('hostId', isEqualTo: _currentUserId)
          .where('startedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();

      _periodStreams = periodStreamsSnapshot.docs.length;
      _totalStreamMinutes = 0;

      for (var doc in periodStreamsSnapshot.docs) {
        _totalStreamMinutes += (doc.data()['durationMinutes'] as num?)?.toInt() ?? 0;
      }

      _avgStreamDuration = _periodStreams > 0 ? _totalStreamMinutes / _periodStreams : 0;

      
      
      
      
    } catch (e) {
      
    }
  }

  Future<void> _loadGiftBreakdown(DateTime startDate) async {
    

    try {
      final giftsSnapshot = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('diamond_transactions')
          .where('type', whereIn: ['gift_received', 'live_stream_gift'])
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();

      _giftBreakdown = {};
      Map<String, Map<String, dynamic>> giftDetails = {};

      for (var doc in giftsSnapshot.docs) {
        final data = doc.data();
        final giftName = data['giftName'] as String? ?? 'Unknown';
        final amount = (data['amount'] as num?)?.toInt() ?? 0;

        _giftBreakdown[giftName] = (_giftBreakdown[giftName] ?? 0) + amount;

        if (!giftDetails.containsKey(giftName)) {
          giftDetails[giftName] = {
            'name': giftName,
            'count': 0,
            'diamonds': 0,
            'icon': data['giftIcon'] ?? '🎁',
          };
        }
        giftDetails[giftName]!['count'] = (giftDetails[giftName]!['count'] as int) + 1;
        giftDetails[giftName]!['diamonds'] = (giftDetails[giftName]!['diamonds'] as int) + amount;
      }

      // Sort by diamonds and get top gifts
      _topGifts = giftDetails.values.toList()
        ..sort((a, b) => (b['diamonds'] as int).compareTo(a['diamonds'] as int));

      _topGifts = _topGifts.take(10).toList();

      
      
    } catch (e) {
      
    }
  }

  Future<void> _loadTopSupporters(DateTime startDate) async {
    

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('gift_senders')
          .orderBy('totalDiamonds', descending: true)
          .limit(10)
          .get();

      _topSupporters = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final senderId = doc.id;

        // Get sender info
        final senderDoc = await _firestore.collection('users').doc(senderId).get();
        final senderData = senderDoc.data();

        _topSupporters.add({
          'id': senderId,
          'name': senderData?['name'] ?? 'Unknown',
          'photoUrl': senderData?['photoURL'],
          'totalDiamonds': data['totalDiamonds'] ?? 0,
          'giftCount': data['giftCount'] ?? 0,
          'level': senderData?['level'] ?? 1,
          'isVip': senderData?['isVip'] ?? false,
          'lastGiftAt': (data['lastGiftAt'] as Timestamp?)?.toDate(),
        });
      }

      
    } catch (e) {
      
    }
  }

  Future<void> _loadDailyData(DateTime startDate) async {
    

    try {
      _dailyEarnings = [];
      _dailyViewers = [];

      // Get number of days to display
      final dayCount = DateTime.now().difference(startDate).inDays + 1;
      final daysToShow = dayCount > 30 ? 30 : dayCount;

      for (int i = 0; i < daysToShow; i++) {
        final date = DateTime.now().subtract(Duration(days: daysToShow - 1 - i));
        final dayStart = DateTime(date.year, date.month, date.day);
        final dayEnd = dayStart.add(const Duration(days: 1));

        // Get earnings for this day
        final earningsSnapshot = await _firestore
            .collection('users')
            .doc(_currentUserId)
            .collection('diamond_transactions')
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
            .where('createdAt', isLessThan: Timestamp.fromDate(dayEnd))
            .get();

        int dayEarnings = 0;
        for (var doc in earningsSnapshot.docs) {
          dayEarnings += (doc.data()['amount'] as num?)?.toInt() ?? 0;
        }

        _dailyEarnings.add({
          'date': date,
          'value': dayEarnings,
        });

        // Get viewers for this day
        final viewersSnapshot = await _firestore
            .collection('live_streams')
            .where('hostId', isEqualTo: _currentUserId)
            .where('startedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
            .where('startedAt', isLessThan: Timestamp.fromDate(dayEnd))
            .get();

        int dayViewers = 0;
        for (var doc in viewersSnapshot.docs) {
          dayViewers += (doc.data()['totalViewers'] as num?)?.toInt() ?? 0;
        }

        _dailyViewers.add({
          'date': date,
          'value': dayViewers,
        });
      }

      
    } catch (e) {
      
    }
  }

  Future<void> _loadPeakAnalysis() async {
    

    try {
      _peakHours = {};
      _peakDays = {};

      final streamsSnapshot = await _firestore
          .collection('live_streams')
          .where('hostId', isEqualTo: _currentUserId)
          .orderBy('startedAt', descending: true)
          .limit(100)
          .get();

      for (var doc in streamsSnapshot.docs) {
        final data = doc.data();
        final startedAt = (data['startedAt'] as Timestamp?)?.toDate();
        final viewers = (data['peakViewers'] as num?)?.toInt() ?? 0;

        if (startedAt != null) {
          final hour = startedAt.hour;
          final weekday = startedAt.weekday;

          _peakHours[hour] = (_peakHours[hour] ?? 0) + viewers;
          _peakDays[weekday] = (_peakDays[weekday] ?? 0) + viewers;
        }
      }

      
      
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
          'Analytics',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadAnalyticsData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white54,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Earnings'),
            Tab(text: 'Viewers'),
            Tab(text: 'Performance'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.amber),
            )
          : Column(
              children: [
                // Period selector
                _buildPeriodSelector(),

                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(),
                      _buildEarningsTab(),
                      _buildViewersTab(),
                      _buildPerformanceTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF16213E),
      ),
      child: Row(
        children: [
          _buildPeriodChip('Today', 'day'),
          const SizedBox(width: 8),
          _buildPeriodChip('7 Days', 'week'),
          const SizedBox(width: 8),
          _buildPeriodChip('30 Days', 'month'),
          const SizedBox(width: 8),
          _buildPeriodChip('All Time', 'all'),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String label, String value) {
    final isSelected = _selectedPeriod == value;
    return GestureDetector(
      onTap: () {
        if (_selectedPeriod != value) {
          setState(() => _selectedPeriod = value);
          _loadAnalyticsData();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.amber : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.amber : Colors.white24,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadAnalyticsData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick stats row
            _buildQuickStatsRow(),
            const SizedBox(height: 20),

            // Growth indicators
            _buildGrowthIndicators(),
            const SizedBox(height: 20),

            // Mini chart
            _buildMiniChart('Earnings Trend', _dailyEarnings, Colors.amber),
            const SizedBox(height: 20),

            // Top supporters preview
            _buildTopSupportersPreview(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildQuickStatCard(
            'Diamonds',
            _formatNumber(_periodDiamonds),
            Icons.diamond,
            Colors.amber,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickStatCard(
            'Viewers',
            _formatNumber(_periodViewers),
            Icons.visibility,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickStatCard(
            'Streams',
            _periodStreams.toString(),
            Icons.live_tv,
            Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
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
      ),
    );
  }

  Widget _buildGrowthIndicators() {
    return Row(
      children: [
        Expanded(
          child: _buildGrowthCard(
            'Earnings Growth',
            _diamondGrowth,
            Icons.trending_up,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildGrowthCard(
            'Viewer Growth',
            _viewerGrowth,
            Icons.group_add,
          ),
        ),
      ],
    );
  }

  Widget _buildGrowthCard(String label, double growth, IconData icon) {
    final isPositive = growth >= 0;
    final color = isPositive ? Colors.green : Colors.red;

    return Container(
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
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${isPositive ? '+' : ''}${growth.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniChart(String title, List<Map<String, dynamic>> data, Color color) {
    if (data.isEmpty) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'No data available',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          ),
        ),
      );
    }

    final maxValue = data.map((d) => d['value'] as int).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: data.map((item) {
                final value = item['value'] as int;
                final height = maxValue > 0 ? (value / maxValue * 80) : 0.0;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Container(
                      height: height.clamp(4.0, 80.0),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSupportersPreview() {
    if (_topSupporters.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Top Supporters',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'View All',
                style: TextStyle(
                  color: Colors.amber.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: _topSupporters.take(5).map((supporter) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.amber, width: 2),
                        ),
                        child: ClipOval(
                          child: supporter['photoUrl'] != null
                              ? Image.network(
                                  supporter['photoUrl'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _buildDefaultAvatar(),
                                )
                              : _buildDefaultAvatar(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.diamond, color: Colors.amber, size: 12),
                          const SizedBox(width: 2),
                          Text(
                            _formatNumber(supporter['totalDiamonds']),
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: const Color(0xFF6C63FF),
      child: const Icon(Icons.person, size: 24, color: Colors.white),
    );
  }

  Widget _buildEarningsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total earnings card
          _buildTotalEarningsCard(),
          const SizedBox(height: 20),

          // Earnings chart
          _buildMiniChart('Daily Earnings', _dailyEarnings, Colors.amber),
          const SizedBox(height: 20),

          // Gift breakdown
          _buildSectionTitle('Gift Breakdown'),
          const SizedBox(height: 12),
          _buildGiftBreakdownList(),
        ],
      ),
    );
  }

  Widget _buildTotalEarningsCard() {
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
      ),
      child: Column(
        children: [
          const Text(
            'Period Earnings',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.diamond, color: Colors.amber, size: 36),
              const SizedBox(width: 8),
              Text(
                NumberFormat('#,###').format(_periodDiamonds),
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
            '≈ \$${NumberFormat('#,###.00').format(_periodDiamonds / 100)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildGiftBreakdownList() {
    if (_topGifts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'No gifts received in this period',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          ),
        ),
      );
    }

    return Column(
      children: _topGifts.map((gift) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Text(
                gift['icon'] ?? '🎁',
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gift['name'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${gift['count']} received',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.diamond, color: Colors.amber, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    _formatNumber(gift['diamonds']),
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildViewersTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Viewer stats
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Viewers',
                  _formatNumber(_periodViewers),
                  Icons.visibility,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Unique',
                  _formatNumber(_uniqueViewers),
                  Icons.person,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Avg Watch Time',
                  '${_avgWatchTime.toStringAsFixed(1)}m',
                  Icons.timer,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Growth',
                  '${_viewerGrowth >= 0 ? '+' : ''}${_viewerGrowth.toStringAsFixed(1)}%',
                  Icons.trending_up,
                  _viewerGrowth >= 0 ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Viewer chart
          _buildMiniChart('Daily Viewers', _dailyViewers, Colors.blue),
          const SizedBox(height: 20),

          // Peak hours
          _buildSectionTitle('Peak Hours'),
          const SizedBox(height: 12),
          _buildPeakHoursChart(),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeakHoursChart() {
    if (_peakHours.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'Not enough data',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          ),
        ),
      );
    }

    final maxViewers = _peakHours.values.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Best streaming times (by viewers)',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(24, (hour) {
                final viewers = _peakHours[hour] ?? 0;
                final height = maxViewers > 0 ? (viewers / maxViewers * 60) : 0.0;
                final isTopHour = viewers == maxViewers && viewers > 0;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: height.clamp(4.0, 60.0),
                          decoration: BoxDecoration(
                            color: isTopHour
                                ? Colors.amber
                                : Colors.blue.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        if (hour % 6 == 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${hour}h',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 8,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stream stats
          _buildSectionTitle('Stream Statistics'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Streams',
                  _periodStreams.toString(),
                  Icons.live_tv,
                  Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Stream Time',
                  '${(_totalStreamMinutes / 60).toStringAsFixed(1)}h',
                  Icons.access_time,
                  Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Avg Duration',
                  '${_avgStreamDuration.toStringAsFixed(0)}m',
                  Icons.timelapse,
                  Colors.teal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Avg Viewers',
                  _periodStreams > 0
                      ? (_periodViewers / _periodStreams).toStringAsFixed(0)
                      : '0',
                  Icons.groups,
                  Colors.indigo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Peak days
          _buildSectionTitle('Peak Days'),
          const SizedBox(height: 12),
          _buildPeakDaysChart(),
          const SizedBox(height: 20),

          // Recommendations
          _buildSectionTitle('Recommendations'),
          const SizedBox(height: 12),
          _buildRecommendations(),
        ],
      ),
    );
  }

  Widget _buildPeakDaysChart() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxViewers = _peakDays.isEmpty
        ? 0
        : _peakDays.values.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(7, (index) {
          final weekday = index + 1;
          final viewers = _peakDays[weekday] ?? 0;
          final percentage = maxViewers > 0 ? viewers / maxViewers : 0.0;
          final isTopDay = viewers == maxViewers && viewers > 0;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  Container(
                    height: 60,
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: double.infinity,
                      height: (percentage * 60).clamp(8.0, 60.0),
                      decoration: BoxDecoration(
                        color: isTopDay
                            ? Colors.amber
                            : Colors.purple.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    days[index],
                    style: TextStyle(
                      color: isTopDay ? Colors.amber : Colors.white70,
                      fontSize: 12,
                      fontWeight: isTopDay ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildRecommendations() {
    final recommendations = <Map<String, dynamic>>[];

    // Generate recommendations based on data
    if (_avgStreamDuration < 30) {
      recommendations.add({
        'icon': Icons.access_time,
        'color': Colors.orange,
        'title': 'Increase Stream Duration',
        'description': 'Longer streams (30+ min) tend to get more viewers and gifts.',
      });
    }

    if (_peakHours.isNotEmpty) {
      final bestHour = _peakHours.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
      recommendations.add({
        'icon': Icons.schedule,
        'color': Colors.blue,
        'title': 'Optimal Streaming Time',
        'description': 'Your viewers are most active around $bestHour:00. Consider streaming then.',
      });
    }

    if (_periodStreams < 3) {
      recommendations.add({
        'icon': Icons.repeat,
        'color': Colors.green,
        'title': 'Stream More Frequently',
        'description': 'Try to stream at least 3-4 times per week to build audience.',
      });
    }

    if (recommendations.isEmpty) {
      recommendations.add({
        'icon': Icons.check_circle,
        'color': Colors.green,
        'title': 'Great Job!',
        'description': 'You\'re doing well! Keep up the consistent streaming schedule.',
      });
    }

    return Column(
      children: recommendations.map((rec) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (rec['color'] as Color).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (rec['color'] as Color).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  rec['icon'] as IconData,
                  color: rec['color'] as Color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rec['title'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rec['description'] as String,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
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
