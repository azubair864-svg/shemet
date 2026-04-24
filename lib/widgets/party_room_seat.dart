// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';

import '../../models/seat_model.dart';
import 'party_room/premium_seat_frame.dart';
import 'party_room/sound_wave_widget.dart';

class PartyRoomSeat extends StatefulWidget {
  final SeatModel seat;
  final bool isHost;
  final VoidCallback? onTap;
  final int? diamonds;
  final bool showDetails;
  final bool showBadges;
  final String? theme;
  final UserModel? user; 
  final bool isSpeaking;
  final String? roomType; // Added
  final Function(bool)? onVideoToggle; // Added
  final Function(bool)? onMicToggle; // Added

  const PartyRoomSeat({
    super.key,
    required this.seat,
    this.user,
    this.isHost = false,
    this.onTap,
    this.diamonds,
    this.showDetails = true,
    this.showBadges = true,
    this.theme,
    this.isSpeaking = false,
    this.roomType,
    this.onVideoToggle,
    this.onMicToggle, // Added
  });

  @override
  State<PartyRoomSeat> createState() => _PartyRoomSeatState();
}

class _PartyRoomSeatState extends State<PartyRoomSeat>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _rankController;

  late Animation<double> _glowPulse;
  late Animation<double> _rankScale;

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _glowPulse = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _rankController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _rankScale = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _rankController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    _rankController.dispose();
    super.dispose();
  }

  Color _getThemeColor() {
    switch (widget.theme?.toLowerCase()) {
      case 'pink':
        return const Color(0xFFFF69B4);
      case 'blue':
        return const Color(0xFF2196F3);
      case 'orange':
        return const Color(0xFFFF9800);
      case 'green':
        return const Color(0xFF4CAF50);
      case 'gaming':
        return const Color(0xFF00FFFF);
      case 'romantic':
        return const Color(0xFFFF6B9D);
      case 'party':
        return const Color(0xFFFF00FF);
      case 'chat':
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF9B6FD7);
    }
  }

  String _formatDiamonds(int diamonds) {
    if (diamonds >= 1000000) return '${(diamonds / 1000000).toStringAsFixed(1)}M';
    if (diamonds >= 1000) return '${(diamonds / 1000).toStringAsFixed(1)}K';
    return diamonds.toString();
  }

  String _getCountryFlag(String countryCode) {
    final Map<String, String> flags = {
      'LK': '🇱🇰',
      'US': '🇺🇸',
      'IN': '🇮🇳',
      'GB': '🇬🇧',
      'AU': '🇦🇺',
      'CA': '🇨🇦',
      'JP': '🇯🇵',
      'CN': '🇨🇳',
      'KR': '🇰🇷',
      'PK': '🇵🇰',
      'BD': '🇧🇩',
      'AE': '🇦🇪',
      'SA': '🇸🇦',
      'FR': '🇫🇷',
      'DE': '🇩🇪',
      'IT': '🇮🇹',
      'ES': '🇪🇸',
      'BR': '🇧🇷',
      'MX': '🇲🇽',
      'RU': '🇷🇺',
    };
    return flags[countryCode.toUpperCase()] ?? '🌍';
  }

  int _getRank() {
    if (widget.diamonds == null || widget.diamonds! < 1000) return 0;
    if (widget.diamonds! >= 100000) return 1;
    if (widget.diamonds! >= 50000) return 2;
    if (widget.diamonds! >= 10000) return 3;
    if (widget.diamonds! >= 5000) return 4;
    return 0;
  }


  @override
  Widget build(BuildContext context) {
    // Debug logging for seat rendering
    

    if (widget.seat.index == 0) {
       debugPrint('[DEBUG_UI] 🪑 Seat 0: isOccupied=${widget.seat.isOccupied}, showBadges=${widget.showBadges}, roomType=${widget.roomType}, onVideoToggle=${widget.onVideoToggle != null}');
    }

    if (!widget.showDetails) {
      return _buildSimpleSeat();
    }

    return GestureDetector(
      onTap: () {
        debugPrint('[HIT_DEBUG] 🛑 SEAT TAPPED! (Seat: ${widget.seat.index})');
        widget.onTap?.call();
      },
      child: _buildEnhancedSeat(),
    );
  }

  Widget _buildEnhancedSeat() {
    final isOccupied = widget.seat.isOccupied;
    final rank = _getRank();
    final themeColor = _getThemeColor();

    return FutureBuilder<UserModel?>(
      future: widget.user != null
          ? Future.value(widget.user)
          : (widget.seat.userId != null
                ? DatabaseService().getUserById(widget.seat.userId!)
                : null),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final photoUrl = user?.photos.isNotEmpty == true ? user!.photos[0] : null;
        final userName = user?.name ?? 'User';
        final userCountry = user?.country ?? 'LK';

        return SizedBox(
          width: 110,
          height: 145,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // 1. Audio Visualizer (Underlay)
              if (isOccupied && widget.isSpeaking)
                Positioned(
                  top: 20,
                  child: SoundWaveWidget(
                    isSpeaking: widget.isSpeaking,
                    color: themeColor,
                    size: 110,
                  ),
                ),

              // 2. Main Premium Seat Frame
              Positioned(
                top: 20, 
                child: PremiumSeatFrame(
                  isOccupied: isOccupied,
                  rank: rank,
                  themeColor: themeColor,
                  isSpeaking: widget.isSpeaking,
                  isVideoOn: widget.seat.isVideoOn,
                  size: 85,
                  child: _buildAvatarContent(isOccupied, photoUrl, userName),
                ),
              ),

              // 4. Corner Badges & Controls
              if (widget.showBadges) ...[
                 // ID Badge (Top Left - Red Marker)
                 Positioned(
                   top: 22, left: 16,
                   child: _buildIdBadge(),
                 ),

                  // Video Toggle (Top Right - Green Marker)
                 if (isOccupied && widget.roomType != 'audio')
                   Positioned(
                     top: 18, right: 12,
                     child: _buildVideoToggle(), // Modified: Left slightly
                   ),
 
                 // Country Flag (Bottom Left - Blue Marker)
                 if (isOccupied)
                   Positioned(
                     top: 83, left: 12,
                     child: _buildCountryBadge(userCountry),
                   ),
 
                 // Mic Toggle (Bottom Right - Yellow Marker)
                 if (isOccupied && widget.roomType != 'audio')
                   Positioned(
                     top: 85, right: 8,
                     child: _buildMicToggle(),
                   ),
              ],
 
              // 5. Bottom Status (Diamonds)
              if (isOccupied && widget.diamonds != null && widget.diamonds! > 0)
                Positioned(
                  bottom: 0, 
                  child: _buildDiamondsDisplay(widget.diamonds!),
                ),
 
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatarContent(bool isOccupied, String? photoUrl, String userName) {
    if (widget.seat.isVideoOn) {
      return const SizedBox.expand(); // ABSOLUTE NOTHINGNESS
    }

    return isOccupied
      ? (photoUrl != null
          ? CachedNetworkImage(
              imageUrl: photoUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              placeholder: (context, url) => Container(
                color: Colors.white.withOpacity(0.1),
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white54),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => _buildInitials(userName),
            )
          : _buildInitials(userName))
      : Center(
          child: Icon(
            Icons.add,
            color: Colors.white.withOpacity(0.3),
            size: 28,
          ),
        );
  }

  Widget _buildInitials(String name) {
    return Container(
      color: Colors.white.withOpacity(0.1),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildIdBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.transparent, // Removed black background
        borderRadius: BorderRadius.circular(4),
      ),
      child: widget.isHost
          ? const Icon(Icons.star, color: Colors.amber, size: 12) // Slightly larger star
          : Text(
              '${widget.seat.index + 1}',
              style: const TextStyle(
                color: Colors.white, 
                fontSize: 12, // Larger font
                fontWeight: FontWeight.bold,
                shadows: [Shadow(color: Colors.black, blurRadius: 4)], // Added shadow for visibility
              ),
            ),
    );
  }

  Widget _buildCountryBadge(String country) {
     return Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.transparent, // Removed black background
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          _getCountryFlag(country), 
          style: const TextStyle(
            fontSize: 14, // Larger flag
            shadows: [Shadow(color: Colors.black, blurRadius: 4)], // Added shadow
          ),
        ),
     );
  }

  Widget _buildVideoToggle() {
    final bool canToggleVideo = widget.onVideoToggle != null;

    if (canToggleVideo) {
      return _buildControlButton(
        isOn: widget.seat.isVideoOn,
        onIcon: Icons.videocam,
        offIcon: Icons.videocam_off,
        onTap: () {
          debugPrint('[DEEP_HIT] 🎯 VIDEO TOGGLE TAP! Seat: ${widget.seat.index}');
          widget.onVideoToggle!(!widget.seat.isVideoOn);
        },
      );
    } else if (widget.seat.isVideoOn) {
      return _buildStatusIcon(
        isOn: true,
        icon: Icons.videocam,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildMicToggle() {
    if (widget.onMicToggle != null) {
      return _buildControlButton(
        isOn: !widget.seat.isSelfMuted, // "On" means NOT muted
        onIcon: Icons.mic,
        offIcon: Icons.mic_off,
        onTap: () {
          debugPrint('[DEEP_HIT] 🎯 MIC TOGGLE TAP! Seat: ${widget.seat.index}');
          widget.onMicToggle!(!widget.seat.isSelfMuted);
        },
      );
    } else if (widget.seat.isSelfMuted || widget.seat.isMutedByHost) {
      return _buildStatusIcon(
        isOn: false,
        icon: Icons.mic_off,
      );
    }
    // Default: Show unmuted status icon if nothing else
    return _buildStatusIcon(
      isOn: true,
      icon: Icons.mic,
    );
  }

  Widget _buildControlButton({
    required bool isOn,
    required IconData onIcon,
    required IconData offIcon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4), // Visible touch area
        decoration: BoxDecoration(
          color: Colors.transparent, // Removed black background
          borderRadius: BorderRadius.circular(6),
          // Removed border
        ),
        child: Icon(
          isOn ? onIcon : offIcon,
          color: Colors.white,
          size: 16, // Larger icon
          shadows: const [Shadow(color: Colors.black, blurRadius: 4)], // Added shadow
        ),
      ),
    );
  }

  Widget _buildStatusIcon({
    required bool isOn,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.transparent, // Removed black background
        borderRadius: BorderRadius.circular(6),
        // Removed border
      ),
      child: Icon(
        icon, 
        color: Colors.white, 
        size: 16, // Larger icon
        shadows: const [Shadow(color: Colors.black, blurRadius: 4)], // Added shadow
      ),
    );
  }

  Widget _buildRankingBadge(int rank) {
    String emoji;
    Color bgColor;

    switch (rank) {
      case 1:
        emoji = '🥇';
        bgColor = Colors.amber;
        break;
      case 2:
        emoji = '🥈';
        bgColor = Colors.grey.shade300;
        break;
      case 3:
        emoji = '🥉';
        bgColor = Colors.orange.shade700;
        break;
      case 4:
        emoji = '4️⃣';
        bgColor = Colors.blue.shade400;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Positioned(
      top: 10,
      right: -5,
      child: AnimatedBuilder(
        animation: _rankScale,
        builder: (context, child) {
          return Transform.scale(
            scale: _rankScale.value,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [bgColor, bgColor.withOpacity(0.8)],
                ),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: bgColor.withOpacity(0.6),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 14)),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDiamondsDisplay(int diamonds) {
    return AnimatedBuilder(
      animation: _glowPulse,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withOpacity(_glowPulse.value * 0.8),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withOpacity(_glowPulse.value * 0.5),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💎', style: TextStyle(fontSize: 10)),
              const SizedBox(width: 3),
              Text(
                _formatDiamonds(diamonds),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 2)],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSimpleSeat() {
    final themeColor = _getThemeColor();
    final isOccupied = widget.seat.isOccupied;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 85,
        height: 85,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: (isOccupied && !widget.seat.isVideoOn)
              ? LinearGradient(
                  colors: [themeColor, themeColor.withOpacity(0.7)],
                )
              : null,
          color: (isOccupied && !widget.seat.isVideoOn) 
              ? null 
              : Colors.transparent, // Explicitly transparent for video
          boxShadow: (isOccupied && !widget.seat.isVideoOn)
              ? [
                  BoxShadow(
                    color: themeColor.withOpacity(0.5),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Container(
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: isOccupied
                ? (widget.seat.isVideoOn ? Colors.transparent : Colors.purple.shade700)
                : Colors.grey.shade700.withOpacity(0.5),
          ),
          child: Center(
            child: isOccupied
                ? const Icon(Icons.person, color: Colors.white, size: 32)
                : (widget.seat.isLocked
                      ? const Icon(Icons.lock, color: Colors.white54, size: 28)
                      : Icon(
                          Icons.add,
                          color: Colors.white.withOpacity(0.3),
                          size: 28,
                        )),
          ),
        ),
      ),
    );
  }

}
