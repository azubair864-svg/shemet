import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/user_provider.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../core/constants/app_colors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final user = FirebaseAuth.instance.currentUser;
    final currentUser = userProvider.currentUser;

    return StreamBuilder<UserModel?>(
      stream: user != null ? DatabaseService().getUserStream(user.uid) : null,
      initialData: currentUser,
      builder: (context, snapshot) {
        final liveUser = snapshot.data ?? currentUser;

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // 1. Premium Dynamic Background
              Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.8, -0.6),
                    radius: 1.5,
                    colors: [
                      Color(0xFF1F1235),
                      Colors.black,
                    ],
                  ),
                ),
              ),
              
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // 2. Refined SliverAppBar
                  SliverAppBar(
                    expandedHeight: 280,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    pinned: true,
                    stretch: true,
                    actions: [
                      _buildHeaderAction(Icons.visibility_outlined, () => Navigator.pushNamed(context, '/profile_visitors')),
                      const SizedBox(width: 8),
                      _buildHeaderAction(Icons.edit_outlined, () {}),
                      const SizedBox(width: 16),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      stretchModes: const [StretchMode.zoomBackground],
                      background: Stack(
                        alignment: Alignment.center,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 40),
                              // Avatar Block
                              _buildPremiumAvatar(liveUser?.mainPhoto),
                              const SizedBox(height: 16),
                              // Name and Verified Badge
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    liveUser?.displayName ?? 'Welcome User',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  if ((liveUser?.isVerified ?? false) && liveUser?.gender?.toLowerCase() == 'male') ...[
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.verified_rounded,
                                      color: Colors.blue,
                                      size: 18,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Numeric UID Display - Deterministic & Enhanced
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.amber.withOpacity(0.2),
                                      Colors.orange.withOpacity(0.1),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.amber.withOpacity(0.3),
                                    width: 0.8,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.amber.withOpacity(0.1),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'ID ',
                                      style: TextStyle(
                                        color: Colors.amber,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      liveUser?.displayId ?? '',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.copy_rounded,
                                      color: Colors.white.withOpacity(0.5),
                                      size: 12,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Chips Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildGlassChip('🇱🇰', liveUser?.country ?? 'Sri Lanka'),
                                  const SizedBox(width: 8),
                                  _buildGlassChip('🔊', liveUser?.language ?? 'Sinhala'),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3. Body Content
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          // Stats Row
                          _buildStatsContainer(context, liveUser),
                          const SizedBox(height: 16),
                          // Currency Section
                          Row(
                            children: [
                              Expanded(
                                child: _buildGlassCurrencyCard(
                                  title: 'Diamonds',
                                  value: (liveUser?.diamonds ?? 0).toString(),
                                  accentColor: const Color(0xFF7B2CBF),
                                  icon: Icons.diamond_rounded,
                                  onTap: () => Navigator.pushNamed(context, '/diamond_purchase'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildGlassCurrencyCard(
                                  title: 'Beans',
                                  value: (liveUser?.earningsBeans ?? 0).toString(),
                                  accentColor: Colors.orange,
                                  icon: Icons.monetization_on_rounded,
                                  onTap: () => Navigator.pushNamed(context, '/my_beans'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Menu Header
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'ACCOUNT SETTINGS',
                              style: TextStyle(
                                color: Colors.white24,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Premium Menu Grid/List
                          if (!(liveUser?.isVerified ?? false))
                            _buildMenuTile(
                              icon: Icons.verified_user_rounded,
                              title: 'Verify Profile',
                              trailing: liveUser?.isVerified ?? false ? 'Verified' : 'Get Badge',
                              accentColor: Colors.blue,
                              onTap: () => Navigator.pushNamed(context, '/auto_verification'),
                            ),
                          _buildMenuTile(
                            icon: Icons.auto_graph_rounded,
                            title: 'My Level',
                            trailing: 'Lv${liveUser?.level ?? 0}',
                            accentColor: const Color(0xFFFF1493),
                            onTap: () => Navigator.pushNamed(context, '/my_level'),
                          ),
                          _buildMenuTile(
                            icon: Icons.card_giftcard_rounded,
                            title: 'My Invitation',
                            trailing: 'Get Rewards',
                            accentColor: Colors.orange,
                            onTap: () => Navigator.pushNamed(context, '/my_invitation'),
                          ),
                          _buildMenuTile(
                            icon: Icons.task_alt_rounded,
                            title: 'Daily Tasks',
                            trailing: '💎100',
                            accentColor: Colors.amber,
                            onTap: () => Navigator.pushNamed(context, '/my_tasks'),
                          ),
                          if (liveUser?.gender?.toLowerCase() != 'male')
                            _buildMenuTile(
                              icon: Icons.chat_bubble_outline_rounded,
                              title: 'Greeting Words',
                              accentColor: Colors.teal,
                              onTap: () => Navigator.pushNamed(context, '/greeting_words'),
                            ),
                          _buildMenuTile(
                            icon: Icons.person_outline_rounded,
                            title: 'Edit Profile',
                            accentColor: Colors.purpleAccent,
                            onTap: () => Navigator.pushNamed(context, '/edit_profile'),
                          ),
                          _buildMenuTile(
                            icon: Icons.settings_rounded,
                            title: 'App Settings',
                            accentColor: Colors.grey,
                            onTap: () => Navigator.pushNamed(context, '/settings'),
                          ),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderAction(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _buildPremiumAvatar(String? photoUrl) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer Glow
        Container(
          width: 110, height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withOpacity(0.1),
            boxShadow: [
              BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20, spreadRadius: 5),
            ],
          ),
        ),
        // Avatar Ring
        Container(
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [AppColors.primary, Color(0xFFFF69B4)]),
          ),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
            child: CircleAvatar(
              radius: 46,
              backgroundColor: Colors.white.withOpacity(0.05),
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null ? const Icon(Icons.person, size: 40, color: Colors.white24) : null,
            ),
          ),
        ),
        // Badge
        Positioned(
          bottom: 2, right: 2,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Colors.orange, Colors.redAccent]),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildGlassChip(String icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildStatsContainer(BuildContext context, UserModel? currentUser) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStatBadge(context, '${currentUser?.friends ?? 0}', 'Friends', Icons.people_outline_rounded, () => Navigator.pushNamed(context, '/friends')),
          const SizedBox(width: 8),
          _buildStatBadge(context, '${currentUser?.following ?? 0}', 'Following', Icons.person_add_alt_1_rounded, () => Navigator.pushNamed(context, '/following')),
          const SizedBox(width: 8),
          _buildStatBadge(context, '${currentUser?.followers ?? 0}', 'Followers', Icons.favorite_border_rounded, () => Navigator.pushNamed(context, '/followers')),
        ],
      ),
    );
  }

  Widget _buildStatBadge(BuildContext context, String count, String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withOpacity(0.03), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white38, size: 14),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(count, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildGlassCurrencyCard({
    required String title,
    required String value,
    required Color accentColor,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accentColor, size: 16),
                const SizedBox(width: 8),
                Text(title, style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    String? trailing,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          decoration: const BoxDecoration(
            color: Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(icon, color: accentColor, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              if (trailing != null)
                Text(trailing, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded, color: Colors.white12, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}
