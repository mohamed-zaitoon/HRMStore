// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class IntegrityService {
  static const MethodChannel _channel = MethodChannel('tt_android_info');

  // EN: Verifies app integrity to detect tampered/modded builds.
  // AR: تتحقق من سلامة التطبيق لاكتشاف النسخ المعدلة.
  static Future<bool> verify() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }

    try {
      final result = await _channel.invokeMethod<bool>('checkAppIntegrity');
      return result == true;
    } catch (_) {
      // في debug نتجاوز حتى لا نعطّل التطوير.
      return kDebugMode;
    }
  }
}
