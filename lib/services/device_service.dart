import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class DeviceService {
  static const String _deviceIdKey = 'shemet_unique_device_id';

  /// Gets the existing unique device ID or generates a new one
  static Future<String> getUniqueId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);

    if (deviceId == null) {
      deviceId = _generateRandomId();
      await prefs.setString(_deviceIdKey, deviceId);
    }

    return deviceId;
  }

  static String _generateRandomId() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
