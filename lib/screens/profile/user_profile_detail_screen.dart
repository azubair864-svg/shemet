import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../models/call_model.dart';
import '../../services/database_service.dart';
import '../../services/call_service.dart';
import '../../services/gift_service.dart';
import '../../widgets/gifts_bottom_sheet.dart';
import '../../providers/user_provider.dart';

class UserProfileDetailScreen extends StatefulWidget {
  final UserModel user;

  const UserProfileDetailScreen({
    super.key,
    required this.user,
  });

  @override
  State<UserProfileDetailScreen> createState() =>
      _UserProfileDetailScreenState();
}

class _UserProfileDetailScreenState extends State<UserProfileDetailScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _databaseService = DatabaseService();
  final CallService _callService = CallService();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  bool _isFollowing = false;
  bool _isFriend = false;
  bool _isBlocked = false;
  bool _isFavorite = false;
  bool _isLoading = true;
  int _followersCount = 0;
  int _followingCount = 0;
  int _selectedPhotoIndex = 0;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadFollowStatus();
    _loadFollowCounts();
    _loadFavoriteStatus();
    _checkBlockStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkBlockStatus() async {
    try {
      final isBlocked = await _databaseService.isBlocked(
        currentUserId: _currentUserId,
        otherUserId: widget.user.uid,
      );
      if (mounted) {
        setState(() => _isBlocked = isBlocked);
      }
    } catch (e) {
      debugPrint('[BLOCK_CHECK_ERROR] $e');
    }
  }

  Future<void> _loadFollowStatus() async {
    try {
      final isFollowing = await _databaseService.isFollowing(
        followerId: _currentUserId,
        followingId: widget.user.uid,
      );
      // Check for mutual follow
      final isOtherFollowingMe = await _databaseService.isFollowing(
        followerId: widget.user.uid,
        followingId: _currentUserId,
      );

      if (mounted) {
        setState(() {
          _isFollowing = isFollowing;
          _isFriend = isFollowing && isOtherFollowingMe;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadFollowCounts() async {
    setState(() {
      _followersCount = widget.user.followers;
      _followingCount = widget.user.following;
    });
  }

  Future<void> _loadFavoriteStatus() async {
    // TODO: Implement favorite status check from Firestore
    setState(() {
      _isFavorite = false; // Default to false for now
    });
  }

  Future<void> _handleFollowToggle() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      if (_isFollowing) {
        await _databaseService.unfollowUser(
          followerId: _currentUserId,
          followingId: widget.user.uid,
        );
        if (mounted) {
          setState(() {
            _isFollowing = false;
            _followersCount = (_followersCount > 0) ? _followersCount - 1 : 0;
          });
          _showSnackBar('Unfollowed ${widget.user.name}', Colors.grey);
        }
      } else {
        final currentUser = context.read<UserProvider>().currentUser;
        await _databaseService.followUser(
          followerId: _currentUserId,
          followingId: widget.user.uid,
          followerName: currentUser?.name ?? 'Someone',
        );
        if (mounted) {
          setState(() {
            _isFollowing = true;
            _followersCount++;
          });
          _showSnackBar('Following ${widget.user.name}', Colors.green);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: $e', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleFavorite() async {
    setState(() {
      _isFavorite = !_isFavorite;
    });

    // TODO: Save to Firestore favorites collection
    try {
      if (_isFavorite) {
        // await _databaseService.addToFavorites(_currentUserId, widget.user.uid);
        _showSnackBar('Added to favorites', Colors.pink);
      } else {
        // await _databaseService.removeFromFavorites(_currentUserId, widget.user.uid);
        _showSnackBar('Removed from favorites', Colors.grey);
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          backgroundColor: color,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: _databaseService.getUserStream(widget.user.uid),
      initialData: widget.user,
      builder: (context, snapshot) {
        final liveUser = snapshot.data ?? widget.user;
        
        // Synchronize local counts with live data
        _followersCount = liveUser.followers;
        _followingCount = liveUser.following;

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // 🎢 MAIN SCROLL VIEW WITH PARALLAX
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildParallaxHeader(liveUser),
                  
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _buildPremiumProfileCard(liveUser),
                        _buildTabSection(liveUser),
                        const SizedBox(height: 120), // Padding for bottom bar
                      ],
                    ),
                  ),
                ],
              ),

              // 🎨 FLOATING TOP BAR
              _buildFloatingTopBar(),

              // 🚀 PREMIUM BOTTOM ACTION BAR
              _buildFloatingBottomActionBar(liveUser),
            ],
          ),
        );
      }
    );
  }

  Widget _buildParallaxHeader(UserModel user) {
    return SliverAppBar(
      expandedHeight: MediaQuery.of(context).size.height * 0.55,
      backgroundColor: Colors.black,
      automaticallyImplyLeading: false,
      elevation: 0,
      stretch: true,
      pinned: false,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Photo Carousel
            PageView.builder(
              itemCount: user.photos.length,
              onPageChanged: (index) => setState(() => _selectedPhotoIndex = index),
              itemBuilder: (context, index) {
                return CachedNetworkImage(
                  imageUrl: user.photos[index],
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: Colors.black26),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                );
              },
            ),
            
            // Subtle Overlay Gradients
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.3, 0.7, 1.0],
                    colors: [
                      Colors.black.withOpacity(0.4),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.9),
                    ],
                  ),
                ),
              ),
            ),

            // Photo Indicators
            if (user.photos.length > 1)
              Positioned(
                bottom: 60,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    user.photos.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: _selectedPhotoIndex == index ? 24 : 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: _selectedPhotoIndex == index
                            ? Colors.white
                            : Colors.white.withOpacity(0.4),
                      ),
                    ),
                  ),
                ),
              ),

            // Online Badge (Pulsing)
            if (user.isOnline)
              Positioned(
                bottom: 80,
                left: 20,
                child: _buildPulsingOnlineBadge(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPulsingOnlineBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withOpacity(0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.green, blurRadius: 6, spreadRadius: 2)],
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'ONLINE',
            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingTopBar() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildTopBarButton(
            icon: Icons.arrow_back_ios_new, 
            onTap: () => Navigator.pop(context),
          ),
          Row(
            children: [
              _buildTopBarButton(
                icon: _isFavorite ? Icons.favorite : Icons.favorite_border,
                iconColor: _isFavorite ? Colors.pink : Colors.white,
                onTap: _toggleFavorite,
              ),
              const SizedBox(width: 12),
              _buildTopBarButton(
                icon: Icons.more_vert,
                onTap: _showMoreOptions,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopBarButton({required IconData icon, required VoidCallback onTap, Color iconColor = Colors.white}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
          ),
          child: IconButton(
            icon: Icon(icon, color: iconColor, size: 20),
            onPressed: onTap,
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundCarousel(UserModel user) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.55,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: user.photos.length,
            onPageChanged: (index) {
              setState(() {
                _selectedPhotoIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: CachedNetworkImageProvider(user.photos[index]),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.3),
                        Colors.black.withOpacity(0.8)
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Photo Indicators
          if (user.photos.length > 1)
            Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  user.photos.length,
                      (index) => Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _selectedPhotoIndex == index
                          ? Colors.white
                          : Colors.white.withOpacity(0.4),
                    ),
                  ),
                ),
              ),
            ),

          // Online Status Indicator
          if (user.isOnline)
            Positioned(
              top: 100,
              left: 20,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Online',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _isFavorite ? Colors.pink : Colors.white,
              ),
              onPressed: _toggleFavorite,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onPressed: _showMoreOptions,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumProfileCard(UserModel user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 45, 24, 24), // Even more top padding (45)
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55), // Dark Glass Style
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.5),
            ),
            child: Column(
              children: [
                // Profile Header with Level Ring
                Row(
                  children: [
                    _buildAnimatedLevelAvatar(user),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  user.name,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                (user.gender?.toLowerCase() == 'female') ? Icons.female : Icons.male,
                                color: (user.gender?.toLowerCase() == 'female') ? Colors.pinkAccent : Colors.blueAccent,
                                size: 22,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${user.age ?? 0}',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white.withOpacity(0.7),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (user.isLive ?? false) _buildNeonBadge('LIVE', const Color(0xFFFF1493)),
                              if ((user.isVerified ?? false) && user.gender?.toLowerCase() == 'male') _buildNeonBadge('Verified', Colors.blueAccent),
                              if (user.isVip ?? false) _buildNeonBadge('VIP', const Color(0xFFFFD700)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _buildPremiumFollowButton(),
                  ],
                ),

                const SizedBox(height: 30),

                // Premium Stats Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildPremiumStat('Followers', _followersCount),
                    _buildStatDivider(),
                    _buildPremiumStat('Following', _followingCount),
                    _buildStatDivider(),
                    _buildPremiumStat('Gifts', user.giftsReceived ?? 0),
                  ],
                ),

                const SizedBox(height: 25),
                Divider(color: Colors.white.withOpacity(0.1)),
                const SizedBox(height: 20),

                // Location & Language Cards
                Row(
                  children: [
                    _buildInfoCard(Icons.location_on, '${user.countryFlag} ${user.country ?? "Unknown"}'),
                    const SizedBox(width: 12),
                    _buildInfoCard(Icons.language, user.language ?? "Universal"),
                  ],
                ),

                if (user.bio != null && user.bio!.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      user.bio!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                        height: 1.6,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedLevelAvatar(UserModel user) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Level Progress Ring (Neon)
        SizedBox(
          width: 82,
          height: 82,
          child: CircularProgressIndicator(
            value: (user.level % 10) / 10, // Placeholder for level progress
            strokeWidth: 3,
            backgroundColor: Colors.white.withOpacity(0.1),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF1493)),
          ),
        ),
        
        // Main Avatar
        Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child: CircleAvatar(
            radius: 35,
            backgroundColor: Colors.white.withOpacity(0.1),
            backgroundImage: user.photos.isNotEmpty
                ? CachedNetworkImageProvider(user.photos[0])
                : const NetworkImage('https://ui-avatars.com/api/?name=User') as ImageProvider,
          ),
        ),

        // Verification Badge
        if ((user.isVerified ?? false) && user.gender?.toLowerCase() == 'male')
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
              child: const Icon(Icons.verified, size: 14, color: Colors.white),
            ),
          ),

        // Floating Level Text
        Positioned(
          top: 0, // Adjusted from -2 to 0 to prevent clipping
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.5), blurRadius: 4)],
            ),
            child: Text(
              'LV.${user.level}',
              style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNeonBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildPremiumStat(String label, int count) {
    return Column(
      children: [
        Text(
          '$count',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.5), letterSpacing: 1),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(height: 25, width: 1, color: Colors.white.withOpacity(0.1));
  }

  Widget _buildInfoCard(IconData icon, String text) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFFFF69B4)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumFollowButton() {
    return GestureDetector(
      onTap: _handleFollowToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          gradient: _isFollowing
              ? null
              : const LinearGradient(colors: [Color(0xFFFF69B4), Color(0xFFFF1493)]),
          color: _isFollowing ? Colors.white.withOpacity(0.1) : null,
          shape: BoxShape.circle,
          boxShadow: _isFollowing ? null : [
            BoxShadow(color: const Color(0xFFFF69B4).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: _isLoading 
          ? const Padding(padding: EdgeInsets.all(15), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Icon(_isFollowing ? Icons.check : Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildFollowButton() {
    if (_isLoading) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF69B4)),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: _isFollowing
            ? null
            : LinearGradient(
          colors: [Color(0xFFFF69B4), Color(0xFFFF1493)],
        ),
        color: _isFollowing ? Colors.grey.shade300 : null,
        shape: BoxShape.circle,
        boxShadow: _isFollowing
            ? null
            : [
          BoxShadow(
            color: Color(0xFFFF69B4).withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(
          _isFriend 
              ? Icons.people 
              : (_isFollowing ? Icons.check : Icons.add),
          color: Colors.white,
          size: 24,
        ),
        onPressed: _handleFollowToggle,
      ),
    );
  }

  Widget _buildBadge(String text, Color color,
      {bool hasIcon = false, IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasIcon && icon != null) ...[
            Icon(icon, size: 8, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count) {
    return Column(
      children: [
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFF69B4),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildInterestTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFFF69B4).withOpacity(0.15),
            Color(0xFFFF1493).withOpacity(0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Color(0xFFFF69B4).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFFFF1493),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildVoiceIntro() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFFF69B4).withOpacity(0.1),
            Color(0xFFFF1493).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color(0xFFFF69B4).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFF69B4), Color(0xFFFF1493)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Voice Introduction',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap to listen',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Color(0xFFFF69B4).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '0:15',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFFFF1493),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSection(UserModel user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08), // Dark Glass Style for Tabs
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            ),
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFFFF1493),
                  unselectedLabelColor: Colors.white.withOpacity(0.5),
                  indicatorColor: const Color(0xFFFF1493),
                  indicatorWeight: 3,
                  dividerColor: Colors.transparent, // Remove default divider
                  tabs: const [
                    Tab(text: 'Photos'),
                    Tab(text: 'Gifts'),
                    Tab(text: 'Moments'),
                  ],
                ),
                SizedBox(
                  height: 300,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPhotosTab(user),
                      _buildGiftsTab(),
                      _buildMomentsTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotosTab(UserModel user) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: user.photos.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            // Open full screen image viewer
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: NetworkImage(user.photos[index]),
                fit: BoxFit.cover,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGiftsTab() {
    // Mock gifts data - replace with actual data
    final mockGifts = [
      {'name': 'Rose', 'emoji': '🌹', 'count': 42},
      {'name': 'Heart', 'emoji': '💖', 'count': 35},
      {'name': 'Diamond', 'emoji': '💎', 'count': 28},
      {'name': 'Crown', 'emoji': '👑', 'count': 15},
      {'name': 'Star', 'emoji': '⭐', 'count': 12},
      {'name': 'Trophy', 'emoji': '🏆', 'count': 8},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: mockGifts.length,
      itemBuilder: (context, index) {
        final gift = mockGifts[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFFF69B4).withOpacity(0.1),
                Color(0xFFFF1493).withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Color(0xFFFF69B4).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    gift['emoji'] as String,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gift['name'] as String,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Received ${gift['count']} times',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF69B4), Color(0xFFFF1493)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'x${gift['count']}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMomentsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 60,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'No moments yet',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingBottomActionBar(UserModel user) {
    return Positioned(
      bottom: 25,
      left: 20,
      right: 20,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(35),
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
            ),
            child: Row(
              children: [
                // 🎁 Send Gift Button (Gradient Stroke)
                Expanded(
                  child: GestureDetector(
                    onTap: _showGiftDialog,
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: const Color(0xFFFF69B4), width: 1.5),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.card_giftcard, color: Color(0xFFFF69B4), size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Gift',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // 💬 Message Button (Solid Neon)
                Expanded(
                  child: GestureDetector(
                    onTap: _handleMessage,
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFF69B4), Color(0xFFFF1493)]),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFFFF69B4).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.message_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Message',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // 📞 Call Button (Pulsing Circle)
                GestureDetector(
                  onTap: _showCallDialog,
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFF00E676), Color(0xFF00C853)]), // Green for calls
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 24),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showGiftDialog() {
    debugPrint('[PROFILE_GIFT_DEBUG] 🎁 Opening Gift Dialog for: ${widget.user.name}');
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => GiftsBottomSheet(
        onSendGift: (gift, quantity) async {
          debugPrint('[PROFILE_GIFT_DEBUG] 🎈 onSendGift triggered. Gift: ${gift.name}, Qty: $quantity');
          final userProvider = Provider.of<UserProvider>(context, listen: false);
          final currentUser = userProvider.currentUser;

          if (currentUser == null) {
            debugPrint('[PROFILE_GIFT_DEBUG] ❌ currentUser is NULL. Cannot send gift.');
            return;
          }

          final totalCost = gift.price * quantity;
          debugPrint('[PROFILE_GIFT_DEBUG] 💎 User Balance: ${currentUser.diamonds}, Total Cost: $totalCost');

          if (currentUser.diamonds < totalCost) {
            debugPrint('[PROFILE_GIFT_DEBUG] 🚫 Insufficient balance. User need: $totalCost, has: ${currentUser.diamonds}');
            _showSnackBar('Insufficient diamonds!', Colors.red);
            return;
          }

          debugPrint('[PROFILE_GIFT_DEBUG] 🚀 Calling GiftService.sendGift...');
          final success = await GiftService().sendGift(
            fromUserId: _currentUserId,
            fromUserName: currentUser.name,
            toUserId: widget.user.uid,
            toUserName: widget.user.name,
            gift: gift,
            quantity: quantity,
            context: 'profile',
            contextId: widget.user.uid,
          );

          debugPrint('[PROFILE_GIFT_DEBUG] 🏁 GiftService result: $success');

          if (success) {
            _showSnackBar('Gift sent successfully! 🎁', Colors.green);
          } else {
            _showSnackBar('Failed to send gift. Please try again.', Colors.red);
          }
        },
      ),
    );
  }

  void _handleMessage() async {
    try {
      final chatId = await _databaseService.createOrGetChat(
        user1Id: _currentUserId,
        user2Id: widget.user.uid,
      );
      if (mounted) {
        Navigator.pushNamed(
          context,
          '/chat',
          arguments: {
            'chatId': chatId,
            'otherUser': widget.user,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: $e', Colors.red);
      }
    }
  }

  void _showCallDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFF69B4).withOpacity(0.1),
                Color(0xFFFF1493).withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundImage: NetworkImage(
                  widget.user.photos.isNotEmpty
                      ? widget.user.photos[0]
                      : 'https://ui-avatars.com/api/?name=${widget.user.name}',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Call ${widget.user.name}?',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // 💎 Call Price (Dynamic Stream)
              StreamBuilder<UserModel?>(
                stream: _databaseService.getUserStream(widget.user.uid),
                initialData: widget.user,
                builder: (context, snapshot) {
                  final liveUser = snapshot.data ?? widget.user;
                  if (liveUser.callRate != null && liveUser.callRate! > 0) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF69B4).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '💎 ${liveUser.callRate}/min',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF1493),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              const SizedBox(height: 24),
              // Only Video Call Option
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    // Save navigator and messenger BEFORE any async operations
                    final navigator = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);

                    // Close dialog first
                    navigator.pop();

                    // Create call record in Firestore
                    String? callId;
                    String? errorMessage;

                    try {
                      callId = await _callService.initiateCall(
                        callerId: _currentUserId,
                        callerName: FirebaseAuth.instance.currentUser?.displayName ?? 'User',
                        callerPhoto: FirebaseAuth.instance.currentUser?.photoURL,
                        receiverId: widget.user.uid,
                        receiverName: widget.user.name,
                        receiverPhoto: widget.user.photos.isNotEmpty ? widget.user.photos[0] : null,
                        type: CallType.video,
                      );
                    } catch (e) {
                      errorMessage = e.toString();
                    }

                    // Navigate or show error based on result
                    if (!mounted) return;

                    if (callId != null) {
                      navigator.pushNamed(
                        '/video_call',
                        arguments: {
                          'callId': callId,
                          'otherUser': widget.user,
                          'isOutgoing': true,
                        },
                      );
                    } else if (errorMessage != null) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Failed to initiate call: $errorMessage'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.videocam),
                  label: const Text('Start Video Call'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF1493),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            _buildOptionItem(
              Icons.share,
              'Share Profile',
                  () {
                Navigator.pop(context);
                // TODO: Implement share
              },
            ),
            _buildOptionItem(
              _isBlocked ? Icons.block_flipped : Icons.block,
              _isBlocked ? 'Unblock User' : 'Block User',
                  () {
                Navigator.pop(context);
                _showBlockDialog();
              },
              isDestructive: true,
            ),
            _buildOptionItem(
              Icons.report,
              'Report User',
                  () {
                Navigator.pop(context);
                _showReportDialog();
              },
              isDestructive: true,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionItem(IconData icon, String title, VoidCallback onTap,
      {bool isDestructive = false}) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red : const Color(0xFFFF1493),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : Colors.black,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Future<void> _toggleBlock() async {
    final success = _isBlocked
        ? await _databaseService.unblockUser(
            blockerId: _currentUserId,
            blockedId: widget.user.uid,
          )
        : await _databaseService.blockUser(
            blockerId: _currentUserId,
            blockedId: widget.user.uid,
          );

    if (success) {
      if (mounted) {
        setState(() => _isBlocked = !_isBlocked);
        _showSnackBar(
          _isBlocked ? 'User blocked' : 'User unblocked',
          _isBlocked ? Colors.red : Colors.green,
        );
      }
    } else {
      if (mounted) {
        _showSnackBar('Failed to update block status', Colors.orange);
      }
    }
  }

  void _showBlockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(_isBlocked ? 'Unblock User?' : 'Block User?'),
        content: Text(
          _isBlocked
              ? 'Are you sure you want to unblock ${widget.user.name}?'
              : 'Are you sure you want to block ${widget.user.name}? You won\'t be able to see each other\'s content.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _toggleBlock();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _isBlocked ? Colors.green : Colors.red,
            ),
            child: Text(_isBlocked ? 'Unblock' : 'Block'),
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    
    
    
    

    final reasons = [
      'Spam or Scam',
      'Inappropriate Content',
      'Harassment or Bullying',
      'Fake Profile',
      'Underage User',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.report, color: Colors.red[700]),
            const SizedBox(width: 8),
            const Text(
              'Report User',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Why are you reporting ${widget.user.name}?',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 16),
            ...reasons.map((reason) => InkWell(
              onTap: () async {
                
                Navigator.pop(context);
                await _handleReport(reason);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getReasonIcon(reason),
                      size: 20,
                      color: Colors.red[700],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        reason,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
              ),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              
              Navigator.pop(context);
            },
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getReasonIcon(String reason) {
    

    switch (reason) {
      case 'Spam or Scam':
        return Icons.block;
      case 'Inappropriate Content':
        return Icons.warning;
      case 'Harassment or Bullying':
        return Icons.person_off;
      case 'Fake Profile':
        return Icons.verified_user_outlined;
      case 'Underage User':
        return Icons.child_care;
      case 'Other':
        return Icons.more_horiz;
      default:
        return Icons.report;
    }
  }

  Future<void> _handleReport(String reason) async {
    
    
    
    
    

    try {
      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Submitting report...'),
              ],
            ),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.orange,
          ),
        );
      }

      

      final success = await _databaseService.reportUser(
        reporterId: _currentUserId,
        reportedUserId: widget.user.uid,
        reason: reason,
        description: 'Reported via user profile',
      );

      

      if (success) {
        

        if (mounted) {
          _showSnackBar(
            'Report submitted successfully. We\'ll review it shortly.',
            Colors.green,
          );
        }

        // Optional: Show confirmation dialog
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[700]),
                  const SizedBox(width: 8),
                  const Text('Report Submitted'),
                ],
              ),
              content: const Text(
                'Thank you for helping keep our community safe. We\'ll review this report and take appropriate action.',
                style: TextStyle(fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    
                    Navigator.pop(context);
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        

        if (mounted) {
          _showSnackBar(
            'Failed to submit report. Please try again.',
            Colors.red,
          );
        }
      }
    } catch (e) {
      
      
      

      if (mounted) {
        _showSnackBar(
          'Error submitting report: $e',
          Colors.red,
        );
      }
    }

    
  }
}