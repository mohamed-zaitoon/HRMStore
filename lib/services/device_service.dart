// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceService {
  static const _key = 'device_id';

  // EN: Gets Device Id.
  // AR: تجلب Device Id.
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString(_key);

    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_key, id);
    }

    return id;
  }
}
