import 'package:just_audio/just_audio.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:async';
import 'dart:io';

class AudioService {
  final RecorderController _recorder = RecorderController();
  final AudioPlayer _audioPlayer = AudioPlayer();

  String? _recordingPath;
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  bool _isRecording = false;
  bool _isPlaying = false;

  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  int get recordingDuration => _recordingDuration;

  Stream<PlayerState> get playerStateStream {
    return _audioPlayer.playerStateStream.map((state) {
      if (state.playing) return PlayerState.playing;
      if (state.processingState == ProcessingState.completed) {
        return PlayerState.stopped;
      }
      return PlayerState.paused;
    });
  }

  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;

  Future<String?> startRecording() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _recordingPath = '${directory.path}/$fileName';

      await _recorder.record(path: _recordingPath);

      _isRecording = true;
      _recordingDuration = 0;

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _recordingDuration++;
      });

      return _recordingPath;
    } catch (e) {
      
      return null;
    }
  }

  Future<String?> stopRecording() async {
    try {
      _recordingTimer?.cancel();
      final path = await _recorder.stop();
      _isRecording = false;
      return path;
    } catch (e) {
      
      return null;
    }
  }

  Future<void> cancelRecording() async {
    try {
      _recordingTimer?.cancel();
      await _recorder.stop();
      _isRecording = false;

      if (_recordingPath != null) {
        final file = File(_recordingPath!);
        if (await file.exists()) await file.delete();
      }
    } catch (e) {
      
    }
  }

  Future<void> playAudio(String url) async {
    try {
      await _audioPlayer.setUrl(url);
      await _audioPlayer.play();
      _isPlaying = true;
    } catch (e) {
      
    }
  }

  Future<void> pauseAudio() async {
    try {
      await _audioPlayer.pause();
      _isPlaying = false;
    } catch (e) {}
  }

  Future<void> stopAudio() async {
    try {
      await _audioPlayer.stop();
      _isPlaying = false;
    } catch (e) {}
  }

  Future<Map<String, dynamic>?> uploadVoiceMessage({
    required String filePath,
    required String chatId,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final ref = FirebaseStorage.instance
          .ref()
          .child('chat_voice')
          .child(chatId)
          .child(fileName);

      final uploadTask = await ref.putFile(file);
      final url = await uploadTask.ref.getDownloadURL();

      await file.delete();

      return {
        'url': url,
        'duration': _recordingDuration,
        'size': await file.length(),
      };
    } catch (e) {
      return null;
    }
  }

  void dispose() {
    _recordingTimer?.cancel();
    _recorder.dispose();
    _audioPlayer.dispose();
  }
}

enum PlayerState {
  stopped,
  playing,
  paused,
}