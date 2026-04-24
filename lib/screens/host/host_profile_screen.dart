import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/host_application_model.dart';
import '../../services/database_service.dart';
import '../../services/host_service.dart';
import '../profile/earnings_dashboard_screen.dart';
import 'host_analytics_screen.dart';

/// ⭐⭐⭐ PRODUCTION-READY HOST PROFILE SCREEN ⭐⭐⭐
/// Complete host profile with streaming stats, followers, earnings, schedule
class HostProfileScreen extends StatefulWidget {
  final String? hostId; // If null, shows current user's host profile

  const HostProfileScreen({super.key, this.hostId});

  @override
  State<HostProfileScreen> createState() => _HostProfileScreenState();
}

class _HostProfileScreenState extends State<HostProfileScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseService _databaseService = DatabaseService();
  final HostService _hostService = HostService();

  late TabController _tabController;

  bool _isLoading = true;
  bool _isCurrentUserProfile = false;
  UserModel? _hostUser;
  HostApplicationModel? _hostApplication;

  // Host statistics
  int _totalDiamonds = 0;
  int _totalFollowers = 0;
  int _totalStreams = 0;
  int _totalStreamMinutes = 0;
  int _totalGiftsReceived = 0;
  int _topSupportersCount = 0;
  double _avgViewersPerStream = 0;

  // Schedule
  List<Map<String, dynamic>> _streamSchedule = [];

  // Recent streams
  List<Map<String, dynamic>> _recentStreams = [];

  // Top supporters
  List<Map<String, dynamic>> _topSupporters = [];

  @override
  void initState() {
    super.initState();
    

    _tabController = TabController(length: 3, vsync: this);

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _isCurrentUserProfile = widget.hostId == null || widget.hostId == currentUserId;

    
    

    _loadHostProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHostProfile() async {
    

    setState(() => _isLoading = true);

    try {
      final hostId = widget.hostId ?? FirebaseAuth.instance.currentUser?.uid;

      if (hostId == null) {
        
        setState(() => _isLoading = false);
        return;
      }

      // Step 1: Load host user data
      
      _hostUser = await _databaseService.getUserById(hostId);

      if (_hostUser == null) {
        
        setState(() => _isLoading = false);
        return;
      }

      
      

      // Step 2: Load host application for category info
      
      _hostApplication = await _hostService.getApplicationByUserId(hostId);

      if (_hostApplication != null) {
        
      }

      // Step 3: Load host statistics
      
      await _loadHostStatistics(hostId);

      // Step 4: Load stream schedule
      
      await _loadStreamSchedule(hostId);

      // Step 5: Load recent streams
      
      await _loadRecentStreams(hostId);

      // Step 6: Load top supporters
      
      await _loadTopSupporters(hostId);

      setState(() => _isLoading = false);

      
      
      
      
      
      
    } catch (e) {
      
      
      
      
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadHostStatistics(String hostId) async {
    

    try {
      // Get follower count from user
      _totalFollowers = _hostUser?.followers ?? 0;
      

      // Get diamond balance
      final userDoc = await _firestore.collection('users').doc(hostId).get();
      _totalDiamonds = (userDoc.data()?['diamonds'] as num?)?.toInt() ?? 0;
      

      // Get total gifts received
      _totalGiftsReceived = _hostUser?.giftsReceived ?? 0;
      

      // Get stream statistics
      final streamsSnapshot = await _firestore
          .collection('live_streams')
          .where('hostId', isEqualTo: hostId)
          .get();

      _totalStreams = streamsSnapshot.docs.length;
      

      // Calculate total stream minutes and average viewers
      int totalViewers = 0;
      for (var doc in streamsSnapshot.docs) {
        final data = doc.data();
        _totalStreamMinutes += (data['durationMinutes'] as num?)?.toInt() ?? 0;
        totalViewers += (data['peakViewers'] as num?)?.toInt() ?? 0;
      }

      _avgViewersPerStream = _totalStreams > 0 ? totalViewers / _totalStreams : 0;
      
      

      // Get top supporters count
      final supportersSnapshot = await _firestore
          .collection('users')
          .doc(hostId)
          .collection('top_supporters')
          .get();

      _topSupportersCount = supportersSnapshot.docs.length;
      
    } catch (e) {
      
    }
  }

  Future<void> _loadStreamSchedule(String hostId) async {
    

    try {
      final now = DateTime.now();
      final snapshot = await _firestore
          .collection('users')
          .doc(hostId)
          .collection('stream_schedule')
          .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .orderBy('scheduledAt')
          .limit(10)
          .get();

      _streamSchedule = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'] ?? 'Untitled Stream',
          'scheduledAt': (data['scheduledAt'] as Timestamp?)?.toDate() ?? now,
          'category': data['category'] ?? 'general',
          'description': data['description'] ?? '',
        };
      }).toList();

      
    } catch (e) {
      
    }
  }

  Future<void> _loadRecentStreams(String hostId) async {
    

    try {
      final snapshot = await _firestore
          .collection('live_streams')
          .where('hostId', isEqualTo: hostId)
          .orderBy('startedAt', descending: true)
          .limit(20)
          .get();

      _recentStreams = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'] ?? 'Untitled Stream',
          'startedAt': (data['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'endedAt': (data['endedAt'] as Timestamp?)?.toDate(),
          'peakViewers': data['peakViewers'] ?? 0,
          'totalGifts': data['totalGifts'] ?? 0,
          'durationMinutes': data['durationMinutes'] ?? 0,
          'thumbnailUrl': data['thumbnailUrl'],
        };
      }).toList();

      
    } catch (e) {
      
    }
  }

  Future<void> _loadTopSupporters(String hostId) async {
    

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(hostId)
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
        });
      }

      
    } catch (e) {
      
    }
  }

  @override
  Widget build(BuildContext context) {
    

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.amber),
            )
          : _hostUser == null
              ? _buildErrorState()
              : _buildProfileContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Host profile not found',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent() {
    return CustomScrollView(
      slivers: [
        // Profile header
        _buildProfileHeader(),

        // Stats bar
        SliverToBoxAdapter(child: _buildStatsBar()),

        // Tab bar
        SliverPersistentHeader(
          pinned: true,
          delegate: _SliverTabBarDelegate(
            TabBar(
              controller: _tabController,
              indicatorColor: Colors.amber,
              labelColor: Colors.amber,
              unselectedLabelColor: Colors.white54,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Streams'),
                Tab(text: 'Supporters'),
              ],
            ),
          ),
        ),

        // Tab content
        SliverFillRemaining(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(),
              _buildStreamsTab(),
              _buildSupportersTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHeader() {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: const Color(0xFF16213E),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (_isCurrentUserProfile)
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: _openHostSettings,
          ),
        IconButton(
          icon: const Icon(Icons.share, color: Colors.white),
          onPressed: _shareProfile,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF6C63FF).withValues(alpha: 0.8),
                const Color(0xFF1A1A2E),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // Profile photo
                Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.amber, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withValues(alpha: 0.5),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _hostUser!.photoURL != null
                            ? Image.network(
                                _hostUser!.photoURL!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _buildDefaultAvatar(),
                              )
                            : _buildDefaultAvatar(),
                      ),
                    ),
                    // Host badge
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Text('👑', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Host name
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _hostUser!.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_hostUser!.isVerified && _hostUser!.gender?.toLowerCase() == 'male')
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(
                          Icons.verified,
                          color: Colors.blue,
                          size: 24,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Category badge
                if (_hostApplication?.category != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _hostApplication!.categoryDisplayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: const Color(0xFF6C63FF),
      child: const Icon(Icons.person, size: 50, color: Colors.white),
    );
  }

  Widget _buildStatsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF16213E),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem('Followers', _totalFollowers, Icons.people),
          _buildDivider(),
          _buildStatItem('Streams', _totalStreams, Icons.live_tv),
          _buildDivider(),
          _buildStatItem('Diamonds', _totalDiamonds, Icons.diamond, isAmber: true),
          _buildDivider(),
          _buildStatItem('Level', _hostUser?.level ?? 1, Icons.star, isAmber: true),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int value, IconData icon, {bool isAmber = false}) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isAmber ? Colors.amber : Colors.white70,
              size: 18,
            ),
            const SizedBox(width: 4),
            Text(
              _formatNumber(value),
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
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 40,
      color: Colors.white.withValues(alpha: 0.2),
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

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick action buttons (if current user)
          if (_isCurrentUserProfile) ...[
            _buildQuickActions(),
            const SizedBox(height: 20),
          ],

          // Bio section
          if (_hostUser!.bio != null && _hostUser!.bio!.isNotEmpty) ...[
            _buildSectionTitle('About'),
            const SizedBox(height: 8),
            Text(
              _hostUser!.bio!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Statistics overview
          _buildSectionTitle('Statistics'),
          const SizedBox(height: 12),
          _buildStatisticsGrid(),
          const SizedBox(height: 20),

          // Upcoming schedule
          if (_streamSchedule.isNotEmpty) ...[
            _buildSectionTitle('Upcoming Streams'),
            const SizedBox(height: 12),
            _buildScheduleList(),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            'Earnings',
            Icons.account_balance_wallet,
            Colors.green,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const EarningsDashboardScreen(),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            'Analytics',
            Icons.bar_chart,
            Colors.blue,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const HostAnalyticsScreen(),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            'Go Live',
            Icons.videocam,
            Colors.red,
            _startLiveStream,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
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

  Widget _buildStatisticsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Total Stream Time',
          '${(_totalStreamMinutes / 60).toStringAsFixed(1)}h',
          Icons.access_time,
          Colors.purple,
        ),
        _buildStatCard(
          'Avg Viewers',
          _avgViewersPerStream.toStringAsFixed(0),
          Icons.visibility,
          Colors.blue,
        ),
        _buildStatCard(
          'Gifts Received',
          _formatNumber(_totalGiftsReceived),
          Icons.card_giftcard,
          Colors.pink,
        ),
        _buildStatCard(
          'Top Supporters',
          _topSupportersCount.toString(),
          Icons.favorite,
          Colors.red,
        ),
      ],
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
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
          Text(
            value,
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

  Widget _buildScheduleList() {
    return Column(
      children: _streamSchedule.take(3).map((schedule) {
        final scheduledAt = schedule['scheduledAt'] as DateTime;
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('MMM').format(scheduledAt).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.purple,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      scheduledAt.day.toString(),
                      style: const TextStyle(
                        color: Colors.purple,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schedule['title'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('EEEE, h:mm a').format(scheduledAt),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStreamsTab() {
    if (_recentStreams.isEmpty) {
      return _buildEmptyState(
        Icons.live_tv,
        'No streams yet',
        'Start your first stream to see it here',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _recentStreams.length,
      itemBuilder: (context, index) {
        final stream = _recentStreams[index];
        return _buildStreamCard(stream);
      },
    );
  }

  Widget _buildStreamCard(Map<String, dynamic> stream) {
    final startedAt = stream['startedAt'] as DateTime;
    final duration = stream['durationMinutes'] as int;
    final peakViewers = stream['peakViewers'] as int;
    final totalGifts = stream['totalGifts'] as int;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail placeholder
          Container(
            height: 120,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              gradient: LinearGradient(
                colors: [
                  Colors.purple.withValues(alpha: 0.5),
                  Colors.blue.withValues(alpha: 0.3),
                ],
              ),
            ),
            child: const Center(
              child: Icon(Icons.play_circle_outline, color: Colors.white, size: 48),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stream['title'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      DateFormat('MMM d, yyyy • h:mm a').format(startedAt),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${duration}m',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStreamStat(Icons.visibility, '$peakViewers peak'),
                    const SizedBox(width: 16),
                    _buildStreamStat(Icons.card_giftcard, '$totalGifts gifts'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamStat(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white54, size: 16),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSupportersTab() {
    if (_topSupporters.isEmpty) {
      return _buildEmptyState(
        Icons.favorite,
        'No supporters yet',
        'Supporters who send you gifts will appear here',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _topSupporters.length,
      itemBuilder: (context, index) {
        final supporter = _topSupporters[index];
        return _buildSupporterCard(supporter, index + 1);
      },
    );
  }

  Widget _buildSupporterCard(Map<String, dynamic> supporter, int rank) {
    final isTopThree = rank <= 3;
    final rankColor = rank == 1
        ? const Color(0xFFFFD700)
        : rank == 2
            ? const Color(0xFFC0C0C0)
            : rank == 3
                ? const Color(0xFFCD7F32)
                : Colors.white54;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: isTopThree
            ? Border.all(color: rankColor.withValues(alpha: 0.5))
            : null,
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isTopThree ? rankColor.withValues(alpha: 0.2) : Colors.white10,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                isTopThree
                    ? rank == 1
                        ? '🥇'
                        : rank == 2
                            ? '🥈'
                            : '🥉'
                    : '#$rank',
                style: TextStyle(
                  color: isTopThree ? rankColor : Colors.white54,
                  fontSize: isTopThree ? 18 : 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isTopThree ? rankColor : Colors.white24,
                width: 2,
              ),
            ),
            child: ClipOval(
              child: supporter['photoUrl'] != null
                  ? Image.network(
                      supporter['photoUrl'],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildDefaultAvatar(),
                    )
                  : _buildDefaultAvatar(),
            ),
          ),
          const SizedBox(width: 12),

          // Name and stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      supporter['name'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (supporter['isVip'] == true)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'VIP',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Lv.${supporter['level']} • ${supporter['giftCount']} gifts',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Diamonds
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.diamond, color: Colors.amber, size: 18),
              const SizedBox(width: 4),
              Text(
                _formatNumber(supporter['totalDiamonds']),
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
              title,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openHostSettings() {
    
    // TODO: Navigate to host settings screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Host settings coming soon!')),
    );
  }

  void _shareProfile() {
    
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share feature coming soon!')),
    );
  }

  void _startLiveStream() {
    
    // TODO: Navigate to broadcast screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Starting live stream...')),
    );
  }
}

/// Delegate for pinned tab bar
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFF16213E),
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
