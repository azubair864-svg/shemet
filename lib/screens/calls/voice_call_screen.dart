import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/call_service.dart';
import '../../models/user_model.dart';
import '../../models/call_model.dart';
import '../../services/call_audio_manager.dart';

class VoiceCallScreen extends StatefulWidget {
  final String callId;
  final UserModel otherUser;
  final bool isOutgoing;

  const VoiceCallScreen({
    super.key,
    required this.callId,
    required this.otherUser,
    this.isOutgoing = true,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  final CallService _callService = CallService();
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isConnected = false;
  Timer? _durationTimer;
  int _callDuration = 0;
  StreamSubscription? _statusSubscription;
  String? _overrideStatus;

  @override
  void initState() {
    super.initState();
    _initializeCall();
    _listenToCallStatus();
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
      
      // Play busy tone
      CallAudioManager().playBusyTone();
      
      // Auto-exit after 2 seconds
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  // Helper to get audio manager if needed, or just import it

  Future<void> _initializeCall() async {
    await _callService.initialize();

    // Generate token
    final token = await _callService.generateAgoraToken(
      channelName: widget.callId,
      uid: widget.otherUser.uid.hashCode,
    );

    // Start voice call
    final success = await _callService.startVoiceCall(
      channelName: widget.callId,
      token: token,
      uid: widget.otherUser.uid.hashCode,
      onUserJoined: (uid, elapsed) {
        setState(() => _isConnected = true);
        _startDurationTimer();
      },
      onUserOffline: (uid, reason) {
        _endCall();
      },
    );

    if (!success && mounted) {
      Navigator.pop(context);
    }
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _callDuration++);
      }
    });
  }

  Future<void> _endCall() async {
    _durationTimer?.cancel();

    // End the Agora call
    await _callService.endCall();

    // Update Firestore call record
    await _callService.endCallWithDuration(
      callId: widget.callId,
      duration: _callDuration,
    );

    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _toggleMute() async {
    await _callService.toggleMute();
    setState(() => _isMuted = _callService.isMuted);
  }

  void _toggleSpeaker() async {
    await _callService.toggleSpeaker();
    setState(() => _isSpeakerOn = _callService.isSpeakerOn);
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _durationTimer?.cancel();
    _callService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2D1B69), Color(0xFF1A0F3D)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Status
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  _overrideStatus ?? (_isConnected ? 'Connected' : 'Calling...'),
                  style: TextStyle(
                    color: _overrideStatus != null ? Colors.redAccent : Colors.white70,
                    fontSize: 16,
                    fontWeight: _overrideStatus != null ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),

              const Spacer(),

              // User Avatar
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  backgroundImage: widget.otherUser.photos.isNotEmpty
                      ? NetworkImage(widget.otherUser.photos[0])
                      : null,
                  child: widget.otherUser.photos.isEmpty
                      ? Text(
                    widget.otherUser.name[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                      : null,
                ),
              ),

              const SizedBox(height: 30),

              // User Name
              Text(
                widget.otherUser.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              // Call Duration
              Text(
                _formatDuration(_callDuration),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                ),
              ),

              const Spacer(),

              // Control Buttons
              Padding(
                padding: const EdgeInsets.all(40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Speaker
                    _buildControlButton(
                      icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                      label: 'Speaker',
                      onTap: _toggleSpeaker,
                      isActive: _isSpeakerOn,
                    ),

                    // Mute
                    _buildControlButton(
                      icon: _isMuted ? Icons.mic_off : Icons.mic,
                      label: 'Mute',
                      onTap: _toggleMute,
                      isActive: _isMuted,
                    ),

                    // End Call
                    _buildControlButton(
                      icon: Icons.call_end,
                      label: 'End',
                      onTap: _endCall,
                      color: Colors.red,
                      size: 80,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    Color? color,
    double size = 64,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color ??
                  (isActive
                      ? Colors.white.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.2)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: size * 0.4,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}