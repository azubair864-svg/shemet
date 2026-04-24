import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class CallAudioManager {
  static final CallAudioManager _instance = CallAudioManager._internal();
  factory CallAudioManager() => _instance;
  CallAudioManager._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  /// Start playing the ringtone (for incoming calls)
  Future<void> startRingtone() async {
    if (_isPlaying) return;
    try {
      debugPrint('[AUDIO] 🔔 Starting ringtone...');
      await _player.setReleaseMode(ReleaseMode.loop);
      // Primary: The high-quality remix added by the user
      // Fallback: The standard naming convention
      try {
        await _player.play(AssetSource('audio/iphone-remix-68028.mp3'));
      } catch (_) {
        await _player.play(AssetSource('audio/ringtone.mp3'));
      }
      _isPlaying = true;
    } catch (e) {
      debugPrint('[AUDIO] ❌ Error playing ringtone: $e');
      // If assets missing, we just don't play sound
    }
  }

  /// Start playing the ringback tone (for outgoing calls)
  Future<void> startRingbackTone() async {
    if (_isPlaying) return;
    try {
      debugPrint('[AUDIO] 📞 Starting ringback tone...');
      await _player.setReleaseMode(ReleaseMode.loop);
      // We assume a 'ringback.mp3' exists in assets/audio/
      await _player.play(AssetSource('audio/ringback.mp3'));
      _isPlaying = true;
    } catch (e) {
      debugPrint('[AUDIO] ❌ Error playing ringback: $e');
    }
  }

  /// Play a busy tone when call is rejected
  Future<void> playBusyTone() async {
    try {
      debugPrint('[AUDIO] 📵 Playing busy tone...');
      await stopAll();
      await _player.setReleaseMode(ReleaseMode.release);
      // Try to play 'busy.mp3', fallback to a short burst of the remix if needed
      try {
        await _player.play(AssetSource('audio/busy.mp3'));
      } catch (_) {
        // Fallback or silent
      }
      _isPlaying = true;
    } catch (e) {
      debugPrint('[AUDIO] ❌ Error playing busy tone: $e');
    }
  }

  /// Stop any playing call sounds
  Future<void> stopAll() async {
    if (!_isPlaying) return;
    try {
      debugPrint('[AUDIO] 🔇 Stopping call sounds');
      await _player.stop();
      _isPlaying = false;
    } catch (e) {
      debugPrint('[AUDIO] ❌ Error stopping audio: $e');
    }
  }
}
