import 'package:flutter/material.dart';
import '../../services/agora_service.dart';

class AgoraVoiceControls extends StatefulWidget {
  final String roomId;
  final bool isHost;
  final VoidCallback? onToggleMute;

  const AgoraVoiceControls({
    super.key,
    required this.roomId,
    this.isHost = false,
    this.onToggleMute,
  });

  @override
  State<AgoraVoiceControls> createState() => _AgoraVoiceControlsState();
}

class _AgoraVoiceControlsState extends State<AgoraVoiceControls>
    with SingleTickerProviderStateMixin {
  final AgoraService _agoraService = AgoraService();
  bool _isMuted = false;
  bool _isSpeaking = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _initializeAgora();
  }

  Future<void> _initializeAgora() async {
    try {
      await _agoraService.initialize();
      _setupAgoraHandlers();
    } catch (e) {
      
    }
  }

  void _setupAgoraHandlers() {
    _agoraService.registerEventHandlers(
      onAudioVolumeIndication: (connection, speakers, speakerNumber, totalVolume) {
        if (mounted) {
          setState(() {
            _isSpeaking = speakers.isNotEmpty && totalVolume > 5;
          });
        }
      },
    );

    _agoraService.enableAudioVolumeIndication();
  }

  Future<void> _toggleMute() async {
    await _agoraService.toggleMute();
    if (mounted) {
      setState(() {
        _isMuted = _agoraService.isMuted;
      });
      widget.onToggleMute?.call();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleMute,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: _isMuted
              ? const LinearGradient(
            colors: [Color(0xFF666666), Color(0xFF444444)],
          )
              : const LinearGradient(
            colors: [Color(0xFFFF1493), Color(0xFFFF69B4)],
          ),
          boxShadow: [
            BoxShadow(
              color: (_isMuted ? Colors.grey : Colors.pink).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Pulse animation when speaking
            if (_isSpeaking && !_isMuted)
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 56 + (_pulseController.value * 20),
                    height: 56 + (_pulseController.value * 20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.pink.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                  );
                },
              ),

            // Microphone icon
            Icon(
              _isMuted ? Icons.mic_off : Icons.mic,
              color: Colors.white,
              size: 26,
            ),
          ],
        ),
      ),
    );
  }
}