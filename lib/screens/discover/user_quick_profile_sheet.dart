import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import 'random_match_call_screen.dart';
import '../messages/chat_screen.dart';
import '../../widgets/live/gift_picker_sheet.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/user_provider.dart';

class UserQuickProfileSheet extends StatefulWidget {
  final UserModel user;

  const UserQuickProfileSheet({super.key, required this.user});

  static Future<void> show(BuildContext context, UserModel user) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UserQuickProfileSheet(user: user),
    );
  }

  @override
  State<UserQuickProfileSheet> createState() => _UserQuickProfileSheetState();
}

class _UserQuickProfileSheetState extends State<UserQuickProfileSheet> {
  final DatabaseService _dbService = DatabaseService();
  bool _isFollowing = false;
  int _currentPhotoIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _checkFollowStatus();
  }

  Future<void> _checkFollowStatus() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;
    
    try {
      final isFollowing = await _dbService.isFollowing(followerId: currentUserId, followingId: widget.user.uid);
      if (mounted) {
         debugPrint('[SOCIAL_DEBUG] UserQuickProfileSheet: _checkFollowStatus = $isFollowing (for ${widget.user.name})');
         setState(() {
           _isFollowing = isFollowing;
         });
       }
     } catch (e) {
       debugPrint('Error checking follow status: $e');
     }
  }

  Future<void> _toggleFollow() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;
    
    try {
      if (_isFollowing) {
        await _dbService.unfollowUser(followerId: currentUserId, followingId: widget.user.uid);
      } else {
        final currentUser = context.read<UserProvider>().currentUser;
        await _dbService.followUser(
          followerId: currentUserId, 
          followingId: widget.user.uid,
          followerName: currentUser?.name ?? 'Someone',
        );
      }
      if (mounted) {
        debugPrint('[SOCIAL_DEBUG] UserQuickProfileSheet: _toggleFollow toggled to ${!_isFollowing}');
        setState(() {
          _isFollowing = !_isFollowing;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isFollowing ? 'Followed ${widget.user.name}' : 'Unfollowed ${widget.user.name}')),
      );
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update follow status')),
      );
    }
  }

  void _initiateCall(UserModel liveUser) {
     Navigator.pop(context); // close sheet
     Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RandomMatchCallScreen(
          callId: 'direct_${liveUser.uid}_${DateTime.now().millisecondsSinceEpoch}',
          otherUser: liveUser,
          isOutgoing: true,
          ratePerMinute: liveUser.callRate ?? 1000,
        ),
      ),
    );
  }

  void _openChat() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    // Use deterministic chat ID: callerId_receiverId (sorted)
    final ids = [currentUserId, widget.user.uid]..sort();
    final chatId = '${ids[0]}_${ids[1]}';

    Navigator.pop(context); // close sheet
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          chatId: chatId,
          otherUser: widget.user,
        ),
      ),
    );
  }

  void _openGifts() {
     Navigator.pop(context); // Close profile sheet first
     showModalBottomSheet(
       context: context,
       isScrollControlled: true,
       backgroundColor: Colors.transparent,
       builder: (context) => GiftPickerSheet(
         streamId: 'direct_${widget.user.uid}',
         receiverId: widget.user.uid,
       ),
     );
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFFFF1493); 
    final height = MediaQuery.of(context).size.height * 0.75;

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2C), // Dark base
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: StreamBuilder<UserModel?>(
        stream: _dbService.getUserStream(widget.user.uid),
        initialData: widget.user,
        builder: (context, snapshot) {
          final liveUser = snapshot.data ?? widget.user;
          return Stack(
            children: [
               // 1. Photos Carousel
               Positioned(
                  top: 0, left: 0, right: 0,
                  height: height * 0.55,
                  child: ClipRRect(
                     borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                     child: liveUser.photos.isNotEmpty 
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                               PageView.builder(
                                   controller: _pageController,
                                   itemCount: liveUser.photos.length,
                                   onPageChanged: (index) => setState(() => _currentPhotoIndex = index),
                                   itemBuilder: (context, index) {
                                      return CachedNetworkImage(
                                         imageUrl: liveUser.photos[index],
                                         fit: BoxFit.cover,
                                      );
                                   }
                               ),
                               // Gradient overlay for smooth transition to bottom info
                               Container(
                                  decoration: const BoxDecoration(
                                     gradient: LinearGradient(
                                         begin: Alignment.topCenter,
                                         end: Alignment.bottomCenter,
                                         colors: [Colors.black54, Colors.transparent, Color(0xFF1E1E2C)],
                                         stops: [0.0, 0.5, 1.0]
                                     )
                                  ),
                               ),
                               // Page Indicators
                               if (liveUser.photos.length > 1)
                                 Positioned(
                                    top: 20,
                                    left: 0, right: 0,
                                    child: Row(
                                       mainAxisAlignment: MainAxisAlignment.center,
                                       children: List.generate(liveUser.photos.length, (index) => Container(
                                           margin: const EdgeInsets.symmetric(horizontal: 4),
                                           width: _currentPhotoIndex == index ? 24 : 8,
                                           height: 4,
                                           decoration: BoxDecoration(
                                               color: _currentPhotoIndex == index ? themeColor : Colors.white54,
                                               borderRadius: BorderRadius.circular(2)
                                           ),
                                       )),
                                    )
                                 )
                            ],
                        )
                        : Container(color: Colors.grey[900], child: const Center(child: Icon(Icons.person, size: 100, color: Colors.white54))),
                  )
               ),

               // 2. Info Block (Overlapping Photo)
               Positioned(
                  left: 20, right: 20,
                  top: height * 0.45,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Row(
                         crossAxisAlignment: CrossAxisAlignment.end,
                         children: [
                            Text(
                               liveUser.name,
                               style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.black54, blurRadius: 10)])
                            ),
                            const SizedBox(width: 8),
                            Text('${liveUser.age ?? 21}', style: const TextStyle(color: Colors.white70, fontSize: 22, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            const Icon(Icons.verified, color: Colors.blueAccent, size: 24),
                         ],
                       ),
                       const SizedBox(height: 8),
                       Row(
                         children: [
                            Text(liveUser.countryFlag, style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 12),
                            Container(
                               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                               decoration: BoxDecoration(
                                   gradient: const LinearGradient(colors: [Color(0xFFFF1493), Color(0xFFFF69B4)]),
                                   borderRadius: BorderRadius.circular(12)
                               ),
                               child: Text('Lv${liveUser.level}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                            if (liveUser.isHost == true) ...[
                               const SizedBox(width: 8),
                               Container(
                                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                   decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber)),
                                   child: const Row(
                                     children: [
                                         Icon(Icons.star, color: Colors.amber, size: 12),
                                         SizedBox(width: 4),
                                         Text('HOST', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                                     ],
                                   ),
                               )
                            ],
                            const SizedBox(width: 8),
                            // 💎 LIVE PRICE
                            Container(
                               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                               decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12)),
                               child: Row(
                                 children: [
                                     const Icon(Icons.diamond, color: Colors.yellow, size: 12),
                                     const SizedBox(width: 4),
                                     Text('${liveUser.callRate ?? 1200}/min', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                 ],
                               ),
                            )
                         ],
                       )
                    ],
                  )
               ),

               // 3. Action Buttons
               Positioned(
                  bottom: 30, left: 20, right: 20,
                  child: Row(
                     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                     children: [
                        // Follow
                        _buildActionButton(
                           icon: _isFollowing ? Icons.favorite : Icons.favorite_border,
                           color: _isFollowing ? Colors.redAccent : Colors.white,
                           bg: _isFollowing ? Colors.redAccent.withOpacity(0.2) : Colors.white10,
                           onTap: _toggleFollow,
                           label: _isFollowing ? 'Following' : 'Follow'
                        ),
                        // Message
                        _buildActionButton(
                           icon: Icons.chat_bubble_rounded,
                           color: Colors.blueAccent,
                           bg: Colors.blueAccent.withOpacity(0.2),
                           onTap: _openChat,
                           label: 'Message'
                        ),
                        // Gift
                        _buildActionButton(
                           icon: Icons.card_giftcard,
                           color: Colors.amber,
                           bg: Colors.amber.withOpacity(0.2),
                           onTap: _openGifts,
                           label: 'Gift'
                        ),
                        // Call
                        _buildActionButton(
                           icon: Icons.videocam,
                           color: Colors.white,
                           bg: themeColor, // Solid bg for primary action
                           onTap: () => _initiateCall(liveUser),
                           label: 'Call'
                        ),
                     ],
                  )
               )
            ],
          );
        }
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required Color color, required Color bg, required VoidCallback onTap, required String label}) {
     return GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
             Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                   color: bg,
                   shape: BoxShape.circle,
                   boxShadow: bg.opacity == 1.0 ? [BoxShadow(color: bg.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4))] : null
                ),
                child: Icon(icon, color: color, size: 28),
             ),
             const SizedBox(height: 8),
             Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        )
     );
  }
}
