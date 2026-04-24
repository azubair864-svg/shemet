import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/database_service.dart';
import '../../models/user_model.dart';
import '../../core/constants/app_colors.dart';

class SocialShareSheet extends StatefulWidget {
  final String roomId;
  final String roomTitle;

  const SocialShareSheet({
    super.key,
    required this.roomId,
    required this.roomTitle,
  });

  @override
  State<SocialShareSheet> createState() => _SocialShareSheetState();
}

class _SocialShareSheetState extends State<SocialShareSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseService _databaseService = DatabaseService();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

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
    return Container(
      height: 500,
      decoration: const BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Stack(
        children: [
          // 1. Glass Background
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF1A1033).withOpacity(0.95), // Deep Purple
                      const Color(0xFF000000).withOpacity(0.98),
                    ],
                  ),
                  border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.1), width: 0.5),
                  ),
                ),
              ),
            ),
          ),

          // 2. Content
          Column(
            children: [
              // Handle Bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Share',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Tabs
              TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF9C27B0), // Purple indicator
                labelColor: const Color(0xFF9C27B0),
                unselectedLabelColor: Colors.white60,
                indicatorSize: TabBarIndicatorSize.label,
                tabs: const [
                  Tab(text: 'Friends'),
                  Tab(text: 'Groups'),
                ],
              ),

              // Tab View
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Friends Tab
                    _buildFriendsList(),
                    // Groups Tab (Placeholder)
                    _buildGroupsList(),
                  ],
                ),
              ),
              
              // Bottom Cancel Button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  margin: const EdgeInsets.all(16),
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  alignment: Alignment.center,
                  child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsList() {
    return FutureBuilder<List<UserModel>>(
      future: _databaseService.getFriends(_currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error loading friends', style: TextStyle(color: Colors.white.withOpacity(0.5))));
        }

        final friends = snapshot.data ?? [];

        if (friends.isEmpty) {
          return Center(
            child: Text(
              'No friends found',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: friends.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final friend = friends[index];
            return _buildShareUserTile(friend);
          },
        );
      },
    );
  }

  Widget _buildGroupsList() {
    return Center(
        child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.group_off_outlined, size: 48, color: Colors.white.withOpacity(0.2)),
        const SizedBox(height: 12),
        Text('No groups yet', style: TextStyle(color: Colors.white.withOpacity(0.4))),
      ],
    ));
  }

  Widget _buildShareUserTile(UserModel user) {
    // Check if recently active
    final bool isOnline = user.isOnline;

    return Row(
      children: [
        // Avatar
        Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.white.withOpacity(0.1),
              backgroundImage: user.photos.isNotEmpty ? CachedNetworkImageProvider(user.photos[0]) : null,
              child: user.photos.isEmpty ? Text(user.name[0].toUpperCase(), style: const TextStyle(color: Colors.white)) : null,
            ),
            if (isOnline)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),

        // Name & Status
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF69B4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          (user.gender?.toLowerCase() == 'female')
                              ? Icons.female
                              : Icons.male,
                          color: Colors.white,
                          size: 10,
                        ),
                        const SizedBox(width: 2),
                        Text('${user.age}', style: const TextStyle(color: Colors.white, fontSize: 10)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    user.country ?? 'Unknown',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Send Button
        GestureDetector(
          onTap: () {
            // Implement simple share logic (e.g., send system message or toast)
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Invitation sent to ${user.name}!'), backgroundColor: Colors.green),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF1493), Color(0xFFFF69B4)], // Pink Gradient
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Share',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
