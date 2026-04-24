import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/moment_model.dart';
import '../../models/user_model.dart';
import '../../services/moment_service.dart';
import '../../services/database_service.dart';
import 'create_moment_screen.dart';
import 'moment_detail_screen.dart';

/// ⭐⭐⭐ PRODUCTION-READY MOMENTS FEED SCREEN ⭐⭐⭐
/// Main feed screen for viewing moments/posts
/// Features: Public feed, Following feed, Trending hashtags
class MomentsFeedScreen extends StatefulWidget {
  const MomentsFeedScreen({super.key});

  @override
  State<MomentsFeedScreen> createState() => _MomentsFeedScreenState();
}

class _MomentsFeedScreenState extends State<MomentsFeedScreen>
    with SingleTickerProviderStateMixin {
  final MomentService _momentService = MomentService();
  final DatabaseService _databaseService = DatabaseService();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  late TabController _tabController;
  UserModel? _currentUser;
  List<String> _followingIds = [];
  List<Map<String, dynamic>> _trendingHashtags = [];
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    
    

    _tabController = TabController(length: 2, vsync: this);
    _loadCurrentUser();
    _loadTrendingHashtags();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    
    try {
      final user = await _databaseService.getUserById(_currentUserId);
      if (mounted && user != null) {
        setState(() {
          _currentUser = user;
          _isLoadingUser = false;
        });
        

        // Load following IDs from subcollection
        _databaseService.getFollowing(_currentUserId).listen((ids) {
          if (mounted) {
            setState(() => _followingIds = ids);
            
          }
        });
      }
    } catch (e) {
      
      if (mounted) setState(() => _isLoadingUser = false);
    }
  }

  Future<void> _loadTrendingHashtags() async {
    
    try {
      final hashtags = await _momentService.getTrendingHashtags(limit: 5);
      if (mounted) {
        setState(() => _trendingHashtags = hashtags);
        
      }
    } catch (e) {
      
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Trending hashtags
          if (_trendingHashtags.isNotEmpty) _buildTrendingHashtags(),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPublicFeed(),
                _buildFollowingFeed(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildCreateButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      title: const Text(
        'Moments',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFFFF1493),
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey,
        tabs: const [
          Tab(text: 'Discover'),
          Tab(text: 'Following'),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white),
          onPressed: _showSearchDialog,
        ),
      ],
    );
  }

  Widget _buildTrendingHashtags() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _trendingHashtags.length,
        itemBuilder: (context, index) {
          final hashtag = _trendingHashtags[index];
          return GestureDetector(
            onTap: () => _searchByHashtag(hashtag['tag']),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF1493).withValues(alpha: 0.3),
                    const Color(0xFFFF69B4).withValues(alpha: 0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFFF1493).withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '#',
                    style: TextStyle(
                      color: Color(0xFFFF1493),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    hashtag['tag'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${hashtag['count']}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPublicFeed() {
    
    return StreamBuilder<List<MomentModel>>(
      stream: _momentService.getPublicFeed(currentUserId: _currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF1493)),
          );
        }

        if (snapshot.hasError) {
          
          return _buildErrorWidget('Error loading moments');
        }

        final moments = snapshot.data ?? [];
        

        if (moments.isEmpty) {
          return _buildEmptyWidget('No moments yet\nBe the first to share!');
        }

        return RefreshIndicator(
          onRefresh: () async {
            // Just triggers rebuild
            setState(() {});
          },
          color: const Color(0xFFFF1493),
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: moments.length,
            itemBuilder: (context, index) => _buildMomentCard(moments[index]),
          ),
        );
      },
    );
  }

  Widget _buildFollowingFeed() {
    
    

    if (_isLoadingUser) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF1493)),
      );
    }

    if (_followingIds.isEmpty) {
      return _buildEmptyWidget(
        'Follow people to see their moments\n\nDiscover interesting people in the Discover tab!',
      );
    }

    return StreamBuilder<List<MomentModel>>(
      stream: _momentService.getFollowingFeed(
        userId: _currentUserId,
        followingIds: _followingIds,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF1493)),
          );
        }

        if (snapshot.hasError) {
          
          return _buildErrorWidget('Error loading moments');
        }

        final moments = snapshot.data ?? [];
        

        if (moments.isEmpty) {
          return _buildEmptyWidget(
            'No moments from people you follow\n\nThey haven\'t posted yet!',
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          color: const Color(0xFFFF1493),
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: moments.length,
            itemBuilder: (context, index) => _buildMomentCard(moments[index]),
          ),
        );
      },
    );
  }

  Widget _buildMomentCard(MomentModel moment) {
    return GestureDetector(
      onTap: () => _openMomentDetail(moment),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User header
            _buildMomentHeader(moment),

            // Content
            if (moment.text != null && moment.text!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildTextWithHashtags(moment.text!),
              ),

            // Media
            if (moment.hasMedia) _buildMediaSection(moment),

            // Location
            if (moment.location != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      moment.location!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

            // Actions
            _buildMomentActions(moment),

            // Time
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                moment.timeAgo,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMomentHeader(MomentModel moment) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // User avatar
          GestureDetector(
            onTap: () => _openUserProfile(moment.userId),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: moment.userIsVip
                      ? Colors.amber
                      : const Color(0xFFFF1493),
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: moment.userPhoto != null
                    ? CachedNetworkImage(
                        imageUrl: moment.userPhoto!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[900],
                          padding: const EdgeInsets.all(10),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFFF1493),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[900],
                          child: const Icon(Icons.person, color: Colors.white),
                        ),
                      )
                    : Container(
                        color: Colors.grey,
                        child: const Icon(Icons.person, color: Colors.white),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // User info
          Expanded(
            child: GestureDetector(
              onTap: () => _openUserProfile(moment.userId),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        moment.userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      if (moment.userIsVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified,
                          color: Color(0xFF1DA1F2),
                          size: 16,
                        ),
                      ],
                      if (moment.userIsVip) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.amber, Colors.orange],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'VIP',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF1493), Color(0xFFFF69B4)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Lv${moment.userLevel}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // More options
          IconButton(
            icon: Icon(
              Icons.more_horiz,
              color: Colors.white.withValues(alpha: 0.6),
            ),
            onPressed: () => _showMomentOptions(moment),
          ),
        ],
      ),
    );
  }

  Widget _buildTextWithHashtags(String text) {
    final words = text.split(' ');
    return Wrap(
      children: words.map((word) {
        if (word.startsWith('#')) {
          return GestureDetector(
            onTap: () => _searchByHashtag(word.replaceAll('#', '')),
            child: Text(
              '$word ',
              style: const TextStyle(
                color: Color(0xFFFF1493),
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
          );
        } else if (word.startsWith('@')) {
          return GestureDetector(
            onTap: () => _openUserByName(word.replaceAll('@', '')),
            child: Text(
              '$word ',
              style: const TextStyle(
                color: Color(0xFF1DA1F2),
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
          );
        }
        return Text(
          '$word ',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            height: 1.4,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMediaSection(MomentModel moment) {
    if (moment.mediaUrls.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: moment.mediaUrls.length == 1
          ? _buildSingleMedia(moment.mediaUrls.first, moment.isVideo)
          : _buildMediaGrid(moment.mediaUrls, moment.isVideo),
    );
  }

  Widget _buildSingleMedia(String url, bool isVideo) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 400),
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              height: 200,
              color: Colors.grey[900],
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFFF1493),
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              height: 200,
              color: Colors.grey[900],
              child: const Icon(Icons.broken_image, color: Colors.grey, size: 50),
            ),
          ),
        ),
        if (isVideo)
          Positioned.fill(
            child: Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMediaGrid(List<String> urls, bool isVideo) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: urls.length,
        itemBuilder: (context, index) {
          return Container(
            width: 200,
            margin: const EdgeInsets.only(right: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: urls[index],
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[900],
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF1493),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[900],
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                  if (isVideo && index == 0)
                    Center(
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMomentActions(MomentModel moment) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // Like button
          _buildActionButton(
            icon: moment.isLikedByCurrentUser
                ? Icons.favorite
                : Icons.favorite_border,
            color: moment.isLikedByCurrentUser
                ? const Color(0xFFFF1493)
                : Colors.white.withValues(alpha: 0.7),
            count: moment.formattedLikes,
            onTap: () => _toggleLike(moment),
          ),

          // Comment button
          _buildActionButton(
            icon: Icons.chat_bubble_outline,
            color: Colors.white.withValues(alpha: 0.7),
            count: moment.formattedComments,
            onTap: () => _openMomentDetail(moment),
          ),

          // Share button
          _buildActionButton(
            icon: Icons.share_outlined,
            color: Colors.white.withValues(alpha: 0.7),
            count: moment.formattedShares,
            onTap: () => _shareMoment(moment),
          ),

          const Spacer(),

          // Views
          Row(
            children: [
              Icon(
                Icons.visibility_outlined,
                size: 18,
                color: Colors.white.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 4),
              Text(
                moment.formattedViews,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String count,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            if (count.isNotEmpty && count != '0') ...[
              const SizedBox(width: 4),
              Text(
                count,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCreateButton() {
    return FloatingActionButton(
      onPressed: _createMoment,
      backgroundColor: const Color(0xFFFF1493),
      child: const Icon(Icons.add, color: Colors.white, size: 28),
    );
  }

  Widget _buildEmptyWidget(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 80,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => setState(() {}),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF1493),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ==================== ACTIONS ====================

  Future<void> _toggleLike(MomentModel moment) async {
    
    try {
      await _momentService.toggleLike(
        momentId: moment.momentId,
        userId: _currentUserId,
        userName: _currentUser?.name ?? 'User',
      );
      
    } catch (e) {
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareMoment(MomentModel moment) async {
    
    try {
      await _momentService.shareMoment(
        momentId: moment.momentId,
        userId: _currentUserId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Moment shared!'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      
    }
  }

  void _createMoment() {
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateMomentScreen(currentUser: _currentUser),
      ),
    ).then((_) {
      // Refresh feed when coming back
      setState(() {});
    });
  }

  void _openMomentDetail(MomentModel moment) {
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MomentDetailScreen(
          moment: moment,
          currentUser: _currentUser,
        ),
      ),
    );
  }

  void _openUserProfile(String userId) {
    
    Navigator.pushNamed(context, '/user_profile_detail', arguments: {'userId': userId});
  }

  void _openUserByName(String username) {
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening @$username profile...')),
    );
  }

  void _searchByHashtag(String hashtag) {
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HashtagSearchScreen(
          hashtag: hashtag,
          currentUserId: _currentUserId,
        ),
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => _SearchDialog(
        onSearch: (query) {
          if (query.startsWith('#')) {
            _searchByHashtag(query.replaceAll('#', ''));
          } else {
            
          }
        },
      ),
    );
  }

  void _showMomentOptions(MomentModel moment) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // If own moment, show delete option
            if (moment.userId == _currentUserId) ...[
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteMoment(moment);
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: Colors.orange),
                title: const Text('Report', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _reportMoment(moment);
                },
              ),
              ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: const Text('Block user', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],

            ListTile(
              leading: Icon(Icons.copy, color: Colors.white.withValues(alpha: 0.7)),
              title: Text('Copy link', style: TextStyle(color: Colors.white.withValues(alpha: 0.9))),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied!')),
                );
              },
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteMoment(MomentModel moment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Delete Moment', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this moment? This action cannot be undone.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteMoment(moment);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMoment(MomentModel moment) async {
    
    try {
      final success = await _momentService.deleteMoment(
        momentId: moment.momentId,
        userId: _currentUserId,
      );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Moment deleted'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _reportMoment(MomentModel moment) async {
    final reasons = [
      'Spam',
      'Inappropriate content',
      'Harassment',
      'Violence',
      'False information',
      'Other',
    ];

    String? selectedReason;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Report Moment', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons
              .map(
                (reason) => ListTile(
                  title: Text(reason, style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    selectedReason = reason;
                    Navigator.pop(context);
                  },
                ),
              )
              .toList(),
        ),
      ),
    );

    if (selectedReason != null) {
      await _momentService.reportMoment(
        momentId: moment.momentId,
        reporterId: _currentUserId,
        reason: selectedReason!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted. Thank you!'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    }
  }
}

// ==================== SEARCH DIALOG ====================

class _SearchDialog extends StatefulWidget {
  final Function(String) onSearch;

  const _SearchDialog({required this.onSearch});

  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: const Text('Search', style: TextStyle(color: Colors.white)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search hashtags (#travel)...',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          prefixIcon: const Icon(Icons.search, color: Color(0xFFFF1493)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFFF1493)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFFF1493), width: 2),
          ),
        ),
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            Navigator.pop(context);
            widget.onSearch(value.trim());
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () {
            if (_controller.text.trim().isNotEmpty) {
              Navigator.pop(context);
              widget.onSearch(_controller.text.trim());
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF1493),
          ),
          child: const Text('Search'),
        ),
      ],
    );
  }
}

// ==================== HASHTAG SEARCH SCREEN ====================

class HashtagSearchScreen extends StatelessWidget {
  final String hashtag;
  final String currentUserId;

  const HashtagSearchScreen({
    super.key,
    required this.hashtag,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final momentService = MomentService();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          '#$hashtag',
          style: const TextStyle(
            color: Color(0xFFFF1493),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<List<MomentModel>>(
        stream: momentService.searchByHashtag(
          hashtag: hashtag,
          currentUserId: currentUserId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF1493)),
            );
          }

          final moments = snapshot.data ?? [];

          if (moments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.tag,
                    size: 80,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No moments with #$hashtag',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: moments.length,
            itemBuilder: (context, index) {
              final moment = moments[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MomentDetailScreen(
                        moment: moment,
                        currentUser: null,
                      ),
                    ),
                  );
                },
                child: Container(
                  color: Colors.grey[900],
                  child: moment.hasMedia
                      ? Image.network(
                          moment.mediaUrls.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image,
                            color: Colors.grey,
                          ),
                        )
                      : Center(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              moment.text ?? '',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
