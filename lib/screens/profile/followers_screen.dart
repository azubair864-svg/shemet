import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../providers/user_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FollowersScreen extends StatefulWidget {
  const FollowersScreen({super.key});

  @override
  State<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends State<FollowersScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Followers',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<List<String>>(
        stream: _databaseService.getFollowers(_currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final followerIds = snapshot.data ?? [];

          if (followerIds.isEmpty) {
            return _buildEmptyState();
          }

          return FutureBuilder<List<UserModel>>(
            future: _databaseService.getUsersByIds(followerIds),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final followers = userSnapshot.data ?? [];

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: followers.length,
                itemBuilder: (context, index) {
                  final user = followers[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: user.photos.isNotEmpty
                          ? CachedNetworkImageProvider(user.photos[0])
                          : NetworkImage('https://ui-avatars.com/api/?name=${user.name}') as ImageProvider,
                    ),
                    title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Following you', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    trailing: _buildFollowBackAction(user),
                    onTap: () => Navigator.pushNamed(context, '/user_profile_detail', arguments: user),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFollowBackAction(UserModel user) {
    return FutureBuilder<bool>(
      future: _databaseService.isFollowing(followerId: _currentUserId, followingId: user.uid),
      builder: (context, snapshot) {
        final isFollowingBack = snapshot.data ?? false;

        return ElevatedButton(
          onPressed: () async {
            if (isFollowingBack) {
              await _databaseService.unfollowUser(followerId: _currentUserId, followingId: user.uid);
            } else {
              final currentUser = context.read<UserProvider>().currentUser;
              await _databaseService.followUser(
                followerId: _currentUserId, 
                followingId: user.uid,
                followerName: currentUser?.name ?? 'Someone',
              );
            }
            setState(() {}); // Refresh UI
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isFollowingBack ? Colors.grey.shade200 : const Color(0xFFC769B4),
            foregroundColor: isFollowingBack ? Colors.grey.shade700 : Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: Text(isFollowingBack ? 'Following' : 'Follow Back'),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.people_outline, size: 80, color: Colors.purple.shade100),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Followers Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Keep engaging with others to get followers!',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
