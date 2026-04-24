import 'dart:ui';
import 'package:flutter/material.dart';

class PartyRoomHeader extends StatelessWidget {
  final String roomId;
  final String roomName;
  final String hostName;
  final int followersCount;
  final int totalDiamonds;
  final int participantCount;
  final List<Map<String, dynamic>> topContributors;
  final VoidCallback? onInvitePressed;

  const PartyRoomHeader({
    super.key,
    required this.roomId,
    required this.roomName,
    required this.hostName,
    required this.followersCount,
    required this.totalDiamonds,
    required this.participantCount,
    required this.topContributors,
    this.isHost = false, 
    this.isFollowing = false,
    this.onInvitePressed,
    this.onFollowPressed,
    this.onHostTap,
  });

  final bool isHost;
  final bool isFollowing;
  final VoidCallback? onFollowPressed;
  final VoidCallback? onHostTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30), // Floating pill shape
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2), // Transparent dark
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min, // Shrink to fit content
            children: [
              // Host info section
              GestureDetector(
                onTap: onHostTap,
                child: Row(
                  children: [
                    // Host avatar
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withOpacity(0.3),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        backgroundColor: Colors.purple.shade700,
                        child: const Icon(Icons.person, color: Colors.white, size: 20),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Username & Coins
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          hostName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(color: Colors.black45, blurRadius: 2),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Text('💎', style: TextStyle(fontSize: 10)),
                            const SizedBox(width: 3),
                            Text(
                              _formatNumber(totalDiamonds),
                              style: TextStyle(
                                color: Colors.amber.shade300,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Vertical Divider
              Container(width: 1, height: 24, color: Colors.white.withOpacity(0.2)),
              const SizedBox(width: 12),

              // Participant count or Top Contributors could go here
               // For now, keep it simple as requested for "Premium Look" - less clutter
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                 decoration: BoxDecoration(
                   color: Colors.black.withOpacity(0.3),
                   borderRadius: BorderRadius.circular(12),
                 ),
                 child: Row(
                   children: [
                     const Icon(Icons.people, color: Colors.white70, size: 14),
                     const SizedBox(width: 4),
                     Text(
                       '$participantCount',
                       style: const TextStyle(color: Colors.white, fontSize: 11),
                     ),
                   ],
                 ),
               ),

               // FOLLOW BUTTON (Issue 3 Fix)
               if (!isHost && onFollowPressed != null) ...[
                 const SizedBox(width: 8),
                 GestureDetector(
                   onTap: onFollowPressed,
                   child: Container(
                     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                     decoration: BoxDecoration(
                       color: isFollowing ? Colors.white24 : const Color(0xFFFF1493),
                       borderRadius: BorderRadius.circular(15),
                       boxShadow: isFollowing ? [] : [
                         BoxShadow(
                           color: const Color(0xFFFF1493).withOpacity(0.3),
                           blurRadius: 4,
                           offset: const Offset(0, 2),
                         ),
                       ],
                     ),
                     child: Row(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         if (!isFollowing) const Icon(Icons.add, color: Colors.white, size: 12),
                         if (!isFollowing) const SizedBox(width: 2),
                         Text(
                           isFollowing ? 'Following' : 'Follow',
                           style: const TextStyle(
                             color: Colors.white,
                             fontSize: 10,
                             fontWeight: FontWeight.bold,
                           ),
                         ),
                       ],
                     ),
                   ),
                 ),
               ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}