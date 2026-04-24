import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';

class MyTasksScreen extends StatefulWidget {
  const MyTasksScreen({super.key});

  @override
  State<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends State<MyTasksScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentPoints = 125;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0E),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 280,
              pinned: true,
              stretch: true,
              backgroundColor: const Color(0xFF0A0A0E),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Premium BG Image
                    Image.file(
                      File('/Users/n.skariyawasam/.gemini/antigravity/brain/78c94e6d-f80f-42ae-8b7c-b7cdc4097e1b/premium_task_header_bg_1774217667163.png'),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                          ),
                        ),
                      ),
                    ),
                    // Radial Glow
                    Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 1.2,
                          colors: [
                            Colors.black.withOpacity(0.2),
                            Colors.black.withOpacity(0.8),
                          ],
                        ),
                      ),
                    ),
                    // Header Content
                    Padding(
                      padding: const EdgeInsets.only(top: 100, left: 24, right: 24),
                      child: Column(
                        children: [
                          const Text(
                            'MONTHLY TASKS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              letterSpacing: 4,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                '🫘',
                                style: TextStyle(fontSize: 32),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$_currentPoints',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 54,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildGlassButton(
                            onPressed: _currentPoints >= 50 ? () => _showRewardDialog(50) : null,
                            text: 'CLAIM REWARD',
                            isGlow: _currentPoints >= 50,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                child: Container(
                  color: const Color(0xFF0A0A0E),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: _buildGlassTabBar(),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildTasksView(),
            _buildRewardsView(),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassTabBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white38,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1),
        tabs: const [
          Tab(text: 'MISSIONS'),
          Tab(text: 'REWARDS'),
        ],
      ),
    );
  }

  Widget _buildTasksView() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Mission Row
                _buildSectionLabel('QUICK MISSIONS'),
                const SizedBox(height: 16),
                SizedBox(
                  height: 110,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildQuickMissionCard('Daily Check-in', '+50', true, Icons.calendar_today_rounded),
                      _buildQuickMissionCard('Invite Friend', '+200', false, Icons.person_add_rounded),
                      _buildQuickMissionCard('Watch Ads', 'Free', false, Icons.play_circle_fill_rounded),
                      _buildQuickMissionCard('Top Up', 'Bonus', false, Icons.diamond_rounded),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                // Newbie Missions
                _buildMissionSection('NEWBIE CHALLENGE', [
                  MissionItem(title: 'Set your name', reward: 50, progress: 1, total: 1, isClaimed: false),
                  MissionItem(title: 'Upload profile picture', reward: 50, progress: 1, total: 1, isClaimed: false),
                  MissionItem(title: 'Verify phone number', reward: 100, progress: 0, total: 1, isClaimed: false),
                ]),

                const SizedBox(height: 32),
                
                // Daily Missions
                _buildMissionSection('DAILY MISSIONS', [
                  MissionItem(title: 'Follow 5 Broadcasters', reward: 25, progress: 2, total: 5, isClaimed: false),
                  MissionItem(title: 'Stay in Live for 10 min', reward: 30, progress: 4, total: 10, isClaimed: false),
                  MissionItem(title: 'Send 3 private messages', reward: 15, progress: 3, total: 3, isClaimed: true),
                  MissionItem(title: 'Make a 1-on-1 call', reward: 50, progress: 0, total: 1, isClaimed: false),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRewardsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Icon(Icons.inventory_2_outlined, size: 64, color: Colors.white.withOpacity(0.1)),
          ),
          const SizedBox(height: 24),
          const Text(
            'NO REWARDS YET',
            style: TextStyle(
              color: Colors.white24,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        color: Colors.white.withOpacity(0.4),
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildQuickMissionCard(String title, String reward, bool isDone, IconData icon) {
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(isDone ? 0.08 : 0.03),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDone ? AppColors.primary.withOpacity(0.4) : Colors.white.withOpacity(0.05),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(icon, color: isDone ? AppColors.primary : Colors.white38, size: 20),
                    if (isDone) const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 16),
                  ],
                ),
                const Spacer(),
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  reward,
                  style: TextStyle(
                    color: reward.contains('Free') ? Colors.blueAccent : Colors.amberAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMissionSection(String title, List<MissionItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(title),
        const SizedBox(height: 16),
        ...items.map((item) => _buildMissionItem(item)),
      ],
    );
  }

  Widget _buildMissionItem(MissionItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(child: Text('🫘', style: TextStyle(fontSize: 20))),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            '+${item.reward}',
                            style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.w900, fontSize: 12),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: item.progress / item.total,
                                backgroundColor: Colors.white.withOpacity(0.05),
                                color: AppColors.primary,
                                minHeight: 4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${item.progress}/${item.total}',
                            style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                _buildActionButton(item),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(MissionItem item) {
    if (item.isClaimed) {
      return const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 28);
    }
    
    final bool isReady = item.progress >= item.total;
    
    return ElevatedButton(
      onPressed: () => _handleMissionAction(item),
      style: ElevatedButton.styleFrom(
        backgroundColor: isReady ? AppColors.primary : Colors.white.withOpacity(0.05),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        minimumSize: const Size(60, 36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 0,
      ),
      child: Text(
        isReady ? 'CLAIM' : 'GO',
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }

  Widget _buildGlassButton({required VoidCallback? onPressed, required String text, bool isGlow = false}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        boxShadow: isGlow ? [
          BoxShadow(
            color: Colors.white.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          )
        ] : null,
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          minimumSize: const Size(200, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          elevation: 0,
        ),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
      ),
    );
  }

  void _handleMissionAction(MissionItem item) {
    if (item.progress >= item.total) {
      setState(() {
        _currentPoints += item.reward;
        item.isClaimed = true;
      });
      _showTaskCompletedDialog(item.reward);
    } else {
      // Handle navigation for "GO"
      if (item.title.contains('name')) {
        HapticFeedback.mediumImpact();
      }
    }
  }

  void _showTaskCompletedDialog(int points) {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E).withOpacity(0.8),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('✨', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 24),
                const Text(
                  'MISSION COMPLETE',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2),
                ),
                const SizedBox(height: 12),
                Text(
                  '+$points BEANS',
                  style: const TextStyle(color: Colors.amberAccent, fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                  ),
                  child: const Text('EXCELLENT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRewardDialog(int reward) {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF0F3460).withOpacity(0.9),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.amber.withOpacity(0.2)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎁', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 24),
                const Text(
                  'CONGRATULATIONS',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2),
                ),
                const SizedBox(height: 12),
                Text(
                  'You received $reward Beans!',
                  style: const TextStyle(color: Colors.amberAccent, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _currentPoints -= reward);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                  ),
                  child: const Text('CLAIM NOW', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MissionItem {
  final String title;
  final int reward;
  final int progress;
  final int total;
  bool isClaimed;

  MissionItem({
    required this.title,
    required this.reward,
    required this.progress,
    required this.total,
    this.isClaimed = false,
  });
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate({required this.child});
  final Widget child;

  @override
  double get minExtent => 64;
  @override
  double get maxExtent => 64;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => true;
}
