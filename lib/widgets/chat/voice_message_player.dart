import 'package:flutter/material.dart';
import '../../services/audio_service.dart';

class VoiceMessagePlayer extends StatefulWidget {
  final String voiceUrl;
  final int duration;
  final bool isMe;
  final AudioService audioService;

  const VoiceMessagePlayer({
    super.key,
    required this.voiceUrl,
    required this.duration,
    required this.isMe,
    required this.audioService,
  });

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  bool _isPlaying = false;
  double _currentPosition = 0;
  double _totalDuration = 1;

  @override
  void initState() {
    super.initState();
    _totalDuration = widget.duration.toDouble();
    _listenToPlayerState();
  }

  void _listenToPlayerState() {
    widget.audioService.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    widget.audioService.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _currentPosition = position.inSeconds.toDouble();
        });
      }
    });

    widget.audioService.durationStream.listen((duration) {
      if (mounted && duration != null) {
        setState(() {
          _totalDuration = duration.inSeconds.toDouble();
        });
      }
    });
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await widget.audioService.pauseAudio();
    } else {
      await widget.audioService.playAudio(widget.voiceUrl);
    }
  }

  String _formatDuration(double seconds) {
    final minutes = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: widget.isMe
            ? const LinearGradient(
          colors: [Color(0xFFFF1493), Color(0xFFFF69B4)],
        )
            : null,
        color: widget.isMe ? null : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause Button
          GestureDetector(
            onTap: _togglePlayPause,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.isMe
                    ? Colors.white.withOpacity(0.3)
                    : const Color(0xFFFF1493).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: widget.isMe ? Colors.white : const Color(0xFFFF1493),
                size: 20,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Waveform
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 30,
                    child: CustomPaint(
                      painter: WaveformPainter(
                        progress: _totalDuration > 0
                            ? _currentPosition / _totalDuration
                            : 0,
                        isPlaying: _isPlaying,
                        color: widget.isMe ? Colors.white : const Color(0xFFFF1493),
                      ),
                      child: Container(),
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                // Duration
                Text(
                  _isPlaying
                      ? '${_formatDuration(_currentPosition)} / ${_formatDuration(_totalDuration)}'
                      : _formatDuration(_totalDuration),
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.isMe ? Colors.white70 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Mic Icon
          Icon(
            Icons.mic,
            size: 16,
            color: widget.isMe ? Colors.white70 : Colors.grey.shade600,
          ),
        ],
      ),
    );
  }
}

// Waveform Painter
class WaveformPainter extends CustomPainter {
  final double progress;
  final bool isPlaying;
  final Color color;

  WaveformPainter({
    required this.progress,
    required this.isPlaying,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const barCount = 30;
    final barWidth = size.width / barCount;
    final paint = Paint()
      ..strokeWidth = barWidth * 0.6
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < barCount; i++) {
      final barProgress = i / barCount;
      final isPlayed = barProgress <= progress;

      paint.color = isPlayed
          ? color
          : color.withOpacity(0.3);

      final barHeight = size.height * (0.3 + (i % 3) * 0.2);
      final x = i * barWidth + barWidth / 2;
      final startY = (size.height - barHeight) / 2;
      final endY = startY + barHeight;

      canvas.drawLine(
        Offset(x, startY),
        Offset(x, endY),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isPlaying != isPlaying;
  }
}

// Player State Enum
enum PlayerState {
  stopped,
  playing,
  paused,
}