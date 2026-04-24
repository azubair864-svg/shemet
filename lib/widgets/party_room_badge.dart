import 'package:flutter/material.dart';

class PartyRoomBadge extends StatelessWidget {
  final String type; // 'level', 'vip', 'host', 'achievement', 'rank'
  final dynamic value; // Level number, achievement name, etc.
  final bool showGlow;
  final double size;

  const PartyRoomBadge({
    super.key,
    required this.type,
    required this.value,
    this.showGlow = true,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case 'level':
        return _buildLevelBadge();
      case 'vip':
        return _buildVipBadge();
      case 'host':
        return _buildHostBadge();
      case 'achievement':
        return _buildAchievementBadge();
      case 'rank':
        return _buildRankBadge();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildLevelBadge() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size * 0.3,
        vertical: size * 0.15,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF9B6FD7), Color(0xFFFF69B4)],
        ),
        borderRadius: BorderRadius.circular(size * 0.4),
        border: Border.all(color: Colors.white, width: 1),
        boxShadow: showGlow
            ? [
          BoxShadow(
            color: const Color(0xFF9B6FD7).withOpacity(0.5),
            blurRadius: size * 0.3,
            spreadRadius: 1,
          ),
        ]
            : null,
      ),
      child: Text(
        'Lv$value',
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          shadows: const [
            Shadow(
              color: Colors.black45,
              offset: Offset(0.5, 0.5),
              blurRadius: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVipBadge() {
    final int vipLevel = value as int? ?? 1;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size * 0.25,
        vertical: size * 0.1,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getVipColor(vipLevel),
            _getVipColor(vipLevel).withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: showGlow
            ? [
          BoxShadow(
            color: _getVipColor(vipLevel).withOpacity(0.6),
            blurRadius: size * 0.4,
            spreadRadius: 2,
          ),
        ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium,
            color: Colors.white,
            size: size * 0.5,
          ),
          SizedBox(width: size * 0.1),
          Text(
            'VIP$vipLevel',
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.35,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Color _getVipColor(int level) {
    if (level >= 10) return const Color(0xFFFFD700); // Gold
    if (level >= 5) return const Color(0xFF9B6FD7); // Purple
    return const Color(0xFFFF69B4); // Pink
  }

  Widget _buildHostBadge() {
    return Container(
      padding: EdgeInsets.all(size * 0.15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: showGlow
            ? [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.6),
            blurRadius: size * 0.5,
            spreadRadius: 2,
          ),
        ]
            : null,
      ),
      child: Text(
        '👑',
        style: TextStyle(fontSize: size * 0.5),
      ),
    );
  }

  Widget _buildAchievementBadge() {
    final String achievementName = value as String? ?? '';
    final achievementIcon = _getAchievementIcon(achievementName);

    return Container(
      padding: EdgeInsets.all(size * 0.15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF8C00), Color(0xFFFF6347)],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: showGlow
            ? [
          BoxShadow(
            color: const Color(0xFFFF8C00).withOpacity(0.5),
            blurRadius: size * 0.3,
            spreadRadius: 1,
          ),
        ]
            : null,
      ),
      child: Text(
        achievementIcon,
        style: TextStyle(fontSize: size * 0.5),
      ),
    );
  }

  String _getAchievementIcon(String name) {
    if (name.contains('gift') || name.contains('spender')) return '🎁';
    if (name.contains('star') || name.contains('popular')) return '⭐';
    if (name.contains('diamond') || name.contains('rich')) return '💎';
    if (name.contains('crown') || name.contains('king')) return '👑';
    if (name.contains('fire') || name.contains('hot')) return '🔥';
    if (name.contains('heart') || name.contains('love')) return '❤️';
    return '🏆';
  }

  Widget _buildRankBadge() {
    final int rank = value as int? ?? 1;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size * 0.25,
        vertical: size * 0.15,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _getRankGradient(rank),
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: showGlow
            ? [
          BoxShadow(
            color: _getRankGradient(rank)[0].withOpacity(0.5),
            blurRadius: size * 0.4,
            spreadRadius: 1,
          ),
        ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _getRankEmoji(rank),
            style: TextStyle(fontSize: size * 0.4),
          ),
          SizedBox(width: size * 0.1),
          Text(
            '#$rank',
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.4,
              fontWeight: FontWeight.bold,
              shadows: const [
                Shadow(
                  color: Colors.black45,
                  offset: Offset(0.5, 0.5),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _getRankGradient(int rank) {
    switch (rank) {
      case 1:
        return [const Color(0xFFFFD700), const Color(0xFFFFA500)]; // Gold
      case 2:
        return [const Color(0xFFC0C0C0), const Color(0xFF808080)]; // Silver
      case 3:
        return [const Color(0xFFCD7F32), const Color(0xFF8B4513)]; // Bronze
      default:
        return [const Color(0xFF9B6FD7), const Color(0xFFFF69B4)]; // Purple
    }
  }

  String _getRankEmoji(int rank) {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '⭐';
    }
  }
}