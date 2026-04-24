import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/audio_service.dart';

class VoiceMessageRecorder extends StatefulWidget {
  final Function(String path, int duration) onRecordingComplete;
  final AudioService audioService;

  const VoiceMessageRecorder({
    super.key,
    required this.onRecordingComplete,
    required this.audioService,
  });

  @override
  State<VoiceMessageRecorder> createState() => _VoiceMessageRecorderState();
}

class _VoiceMessageRecorderState extends State<VoiceMessageRecorder>
    with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  bool _isCancelled = false;
  double _slideOffset = 0;
  Timer? _durationTimer;
  int _duration = 0;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    _durationTimer?.cancel();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final path = await widget.audioService.startRecording();
    if (path != null) {
      setState(() {
        _isRecording = true;
        _duration = 0;
      });

      // Start duration timer
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _duration = widget.audioService.recordingDuration;
          });
        }
      });
    }
  }

  Future<void> _stopRecording() async {
    if (_isCancelled) {
      await widget.audioService.cancelRecording();
    } else {
      final path = await widget.audioService.stopRecording();
      if (path != null) {
        widget.onRecordingComplete(path, _duration);
      }
    }

    _durationTimer?.cancel();
    setState(() {
      _isRecording = false;
      _isCancelled = false;
      _slideOffset = 0;
      _duration = 0;
    });
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _slideOffset += details.delta.dx;
      _slideOffset = _slideOffset.clamp(-150.0, 0.0);
      _isCancelled = _slideOffset < -100;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_isRecording) {
      _stopRecording();
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isRecording) {
      return GestureDetector(
        onLongPressStart: (_) => _startRecording(),
        onLongPressEnd: (_) => _stopRecording(),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF1493), Color(0xFFFF69B4)],
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mic, color: Colors.white, size: 24),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(25),
      ),
      child: GestureDetector(
        onHorizontalDragUpdate: _onHorizontalDragUpdate,
        onHorizontalDragEnd: _onHorizontalDragEnd,
        child: Row(
          children: [
            // Recording animation
            AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                return Row(
                  children: List.generate(3, (index) {
                    final delay = index * 0.3;
                    final value = ((_waveController.value + delay) % 1.0);
                    final height = 20 + (10 * (1 - (value * 2 - 1).abs()));

                    return Container(
                      margin: const EdgeInsets.only(right: 3),
                      width: 3,
                      height: height,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                );
              },
            ),

            const SizedBox(width: 12),

            // Duration
            Text(
              _formatDuration(_duration),
              style: const TextStyle(
                color: Colors.red,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const Spacer(),

            // Slide to cancel
            Transform.translate(
              offset: Offset(_slideOffset, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.chevron_left,
                    color: _isCancelled ? Colors.red : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isCancelled ? 'Release to cancel' : 'Slide to cancel',
                    style: TextStyle(
                      color: _isCancelled ? Colors.red : Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}