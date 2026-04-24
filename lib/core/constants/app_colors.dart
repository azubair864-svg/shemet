import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors - Pink Theme
  static const Color primary = Color(0xFFFF69B4); // Hot Pink
  static const Color primaryDark = Color(0xFFFF1493); // Deep Pink
  static const Color primaryLight = Color(0xFFFFB6C1); // Light Pink

  // Secondary Colors
  static const Color secondary = Color(0xFF9C27B0); // Purple
  static const Color accent = Color(0xFFFF8C00); // Orange

  // Background Colors
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBg = Color(0xFFFFFFFF);

  // Text Colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFF9E9E9E);
  static const Color textWhite = Color(0xFFFFFFFF);

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFF44336);
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Color(0xFF2196F3);

  // Special Colors
  static const Color online = Color(0xFFFF69B4); // Pink for online status
  static const Color offline = Color(0xFF9E9E9E);
  static const Color verified = Color(0xFF2196F3);

  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFF69B4), Color(0xFFFF1493)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient callButtonGradient = LinearGradient(
    colors: [Color(0xFFFF69B4), Color(0xFFFF8C00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkOverlay = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x00000000), Color(0x99000000)],
  );

  // Shadow
  static const Color shadowColor = Color(0x1A000000);

  // Divider
  static const Color divider = Color(0xFFE0E0E0);

  // Transparent Colors
  static Color blackTransparent(double opacity) => Colors.black.withOpacity(opacity);
  static Color whiteTransparent(double opacity) => Colors.white.withOpacity(opacity);
  static Color pinkTransparent(double opacity) => const Color(0xFFFF69B4).withOpacity(opacity);
}