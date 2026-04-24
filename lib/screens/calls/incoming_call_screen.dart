import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/call_model.dart';
import '../../services/call_service.dart';
import '../../providers/user_provider.dart';
import '../../models/user_model.dart';
import '../../services/call_audio_manager.dart';
import '../discover/random_match_call_screen.dart';
import 'dart:async';

class IncomingCallScreen extends StatefulWidget {
  final CallModel call;

  const IncomingCallScreen({super.key, required this.call});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  final CallService _callService = CallService();
  final CallAudioManager _audioManager = CallAudioManager();
  bool _isAccepting = false;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _startRinging();
    _startTimeoutTimer();
  }

  void _startTimeoutTimer() {
    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      debugPrint('[CALL_UX] ⏰ Call timed out after 30s');
      _declineCall();
    });
  }

  void _startRinging() {
    _audioManager.startRingtone();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _audioManager.stopAll();
    super.dispose();
  }

  Future<void> _acceptCall() async {
    _timeoutTimer?.cancel();
    _audioManager.stopAll();
    setState(() {
      _isAccepting = true;
    });

    try {
      final currentUser = Provider.of<UserProvider>(context, listen: false).currentUser;
      if (currentUser == null) return;

      // 1. Generate Token
      final token = await _callService.generateAgoraToken(
        channelName: widget.call.callId,
        uid: 0, // 0 for local user
      );

      // 2. Update Status in Firestore
      await _callService.acceptCall(
        callId: widget.call.callId,
        channelId: widget.call.callId,
        agoraToken: token,
      );

      // 3. Navigate to VideoCallScreen
      if (mounted) {
        // Create a temporary UserModel for the caller
        final callerUser = UserModel(
          uid: widget.call.callerId,
          name: widget.call.callerName,
          email: '', // Not needed for call screen
          photoURL: widget.call.callerPhoto,
          photos: widget.call.callerPhoto != null ? [widget.call.callerPhoto!] : [],
          createdAt: DateTime.now(),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RandomMatchCallScreen(
              callId: widget.call.callId,
              token: token,
              otherUser: callerUser,
              isOutgoing: false,
              ratePerMinute: 0, // Receiver doesn't pay
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error accepting call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept call: $e')),
        );
        setState(() {
          _isAccepting = false;
        });
      }
    }
  }

  Future<void> _declineCall() async {
    _timeoutTimer?.cancel();
    _audioManager.stopAll();
    await _callService.rejectCall(widget.call.callId);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _ignoreCall() {
    debugPrint('[CALL_UX] 🤫 Ignoring call (dismissing UI but not rejecting)');
    _timeoutTimer?.cancel();
    _audioManager.stopAll();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image (Blurred Caller Photo)
          if (widget.call.callerPhoto != null)
             Image.network(
                widget.call.callerPhoto!,
                fit: BoxFit.cover,
                color: Colors.black54,
                colorBlendMode: BlendMode.darken,
             ),

          // Ignore Button (Top Right)
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white70, size: 30),
              onPressed: _ignoreCall,
              tooltip: 'Ignore Call',
            ),
          ),

          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               const SizedBox(height: 50),
              // Caller Info
              CircleAvatar(
                radius: 60,
                backgroundImage: widget.call.callerPhoto != null 
                    ? NetworkImage(widget.call.callerPhoto!) 
                    : null,
                child: widget.call.callerPhoto == null 
                    ? const Icon(Icons.person, size: 60) 
                    : null,
              ),
              const SizedBox(height: 20),
              Text(
                widget.call.callerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
               Text(
                'Incoming ${widget.call.type} call...',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                ),
              ),

              const Spacer(),

              // Actions
              Padding(
                padding: const EdgeInsets.only(bottom: 80),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Decline
                    Column(
                      children: [
                        FloatingActionButton(
                          backgroundColor: Colors.red,
                          onPressed: _declineCall,
                          child: const Icon(Icons.call_end, color: Colors.white),
                        ),
                        const SizedBox(height: 10),
                        const Text('Decline', style: TextStyle(color: Colors.white)),
                      ],
                    ),

                    // Accept
                    Column(
                      children: [
                        FloatingActionButton(
                          backgroundColor: Colors.green,
                          onPressed: _isAccepting ? null : _acceptCall,
                          child: _isAccepting 
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Icon(Icons.call, color: Colors.white),
                        ),
                        const SizedBox(height: 10),
                        const Text('Accept', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
