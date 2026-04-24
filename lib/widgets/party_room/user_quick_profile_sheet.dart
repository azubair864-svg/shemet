import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/database_service.dart';
import '../../models/user_model.dart';
import '../../widgets/live/gift_picker_sheet.dart';

class UserQuickProfileSheet extends StatefulWidget {
  final String userId;
  final String roomId;
  final bool isHost;
  final int? seatIndex;
  final VoidCallback? onBlock;
  final VoidCallback? onKick;

  const UserQuickProfileSheet({
    super.key,
    required this.userId,
    required this.roomId,
    this.isHost = false,
    this.seatIndex,
    this.onBlock,
    this.onKick,
  });

  @override
  State<UserQuickProfileSheet> createState() => _UserQuickProfileSheetState();
}

class _UserQuickProfileSheetState extends State<UserQuickProfileSheet> {
  final DatabaseService _databaseService = DatabaseService();
  UserModel? _user;
  bool _isLoading = true;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await _databaseService.getUserById(widget.userId);

      if (user != null && mounted) {
        setState(() {
          _user = user;
          _isLoading = false;
        });

        // Check if following
        _checkFollowStatus();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkFollowStatus() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final isFollowing = await _databaseService.isFollowingUser(
      followerId: currentUserId,
      followingId: widget.userId,
    );

    if (mounted) {
      setState(() => _isFollowing = isFollowing);
    }
  }

  Future<void> _toggleFollow() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final success = await _databaseService.toggleFollow(
      followerId: currentUserId,
      followingId: widget.userId,
    );

    if (success && mounted) {
      setState(() => _isFollowing = !_isFollowing);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF2D1B69),
            Color(0xFF1A0F3D),
          ],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: _isLoading
          ? const Center(
        child: CircularProgressIndicator(color: Colors.white),
      )
          : _user == null
          ? const Center(
        child: Text(
          'User not found',
          style: TextStyle(color: Colors.white),
        ),
      )
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Profile photo
          _buildProfilePhoto(),

          const SizedBox(height: 16),

          // Name and age
          _buildNameAndAge(),

          const SizedBox(height: 8),

          // Level and VIP badge
          _buildLevelBadge(),

          const SizedBox(height: 20),

          // Stats
          _buildStats(),

          const SizedBox(height: 20),

          // Action buttons
          _buildActionButtons(),

          // Host controls (if host)
          if (widget.isHost) _buildHostControls(),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildProfilePhoto() {
    final photoUrl = _user!.photos.isNotEmpty ? _user!.photos[0] : null;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow effect
        Container(
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                (_user!.isVip ?? false) ? Colors.amber : Colors.purple,
                Colors.transparent,
              ],
            ),
          ),
        ),

        // Photo
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: (_user!.isVip ?? false) ? Colors.amber : Colors.purple.shade300,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: (_user!.isVip ?? false)
                    ? Colors.amber.withValues(alpha: 0.5)
                    : Colors.purple.withValues(alpha: 0.3),
                blurRadius: 15,
                spreadRadius: 3,
              ),
            ],
          ),
          child: ClipOval(
            child: photoUrl != null
                ? CachedNetworkImage(
              imageUrl: photoUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey.shade800,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey.shade800,
                child: Center(
                  child: Text(
                    _user!.name[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            )
                : Container(
              color: Colors.grey.shade800,
              child: Center(
                child: Text(
                  _user!.name[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNameAndAge() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _user!.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${_user!.age}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildLevelBadge() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Country flag
        Text(
          _getCountryFlag(_user!.country),
          style: const TextStyle(fontSize: 20),
        ),

        const SizedBox(width: 8),

        // Level
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.purple.shade700,
                Colors.purple.shade900,
              ],
            ),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.purple.shade300, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '⭐',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(width: 4),
              Text(
                'Level ${_user!.level}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // VIP badge
        if (_user!.isVip ?? false) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.amber, width: 1),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('💎', style: TextStyle(fontSize: 14)),
                SizedBox(width: 4),
                Text(
                  'VIP',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStats() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Diamonds', '${_user!.diamonds}', '💎'),
          _buildStatItem('Level', '${_user!.level}', '⭐'),
          _buildStatItem('Gender', (_user!.gender?.toLowerCase() == 'male') ? 'Male' : 'Female', (_user!.gender?.toLowerCase() == 'male') ? '♂️' : '♀️'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, String emoji) {
    return Column(
      children: [
        Text(
          emoji,
          style: const TextStyle(fontSize: 24),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // View Full Profile button
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Navigate to full profile
                Navigator.pushNamed(
                  context,
                  '/user-profile-detail',
                  arguments: {'userId': widget.userId},
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'View Profile',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Follow/Unfollow button
          Expanded(
            child: ElevatedButton(
              onPressed: _toggleFollow,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isFollowing ? Colors.grey.shade700 : const Color(0xFFFF1493),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isFollowing ? Icons.check : Icons.person_add,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isFollowing ? 'Following' : 'Follow',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Gift button
          GestureDetector(
            onTap: _openGifts,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.card_giftcard, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  void _openGifts() {
    Navigator.pop(context); // Close profile sheet
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GiftPickerSheet(
        streamId: widget.roomId,
        receiverId: widget.userId,
        context: 'party_room',
        seatIndex: widget.seatIndex,
      ),
    );
  }

  Widget _buildHostControls() {
    return Container(
      margin: const EdgeInsets.only(top: 20, left: 20, right: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            'Host Controls',
            style: TextStyle(
              color: Colors.red.shade300,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          // Invite to Mic Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _inviteToMic,
              icon: const Icon(Icons.mic, color: Colors.white),
              label: const Text('Invite to Mic'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              // Kick button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onKick?.call();
                  },
                  icon: const Icon(Icons.exit_to_app, size: 18),
                  label: const Text('Kick'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Block button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onBlock?.call();
                  },
                  icon: const Icon(Icons.block, size: 18),
                  label: const Text('Block'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getCountryFlag(String? countryCode) {
    // Handle null country code
    if (countryCode == null || countryCode.isEmpty) {
      return '🌍';
    }

    final Map<String, String> flags = {
      'LK': '🇱🇰', 'US': '🇺🇸', 'IN': '🇮🇳', 'GB': '🇬🇧', 'AU': '🇦🇺',
      'CA': '🇨🇦', 'JP': '🇯🇵', 'CN': '🇨🇳', 'KR': '🇰🇷', 'PK': '🇵🇰',
      'BD': '🇧🇩', 'AE': '🇦🇪', 'SA': '🇸🇦', 'FR': '🇫🇷', 'DE': '🇩🇪',
      'IT': '🇮🇹', 'ES': '🇪🇸', 'BR': '🇧🇷', 'MX': '🇲🇽', 'RU': '🇷🇺',
    };
    return flags[countryCode.toUpperCase()] ?? '🌍';
  }

  Future<void> _inviteToMic() async {
    final host = await _databaseService.getUserById(FirebaseAuth.instance.currentUser?.uid ?? '');
    final success = await _databaseService.inviteUserToMic(
      roomId: widget.roomId,
      userId: widget.userId,
      hostName: host?.name ?? 'Host',
    );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Invitation sent to ${widget.userId}' : 'Failed to send invitation'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }
}