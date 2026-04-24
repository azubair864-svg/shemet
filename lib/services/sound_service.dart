import 'package:audioplayers/audioplayers.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _isMuted = false;

  Future<void> playGiftSound() async {
    if (_isMuted) return;
    // Add sound file to assets/audio/gift.mp3
    // await _player.play(AssetSource('audio/gift.mp3'));
  }

  Future<void> playJoinSound() async {
    if (_isMuted) return;
    // await _player.play(AssetSource('audio/join.mp3'));
  }

  Future<void> playComboSound() async {
    if (_isMuted) return;
    // await _player.play(AssetSource('audio/combo.mp3'));
  }

  void toggleMute() {
    _isMuted = !_isMuted;
  }

  void dispose() {
    _player.dispose();
  }
}