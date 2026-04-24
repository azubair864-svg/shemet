import 'package:audioplayers/audioplayers.dart';
import '../models/gift_model.dart';

/// ⭐⭐⭐ PRODUCTION-READY GIFT SOUND EFFECTS SERVICE ⭐⭐⭐
/// Handles all sound effects for gifts, coins, and notifications
/// Features: Multiple sound categories, volume control, preloading
class GiftSoundService {
  // Singleton instance
  static final GiftSoundService _instance = GiftSoundService._internal();
  factory GiftSoundService() => _instance;
  GiftSoundService._internal();

  // Audio players for different sound types
  final AudioPlayer _giftPlayer = AudioPlayer();
  final AudioPlayer _coinPlayer = AudioPlayer();
  final AudioPlayer _notificationPlayer = AudioPlayer();
  final AudioPlayer _comboPlayer = AudioPlayer();

  // Sound URLs - Using free sound effects
  static const Map<String, String> _soundUrls = {
    // Gift sounds
    'gift_basic': 'https://assets.mixkit.co/active_storage/sfx/2019/2019-preview.mp3',
    'gift_premium': 'https://assets.mixkit.co/active_storage/sfx/2020/2020-preview.mp3',
    'gift_luxury': 'https://assets.mixkit.co/active_storage/sfx/2018/2018-preview.mp3',
    'gift_romantic': 'https://assets.mixkit.co/active_storage/sfx/2017/2017-preview.mp3',

    // Coin sounds
    'coin_receive': 'https://assets.mixkit.co/active_storage/sfx/888/888-preview.mp3',
    'coin_spend': 'https://assets.mixkit.co/active_storage/sfx/889/889-preview.mp3',
    'coin_purchase': 'https://assets.mixkit.co/active_storage/sfx/887/887-preview.mp3',

    // Notification sounds
    'notification': 'https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3',
    'live_start': 'https://assets.mixkit.co/active_storage/sfx/2870/2870-preview.mp3',
    'viewer_join': 'https://assets.mixkit.co/active_storage/sfx/2871/2871-preview.mp3',

    // Combo sounds
    'combo_1': 'https://assets.mixkit.co/active_storage/sfx/270/270-preview.mp3',
    'combo_5': 'https://assets.mixkit.co/active_storage/sfx/271/271-preview.mp3',
    'combo_10': 'https://assets.mixkit.co/active_storage/sfx/272/272-preview.mp3',
    'combo_50': 'https://assets.mixkit.co/active_storage/sfx/273/273-preview.mp3',
    'combo_99': 'https://assets.mixkit.co/active_storage/sfx/274/274-preview.mp3',
  };

  // Settings
  bool _soundEnabled = true;
  double _volume = 0.8;

  /// Initialize the sound service
  Future<void> initialize() async {
    

    try {
      // Set audio context for mobile
      await _giftPlayer.setReleaseMode(ReleaseMode.stop);
      await _coinPlayer.setReleaseMode(ReleaseMode.stop);
      await _notificationPlayer.setReleaseMode(ReleaseMode.stop);
      await _comboPlayer.setReleaseMode(ReleaseMode.stop);

      // Set volume
      await _setAllVolumes(_volume);

      
      
      
      
      
    } catch (e) {
      
      
      
      
    }
  }

  /// Set volume for all players
  Future<void> _setAllVolumes(double volume) async {
    
    await _giftPlayer.setVolume(volume);
    await _coinPlayer.setVolume(volume);
    await _notificationPlayer.setVolume(volume);
    await _comboPlayer.setVolume(volume);
  }

  /// Play gift sound based on gift category and price
  Future<void> playGiftSound(GiftModel gift) async {
    
    
    
    
    

    if (!_soundEnabled) {
      
      
      return;
    }

    try {
      String soundKey;

      // Select sound based on gift category and price
      if (gift.isBigGift) {
        soundKey = 'gift_luxury';
        
      } else if (gift.category == 'romantic') {
        soundKey = 'gift_romantic';
        
      } else if (gift.price >= 1000) {
        soundKey = 'gift_premium';
        
      } else {
        soundKey = 'gift_basic';
        
      }

      final url = _soundUrls[soundKey];
      if (url != null) {
        await _giftPlayer.stop();
        await _giftPlayer.play(UrlSource(url));
        
      } else {
        
      }

      
    } catch (e) {
      
      
      
      
    }
  }

  /// Play combo sound based on combo count
  Future<void> playComboSound(int comboCount) async {
    
    

    if (!_soundEnabled) {
      
      
      return;
    }

    try {
      String soundKey;

      if (comboCount >= 99) {
        soundKey = 'combo_99';
      } else if (comboCount >= 50) {
        soundKey = 'combo_50';
      } else if (comboCount >= 10) {
        soundKey = 'combo_10';
      } else if (comboCount >= 5) {
        soundKey = 'combo_5';
      } else {
        soundKey = 'combo_1';
      }

      

      final url = _soundUrls[soundKey];
      if (url != null) {
        await _comboPlayer.stop();
        await _comboPlayer.play(UrlSource(url));
        
      }

      
    } catch (e) {
      
      
      
      
    }
  }

  /// Play coin sound
  Future<void> playCoinSound({
    required CoinSoundType type,
  }) async {
    
    

    if (!_soundEnabled) {
      
      
      return;
    }

    try {
      String soundKey;

      switch (type) {
        case CoinSoundType.receive:
          soundKey = 'coin_receive';
          break;
        case CoinSoundType.spend:
          soundKey = 'coin_spend';
          break;
        case CoinSoundType.purchase:
          soundKey = 'coin_purchase';
          break;
      }

      

      final url = _soundUrls[soundKey];
      if (url != null) {
        await _coinPlayer.stop();
        await _coinPlayer.play(UrlSource(url));
        
      }

      
    } catch (e) {
      
      
      
      
    }
  }

  /// Play notification sound
  Future<void> playNotificationSound({
    NotificationSoundType type = NotificationSoundType.general,
  }) async {
    
    

    if (!_soundEnabled) {
      
      
      return;
    }

    try {
      String soundKey;

      switch (type) {
        case NotificationSoundType.general:
          soundKey = 'notification';
          break;
        case NotificationSoundType.liveStart:
          soundKey = 'live_start';
          break;
        case NotificationSoundType.viewerJoin:
          soundKey = 'viewer_join';
          break;
      }

      

      final url = _soundUrls[soundKey];
      if (url != null) {
        await _notificationPlayer.stop();
        await _notificationPlayer.play(UrlSource(url));
        
      }

      
    } catch (e) {
      
      
      
      
    }
  }

  /// Enable or disable sound
  void setSoundEnabled(bool enabled) {
    
    
    

    _soundEnabled = enabled;

    if (!enabled) {
      // Stop all playing sounds
      _giftPlayer.stop();
      _coinPlayer.stop();
      _notificationPlayer.stop();
      _comboPlayer.stop();
      
    }

    
  }

  /// Get sound enabled status
  bool get isSoundEnabled => _soundEnabled;

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    
    
    

    _volume = volume.clamp(0.0, 1.0);
    await _setAllVolumes(_volume);

    
  }

  /// Get current volume
  double get volume => _volume;

  /// Dispose all players
  Future<void> dispose() async {
    

    await _giftPlayer.dispose();
    await _coinPlayer.dispose();
    await _notificationPlayer.dispose();
    await _comboPlayer.dispose();

    
    
  }

  /// Play gift received sound (for receiver)
  Future<void> playGiftReceivedSound(GiftModel gift) async {
    
    
    

    if (!_soundEnabled) {
      
      return;
    }

    // Play gift sound + coin receive sound for exciting effect
    await playGiftSound(gift);

    // Small delay then play coin sound
    await Future.delayed(const Duration(milliseconds: 300));
    await playCoinSound(type: CoinSoundType.receive);

    
  }

  /// Play gift sent sound (for sender)
  Future<void> playGiftSentSound(GiftModel gift) async {
    
    
    

    if (!_soundEnabled) {
      
      return;
    }

    // Play gift sound
    await playGiftSound(gift);

    
  }
}

/// Coin sound types
enum CoinSoundType {
  receive,
  spend,
  purchase,
}

/// Notification sound types
enum NotificationSoundType {
  general,
  liveStart,
  viewerJoin,
}
