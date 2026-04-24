import 'package:flutter/material.dart';
import '../../models/call_model.dart';
import '../../services/call_audio_manager.dart';
import '../../services/call_service.dart';
import '../../providers/user_provider.dart';
import '../../models/user_model.dart';
import 'video_call_screen.dart';
import 'voice_call_screen.dart';
import '../../main.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:ui';

class CallNotificationBanner extends StatefulWidget {
  final CallModel call;
  final VoidCallback onDismiss;

  const CallNotificationBanner({
    super.key,
    required this.call,
    required this.onDismiss,
  });

  @override
  State<CallNotificationBanner> createState() => _CallNotificationBannerState();
}

class _CallNotificationBannerState extends State<CallNotificationBanner>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _pulseController;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _pulseAnimation;
  
  final CallAudioManager _audioManager = CallAudioManager();
  final CallService _callService = CallService();
  bool _isActionTaken = false;
  Timer? _timeoutTimer;
  late Future<String> _tokenFuture;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // EAGER TOKEN GENERATION: Start fetching token while the phone is still ringing
    _tokenFuture = _callService.generateAgoraToken(
      channelName: widget.call.callId,
      uid: 0,
    );

    _controller.forward();
    _audioManager.startRingtone();
    _startTimeoutTimer();
  }

  void _startTimeoutTimer() {
    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      if (!_isActionTaken) {
        _declineCall();
      }
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _controller.dispose();
    _pulseController.dispose();
    _audioManager.stopAll();
    super.dispose();
  }

  Future<void> _acceptCall() async {
    if (_isActionTaken) return;
    setState(() => _isActionTaken = true);
    
    _audioManager.stopAll();
    _timeoutTimer?.cancel();

    try {
      final currentUser = Provider.of<UserProvider>(context, listen: false).currentUser;
      if (currentUser == null) {
        return;
      }

      // 1. Prepare data BEFORE any awaits/side effects to survive unmounting
      final callerUser = UserModel(
        uid: widget.call.callerId,
        name: widget.call.callerName,
        email: '',
        photoURL: widget.call.callerPhoto,
        photos: widget.call.callerPhoto != null ? [widget.call.callerPhoto!] : [],
        createdAt: DateTime.now(),
      );

      // 2. Fetch the eagerly started token (will be near-instant if user took a few seconds to answer)
      final token = await _tokenFuture;
      
      // 3. Perform accepting call (This will trigger unmount via GlobalCallListener)
      await _callService.acceptCall(
        callId: widget.call.callId,
        channelId: widget.call.callId,
        agoraToken: token,
      );

      // 3. Perform navigation via global navigatorKey to survive banner unmounting
      final route = MaterialPageRoute(
        builder: (_) => widget.call.type == CallType.video
            ? VideoCallScreen(
                callId: widget.call.callId,
                otherUser: callerUser,
                isOutgoing: false,
                channelId: widget.call.callId,
                token: token,
                callRate: 0,
              )
            : VoiceCallScreen(
                callId: widget.call.callId,
                otherUser: callerUser,
                isOutgoing: false,
              ),
      );

      MyApp.navigatorKey.currentState?.push(route);

      // Dismiss the banner locally as well (if still alive)
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismiss());
      }
    } catch (e) {
      debugPrint('❌ FATAL ERROR in acceptCall: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _isActionTaken = false);
      }
    }
  }

  Future<void> _declineCall() async {
    if (_isActionTaken) return;
    setState(() => _isActionTaken = true);

    _audioManager.stopAll();
    _timeoutTimer?.cancel();
    
    await _callService.rejectCall(widget.call.callId);
    
    if (mounted) {
      _controller.reverse().then((_) => widget.onDismiss());
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine screen width and safe area
    final screenWidth = MediaQuery.of(context).size.width;
    final topPadding = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        Positioned(
          top: topPadding + 10,
          left: 12,
          right: 12,
          child: SlideTransition(
            position: _offsetAnimation,
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onVerticalDragUpdate: (details) {
                  if (details.delta.dy < -10) _declineCall();
                },
                child: Container(
                  width: screenWidth - 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFF121212).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            // Caller Avatar (Pulsing)
                            _buildPulsingAvatar(),
                            const SizedBox(width: 12),
                            
                            // Info Section (Compact & Flexible)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.call.callerName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Incoming ${widget.call.type == CallType.video ? "Video" : "Voice"} call...',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(width: 8),
                            
                            // Actions (Minimalist Circular)
                            _buildCallAction(
                              icon: Icons.close,
                              color: Colors.redAccent.withOpacity(0.85),
                              onTap: _declineCall,
                            ),
                            const SizedBox(width: 10),
                            _buildCallAction(
                              icon: Icons.call,
                              color: Colors.greenAccent.withOpacity(0.85),
                              pulse: true,
                              onTap: _acceptCall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPulsingAvatar() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.pinkAccent.withOpacity(_pulseAnimation.value - 1.0 > 0 ? (_pulseAnimation.value - 1.0) * 5 : 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.pinkAccent.withOpacity(0.2),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
            image: widget.call.callerPhoto != null
                ? DecorationImage(
                    image: NetworkImage(widget.call.callerPhoto!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: widget.call.callerPhoto == null
              ? const Icon(Icons.person, color: Colors.white, size: 24)
              : null,
        );
      },
    );
  }

  Widget _buildCallAction({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool pulse = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (pulse)
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  width: 40 + (10 * (_pulseAnimation.value - 1)),
                  height: 40 + (10 * (_pulseAnimation.value - 1)),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.3 * (1.2 - _pulseAnimation.value)),
                  ),
                );
              },
            ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}
