import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FollowingScreen extends StatefulWidget {
  const FollowingScreen({super.key});

  @override
  State<FollowingScreen> createState() => _FollowingScreenState();
}

class _FollowingScreenState extends State<FollowingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseService _databaseService = DatabaseService();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Following', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF9B6FD7),
            labelStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            tabs: const [
              Tab(text: 'All'),
              Tab(text: 'Live'),
              Tab(text: 'Party'),
              Tab(text: 'Online'),
            ],
          ),
        ),
      ),
      body: StreamBuilder<List<String>>(
        stream: _databaseService.getFollowing(_currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final followingIds = snapshot.data ?? [];

          return TabBarView(
            controller: _tabController,
            children: [
              _buildUserList(followingIds),
              _buildUserList(followingIds, filter: 'Live'),
              _buildUserList(followingIds, filter: 'Party'),
              _buildUserList(followingIds, filter: 'Online'),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUserList(List<String> userIds, {String? filter}) {
    if (userIds.isEmpty) return _buildEmptyState(0);

    return FutureBuilder<List<UserModel>>(
      future: _databaseService.getUsersByIds(userIds),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data ?? [];
        
        // Filter logic
        final filteredUsers = users.where((u) {
          if (filter == 'Online') return u.isOnline;
          if (filter == 'Live') return u.isLive ?? false;
          // Party logic might need additional field, using online for now
          if (filter == 'Party') return u.isOnline; 
          return true;
        }).toList();

        if (filteredUsers.isEmpty) return _buildEmptyState(userIds.length);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My Following (${filteredUsers.length})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Row(
                    children: const [
                      Text('Latest', style: TextStyle(fontSize: 14)),
                      SizedBox(width: 4),
                      Icon(Icons.sort, size: 20),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: filteredUsers.length,
                itemBuilder: (context, index) {
                  final user = filteredUsers[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: user.photos.isNotEmpty
                          ? CachedNetworkImageProvider(user.photos[0])
                          : NetworkImage('https://ui-avatars.com/api/?name=${user.name}') as ImageProvider,
                    ),
                    title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(user.bio ?? 'No bio yet', maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: _buildFollowingButton(user),
                    onTap: () => Navigator.pushNamed(context, '/user_profile_detail', arguments: user),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFollowingButton(UserModel user) {
    return OutlinedButton(
      onPressed: () async {
        await _databaseService.unfollowUser(
          followerId: _currentUserId,
          followingId: user.uid,
        );
        setState(() {}); // Refresh list
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.grey,
        side: const BorderSide(color: Colors.grey),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: const Text('Following'),
    );
  }

  Widget _buildEmptyState(int totalCount) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Following ($totalCount)',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Row(
                children: const [
                    Text('Latest', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 4),
                    Icon(Icons.sort, size: 20),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_outline, size: 80, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('No users found', style: TextStyle(fontSize: 18, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
