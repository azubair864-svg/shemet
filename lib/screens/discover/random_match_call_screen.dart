import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/call_service.dart';
import '../../services/database_service.dart';
import '../../providers/user_provider.dart';
import '../../widgets/live/gift_picker_sheet.dart';

class RandomMatchCallScreen extends StatefulWidget {
  final String callId;
  final UserModel otherUser;
  final bool isOutgoing;
  final String? token;
  final int ratePerMinute;

  const RandomMatchCallScreen({
    super.key,
    required this.callId,
    required this.otherUser,
    required this.isOutgoing,
    this.token,
    this.ratePerMinute = 1000,
  });

  @override
  State<RandomMatchCallScreen> createState() => _RandomMatchCallScreenState();
}

class _RandomMatchCallScreenState extends State<RandomMatchCallScreen> {
  final CallService _callService = CallService();
  final DatabaseService _databaseService = DatabaseService();
  
  bool _isMasked = true;
  bool _isMuted = false;
  int _seconds = 0;
  Timer? _timer;
  final bool _isMatching = false;
  
  int? _remoteUid;
  bool _remoteUserJoined = false;
  StreamSubscription? _statusSubscription;
  
  // 🕒 Trial states
  int _trialSecondsRemaining = 15; // Standard trial duration

  @override
  void initState() {
    super.initState();
    _initializeCall();
    _listenToCallStatus();
  }

  void _listenToCallStatus() {
    _statusSubscription = _callService.listenToCallStatus(widget.callId).listen((call) {
      if (call == null) return;
      if (call.status == 'rejected' || call.status == 'cancelled' || call.status == 'ended') {
        if (mounted) Navigator.pop(context);
      }
    });
  }

  Future<void> _initializeCall() async {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _seconds++;
          
          // Only countdown trial after user joined
          if (_remoteUserJoined && _trialSecondsRemaining > 0) {
            _trialSecondsRemaining--;
          }
        });
      }
    });

    String agToken = widget.token ?? '';
    if (agToken.isEmpty) {
      try {
        agToken = await _callService.generateAgoraToken(
          channelName: widget.callId,
          uid: 0,
        );
      } catch (e) {
        if (mounted) Navigator.pop(context);
        return;
      }
    }

    await _callService.startVideoCall(
      channelName: widget.callId,
      token: agToken,
      uid: 0,
      onUserJoined: (uid, elapsed) {
        if (mounted) {
          setState(() {
            _remoteUid = uid;
            _remoteUserJoined = true;
          });

          // 💰 Start Per-Minute Billing Ticker (1000 Diamonds/min)
          if (widget.isOutgoing) {
            final currentUser = Provider.of<UserProvider>(context, listen: false).currentUser;
            if (currentUser != null) {
              _callService.startTransactionTicker(
                callId: widget.callId,
                callerId: currentUser.uid,
                receiverId: widget.otherUser.uid,
                ratePerMinute: widget.ratePerMinute, // Dynamic rate
                onInsufficientFunds: () {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Insufficient diamonds! Call ending...'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    _endCall();
                  }
                },
              );
            }
          }
        }
      },
      onUserOffline: (uid, reason) {
        _endCall();
      },
    );
  }

  void _endCall() async {
    _timer?.cancel();
    _callService.stopTransactionTicker(); // Stop billing ticker
    await _callService.endCallWithDuration(
      callId: widget.callId,
      duration: _seconds,
      endReason: 'user_hungup',
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _statusSubscription?.cancel();
    _callService.endCall();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _handleMatchNext() async {
    _timer?.cancel();
    _callService.stopTransactionTicker();
    await _callService.endCallWithDuration(
      callId: widget.callId,
      duration: _seconds,
      endReason: 'match_next',
    );
    if (mounted) Navigator.pop(context, 'match_next');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Remote Video
          if (_remoteUserJoined && _remoteUid != null && _callService.engine != null)
            AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: _callService.engine!,
                canvas: VideoCanvas(uid: _remoteUid!),
                connection: RtcConnection(channelId: widget.callId),
              ),
            )
          else
            _buildHostPlaceholder(),

          // 2. Face Detection Blur Mask
          if (_remoteUserJoined && _isMasked) _buildFaceMaskWithStripes(),

          // 3. UI Overlays
          _buildBottomGradient(),
          SafeArea(child: _buildHeader()),
          
          Positioned(
            top: 140,
            left: 20,
            child: _buildCallOverlays(),
          ),

          // Local Preview
          Positioned(
            top: 100,
            right: 20,
            child: _buildLocalPreview(),
          ),

          // Side Controls
          Positioned(
            right: 12,
            bottom: 220,
            child: _buildSideControls(),
          ),

          // Match Next Button
          Positioned(
            right: 16,
            bottom: 85,
            child: _buildMatchNextButton(),
          ),

          // Monitoring Text
          Positioned(
            left: 16,
            bottom: 75,
            child: _buildMonitoringText(),
          ),

          // Bottom Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 10,
            child: _buildBottomBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildHostPlaceholder() {
    return CachedNetworkImage(
      imageUrl: widget.otherUser.photoURL ?? '',
      fit: BoxFit.cover,
      placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.white)),
      errorWidget: (context, url, error) => Container(color: Colors.grey[900]),
    );
  }

  Widget _buildFaceMaskWithStripes() {
    return Stack(
      children: [
        Container(
          color: Colors.black.withOpacity(0.6),
        ),
        Positioned(top: 250, left: 0, right: 0, child: _buildCautionStripe()),
        Positioned(bottom: 350, left: 0, right: 0, child: _buildCautionStripe()),
        
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.privacy_tip_outlined, color: Colors.white54, size: 40),
              const SizedBox(height: 12),
              const Text(
                'No user face detected.',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'You may find the content disturbing.',
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
              ),
              const SizedBox(height: 30),
              GestureDetector(
                onTap: () => setState(() => _isMasked = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFA726), Color(0xFFFB8C00)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text('Uncover the mask', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCautionStripe() {
    return Container(
      height: 12,
      color: Colors.amber,
      child: Row(
        children: List.generate(20, (i) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: Colors.black,
          ),
        )),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.amber.shade300, width: 0.5),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: CachedNetworkImageProvider(widget.otherUser.photoURL ?? ''),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.otherUser.name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Colors.pinkAccent, Colors.pink]),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('Lv${widget.otherUser.level}', style: const TextStyle(color: Colors.white, fontSize: 8)),
                        ),
                        const SizedBox(width: 4),
                        Text(widget.otherUser.country ?? '', style: const TextStyle(color: Colors.white70, fontSize: 9)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                const Icon(Icons.add_circle, color: Colors.purple, size: 20),
                const SizedBox(width: 4),
              ],
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 30),
            onPressed: _endCall,
          ),
        ],
      ),
    );
  }

  Widget _buildCallOverlays() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _formatTime(_seconds),
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _trialSecondsRemaining > 0 ? Colors.black26 : Colors.red.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _trialSecondsRemaining > 0 
              ? '${widget.ratePerMinute}/min (Free trial ${_trialSecondsRemaining}s)' 
              : '${widget.ratePerMinute}/min (Billing Active)', 
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _buildSideControls() {
    return Column(
      children: [
        _buildCircularBtn(label: 'Hold to talk', icon: Icons.mic_none),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => setState(() => _isMuted = !_isMuted),
          child: _buildCircularBtn(
            icon: _isMuted ? Icons.volume_off : Icons.translate,
            color: _isMuted ? Colors.red.withOpacity(0.5) : Colors.black38,
          ),
        ),
      ],
    );
  }

  Widget _buildMatchNextButton() {
    return GestureDetector(
      onTap: _handleMatchNext,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFBA68C8), Color(0xFFE91E63)]),
          borderRadius: BorderRadius.circular(30),
        ),
        child: const Text('Match Next', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildMonitoringText() {
    return const Text(
      '🤖 Robot is monitoring, nudity and\nunder 18 are forbidden.',
      style: TextStyle(color: Colors.white60, fontSize: 10),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('💬', style: TextStyle(fontSize: 24)),
          Row(
            children: [
              const Text('💎', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 15),
              const Text('🌹', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 15),
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (_) => GiftPickerSheet(streamId: widget.callId, receiverId: widget.otherUser.uid),
                  );
                },
                child: const Text('🎁', style: TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 15),
              const Text('⠿', style: TextStyle(fontSize: 24, color: Colors.white)),
              const SizedBox(width: 20),
              GestureDetector(
                onTap: _endCall,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircularBtn({String? label, required IconData icon, Color? color}) {
    return Column(
      children: [
        if (label != null)
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color ?? Colors.black38, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ],
    );
  }

  Widget _buildLocalPreview() {
    if (_callService.engine == null) return const SizedBox.shrink();
    return Container(
      width: 90,
      height: 130,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AgoraVideoView(
          controller: VideoViewController(
            rtcEngine: _callService.engine!,
            canvas: const VideoCanvas(uid: 0),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomGradient() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      height: 200,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black54, Colors.transparent],
          ),
        ),
      ),
    );
  }
}
