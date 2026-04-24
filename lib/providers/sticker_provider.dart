import 'package:flutter/material.dart';
import '../services/agora_service.dart';

enum StickerCategory {
  basic,
  animal,
  cool,
  premium,
}

class Sticker {
  final String id;
  final String name;
  final String thumbnailAsset; // Path to thumbnail image
  final String? deepArAsset;   // Path to .deepar file (nullable if not downloaded)
  final int requiredLevel;     // 0 = Free
  final StickerCategory category;
  bool isDownloaded;

  Sticker({
    required this.id,
    required this.name,
    required this.thumbnailAsset,
    this.deepArAsset,
    required this.requiredLevel,
    required this.category,
    this.isDownloaded = false,
  });

  bool get isLocked => requiredLevel > 0; // Simple check, actual logic compares with user level
}

class StickerProvider with ChangeNotifier {
  // Mock User Level (In real app, get from UserProvider)
  int _currentUserLevel = 1; 
  int get currentUserLevel => _currentUserLevel;

  Sticker? _activeSticker;
  Sticker? get activeSticker => _activeSticker;

  // Mock Data
  final List<Sticker> _stickers = [
    // --- FREE / BASIC ---
    Sticker(
      id: 's1', 
      name: 'Bling', 
      thumbnailAsset: 'assets/images/stickers/bling_thumb.png', 
      deepArAsset: 'Bling', 
      requiredLevel: 0, 
      category: StickerCategory.basic,
      isDownloaded: true,
    ),
    Sticker(
      id: 's2', 
      name: 'Whiskers', 
      thumbnailAsset: 'assets/images/stickers/whiskers_thumb.png', 
      deepArAsset: 'Whiskers', 
      requiredLevel: 0, 
      category: StickerCategory.basic,
      isDownloaded: true,
    ),
    Sticker(
      id: 's3', 
      name: 'Bunny', 
      thumbnailAsset: 'assets/images/stickers/bunny_thumb.png', 
      deepArAsset: 'Bunny', 
      requiredLevel: 0, 
      category: StickerCategory.animal,
      isDownloaded: true,
    ),
    Sticker(
      id: 's4', 
      name: 'Baby Face', 
      thumbnailAsset: 'assets/images/stickers/baby_thumb.png', 
      deepArAsset: 'BabyFace', 
      requiredLevel: 0, 
      category: StickerCategory.basic,
      isDownloaded: true,
    ),
    
    // --- LEVEL LOCKED ---
    Sticker(
      id: 's5', 
      name: 'Cool Shades', 
      thumbnailAsset: 'assets/images/stickers/shades_thumb.png', 
      deepArAsset: 'CoolShades', 
      requiredLevel: 4, 
      category: StickerCategory.cool
    ),
    Sticker(
      id: 's6', 
      name: 'Cyber Mask', 
      thumbnailAsset: 'assets/images/stickers/cyber_thumb.png', 
      deepArAsset: 'CyberMask', 
      requiredLevel: 5, 
      category: StickerCategory.cool
    ),
    Sticker(
      id: 's7', 
      name: 'Golden Crown', 
      thumbnailAsset: 'assets/images/stickers/crown_thumb.png', 
      deepArAsset: 'GoldenCrown', 
      requiredLevel: 6, 
      category: StickerCategory.premium
    ),
    Sticker(
      id: 's8', 
      name: 'Neon Tiger', 
      thumbnailAsset: 'assets/images/stickers/tiger_thumb.png', 
      deepArAsset: 'NeonTiger', 
      requiredLevel: 8, 
      category: StickerCategory.premium
    ),
  ];

  List<Sticker> get stickers => _stickers;

  // Actions
  void setActiveSticker(Sticker? sticker) {
    _activeSticker = sticker;
    
    // Call Agora Service to apply
    // If sticker is null, we pass null to reset to beauty base
    AgoraService().setSticker(sticker?.deepArAsset);
    
    notifyListeners();
  }

  void downloadSticker(String id) {
    final index = _stickers.indexWhere((s) => s.id == id);
    if (index != -1) {
      // Create new instance with downloaded = true
      // In real app, this would await file download
      Sticker original = _stickers[index];
      _stickers[index] = Sticker(
        id: original.id,
        name: original.name,
        thumbnailAsset: original.thumbnailAsset,
        deepArAsset: original.deepArAsset,
        requiredLevel: original.requiredLevel,
        category: original.category,
        isDownloaded: true,
      );
      notifyListeners();
    }
  }

  // Debug method to simulate leveling up
  void setMockLevel(int level) {
    _currentUserLevel = level;
    notifyListeners();
  }
}
