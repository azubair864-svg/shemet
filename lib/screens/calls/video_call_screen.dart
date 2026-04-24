import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'dart:ui';

import '../../services/call_service.dart';
import '../../services/database_service.dart';
import '../../models/user_model.dart';
import '../../models/call_model.dart';
import '../../services/call_audio_manager.dart';
import '../../providers/user_provider.dart';
import '../../widgets/live/gift_picker_sheet.dart';
import '../../widgets/party_room/beauty_effects_panel.dart';
import '../../services/gift_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VideoCallScreen extends StatefulWidget {
  final String callId;
  final UserModel otherUser;
  final bool isOutgoing;
  final String? channelId;
  final String? token;
  final int callRate; // Diamonds per minute

  const VideoCallScreen({
    super.key,
    required this.callId,
    required this.otherUser,
    this.isOutgoing = true,
    this.channelId,
    this.token,
    this.callRate = 0,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final CallService _callService = CallService();
  final DatabaseService _databaseService = DatabaseService();
  final bool _isCameraOff = false;
  int _callDurationSeconds = 0;
  Timer? _durationTimer;
  bool _remoteUserJoined = false;
  int? _remoteUid;
  StreamSubscription? _statusSubscription;
  String? _overrideStatus;
  bool _isFollowing = false;
  bool _showChat = false;
  final TextEditingController _chatController = TextEditingController();
  
  // Session Earnings State
  double _sessionEarnings = 0.0;
  StreamSubscription? _giftSubscription;
  double _giftTotalEarnings = 0.0;
  final GiftService _giftService = GiftService();

  @override
  void initState() {
    super.initState();
    _initializeCall();
    _listenToCallStatus();
    _checkFollowingStatus();
  }

  Future<void> _checkFollowingStatus() async {
    final currentUserId = Provider.of<UserProvider>(context, listen: false).currentUser?.uid;
    if (currentUserId == null) return;
    
    final isFollowing = await _databaseService.isFollowingUser(
      followerId: currentUserId,
      followingId: widget.otherUser.uid,
    );
    
    if (mounted) {
      setState(() {
        _isFollowing = isFollowing;
      });
    }
  }

  Future<void> _toggleFollow() async {
    final currentUserId = Provider.of<UserProvider>(context, listen: false).currentUser?.uid;
    if (currentUserId == null) return;

    final success = await _databaseService.toggleFollow(
      followerId: currentUserId,
      followingId: widget.otherUser.uid,
    );

    if (success && mounted) {
      setState(() {
        _isFollowing = !_isFollowing;
      });
    }
  }

  void _sendChatMessage() {
    if (_chatController.text.trim().isEmpty) return;

    final currentUser = Provider.of<UserProvider>(context, listen: false).currentUser;
    if (currentUser == null) return;

    FirebaseFirestore.instance
        .collection('video_calls')
        .doc(widget.callId)
        .collection('messages')
        .add({
      'senderId': currentUser.uid,
      'senderName': currentUser.name,
      'text': _chatController.text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
    });

    _chatController.clear();
  }

  void _listenToCallStatus() {
    _statusSubscription = _callService.listenToCallStatus(widget.callId).listen((call) {
      if (call == null) return;
      
      if (call.status == CallStatus.rejected) {
        _handleCallRejected();
      } else if (call.status == CallStatus.cancelled) {
        if (mounted) Navigator.pop(context);
      }
    });
  }

  void _handleCallRejected() async {
    if (mounted) {
      setState(() {
        _overrideStatus = 'User Busy / Declined';
      });
      
      CallAudioManager().playBusyTone();
      
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  Future<void> _initializeCall() async {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDurationSeconds++;
          
          // Update Earnings from Duration
          if (!widget.isOutgoing && widget.callRate > 0) {
            _sessionEarnings = (_callDurationSeconds / 60.0) * (widget.callRate * 0.60) + _giftTotalEarnings;
          }
        });
      }
    });

    // Listen for Gifts real-time if receiving
    if (!widget.isOutgoing) {
      _giftSubscription = _giftService.streamGiftTransactions(contextId: widget.callId).listen((gifts) {
        if (!mounted) return;
        
        double totalGiftPoints = 0;
        for (var gift in gifts) {
          totalGiftPoints += (gift['pointsEarned'] ?? 0).toDouble();
        }

        setState(() {
          _giftTotalEarnings = totalGiftPoints;
          _sessionEarnings = (_callDurationSeconds / 60.0) * (widget.callRate * 0.60) + _giftTotalEarnings;
        });
      });
    }

    String channelName = widget.channelId ?? widget.callId;
    String agToken = widget.token ?? '';
    
    if (agToken.isEmpty) {
      try {
        agToken = await _callService.generateAgoraToken(
          channelName: channelName, 
          uid: 0 
        );
      } catch (e) {
        debugPrint('Error generating token: $e');
        if (mounted) Navigator.pop(context);
        return;
      }
    }

    await _callService.startVideoCall(
      channelName: channelName,
      token: agToken,
      uid: 0,
      onUserJoined: (uid, elapsed) {
        if (mounted) {
          setState(() {
            _remoteUid = uid;
            _remoteUserJoined = true;
          });
        }
      },
      onUserOffline: (uid, reason) {
        _onCallEnded('Remote user left');
      },
    );

    if (widget.isOutgoing && widget.callRate > 0) {
      if (!mounted) return;
      final currentUser = Provider.of<UserProvider>(context, listen: false).currentUser;
      if (currentUser != null) {
        _callService.startTransactionTicker(
          callId: widget.callId,
          callerId: currentUser.uid,
          receiverId: widget.otherUser.uid,
          ratePerMinute: widget.callRate,
          onInsufficientFunds: () {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Insufficient diamonds! Call ending...')),
              );
              _onCallEnded('insufficient_funds');
            }
          },
        );
      }
    }
  }

  Future<void> _onCallEnded(String reason) async {
    _durationTimer?.cancel();
    _callService.stopTransactionTicker();
    await _callService.endCallWithDuration(
      callId: widget.callId,
      duration: _callDurationSeconds,
      endReason: reason,
    );
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _switchCamera() async {
    await _callService.switchCamera();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _durationTimer?.cancel();
    _giftSubscription?.cancel();
    _callService.stopTransactionTicker();
    _callService.endCall();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final int min = seconds ~/ 60;
    final int sec = seconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const BeautyEffectsPanel(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final revenueText = widget.isOutgoing 
        ? '-${widget.callRate}/min' 
        : '+${(widget.callRate * 0.60).floor()}/min';

    final revenueColor = widget.isOutgoing ? Colors.redAccent : Colors.greenAccent;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          if (_remoteUserJoined && _remoteUid != null && _callService.engine != null)
            Positioned.fill(
              child: AgoraVideoView(
                controller: VideoViewController.remote(
                  rtcEngine: _callService.engine!,
                  canvas: VideoCanvas(uid: _remoteUid!),
                  connection: RtcConnection(channelId: widget.channelId ?? widget.callId),
                ),
              ),
            )
          else
            _buildConnectingUI(),

          Positioned(
            top: 60,
            left: 20,
            child: SingleChildScrollView( 
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                   Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          _formatDuration(_callDurationSeconds),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (widget.callRate > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: revenueColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            widget.isOutgoing ? Icons.remove_circle_outline : Icons.diamond,
                            color: revenueColor, 
                            size: 16
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.isOutgoing 
                              ? revenueText 
                              : 'Tokens: ${_sessionEarnings.floor()}',
                            style: TextStyle(
                              color: revenueColor, 
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          Positioned(
            top: 60,
            right: 20,
            child: GestureDetector(
              onTap: _toggleFollow,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: _isFollowing 
                    ? LinearGradient(colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)])
                    : const LinearGradient(colors: [Color(0xFFFF1493), Color(0xFFFF69B4)]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: _isFollowing ? [] : [
                    BoxShadow(color: const Color(0xFFFF1493).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      _isFollowing ? Icons.check : Icons.add_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isFollowing ? 'Following' : 'Follow',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            left: 16,
            bottom: 120,
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.6,
              height: 200,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('video_calls')
                    .doc(widget.callId)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .limit(20)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  
                  final messages = snapshot.data!.docs;
                  
                  return ListView.builder(
                    reverse: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index].data() as Map<String, dynamic>;
                      final isMe = msg['senderId'] == Provider.of<UserProvider>(context, listen: false).currentUser?.uid;
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black38,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${msg['senderName']}: ',
                                    style: TextStyle(
                                      color: isMe ? Colors.blueAccent : Colors.orangeAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  TextSpan(
                                    text: msg['text'] ?? '',
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),

          Positioned(
            right: 20,
            bottom: 150,
            child: SizedBox(
              width: 100,
              height: 150,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: _callService.engine!,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton(
                  heroTag: 'chat_btn',
                  mini: true,
                  backgroundColor: _showChat ? Colors.white : Colors.black45,
                  onPressed: () => setState(() => _showChat = !_showChat),
                  child: Icon(Icons.chat_bubble_outline_rounded, color: _showChat ? Colors.black : Colors.white),
                ),

                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA000)]),
                    shape: BoxShape.circle,
                  ),
                  child: FloatingActionButton(
                    heroTag: 'gift_btn',
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        builder: (_) => GiftPickerSheet(
                          streamId: widget.callId,
                          receiverId: widget.otherUser.uid,
                        ),
                      );
                    },
                    child: const Text('🎁', style: TextStyle(fontSize: 22)),
                  ),
                ),

                FloatingActionButton(
                  heroTag: 'end_call_btn',
                  backgroundColor: Colors.red,
                  onPressed: () => _onCallEnded('user_hangup'),
                  child: const Icon(Icons.call_end, color: Colors.white),
                ),

                FloatingActionButton(
                  heroTag: 'filter_btn',
                  mini: true,
                  backgroundColor: Colors.black45,
                  onPressed: _showFilters,
                  child: const Icon(Icons.face_retouching_natural_rounded, color: Colors.white),
                ),

                 FloatingActionButton(
                  heroTag: 'switch_cam_btn',
                  mini: true,
                  backgroundColor: Colors.black45,
                  onPressed: _switchCamera,
                  child: const Icon(Icons.cameraswitch, color: Colors.white),
                ),
              ],
            ),
          ),

          if (_showChat)
            Positioned(
              bottom: 110,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _chatController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(color: Colors.white38),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (val) => _sendChatMessage(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.blueAccent),
                      onPressed: _sendChatMessage,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConnectingUI() {
    final photoUrl = widget.otherUser.photos.isNotEmpty ? widget.otherUser.photos.first : '';
    
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 🖼️ Blurred Background Photo
          CachedNetworkImage(
            imageUrl: photoUrl,
            fit: BoxFit.cover,
            errorWidget: (context, url, error) => Container(color: Colors.black),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(color: Colors.black.withOpacity(0.55)),
          ),
          
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 👤 Pulsing Avatar
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 1.0, end: 1.15),
                  duration: const Duration(seconds: 1),
                  curve: Curves.easeInOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFFF1493).withOpacity(0.5), width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF1493).withOpacity(0.35),
                              blurRadius: 30,
                              spreadRadius: 10,
                            )
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 55,
                          backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                          child: photoUrl.isEmpty ? const Icon(Icons.person, size: 50, color: Colors.white) : null,
                        ),
                      ),
                    );
                  },
                  onEnd: () {}, // Not used but could be for looping if needed
                ),
                const SizedBox(height: 32),
                
                // ⏳ Status Text
                Text(
                  widget.otherUser.name,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _overrideStatus ?? 'Connecting...',
                  style: TextStyle(
                    color: _overrideStatus != null ? Colors.redAccent : Colors.white70, 
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
                
                const SizedBox(height: 60),
                const CircularProgressIndicator(color: Color(0xFFFF1493), strokeWidth: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
