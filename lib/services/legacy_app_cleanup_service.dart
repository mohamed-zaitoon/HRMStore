// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class LegacyAppInfo {
  final String packageName;
  final String label;

  const LegacyAppInfo({
    required this.packageName,
    required this.label,
  });
}

class LegacyAppCleanupService {
  static const MethodChannel _channel = MethodChannel('tt_android_info');
  static final ValueNotifier<int> cleanupDialogClosed = ValueNotifier(0);

  static const LegacyAppInfo _legacyUser = LegacyAppInfo(
    packageName: 'com.mohamedzaitoon.tiktokcoin',
    label: 'نسخة المستخدم القديمة',
  );
  static const LegacyAppInfo _legacyAdmin = LegacyAppInfo(
    packageName: 'com.mohamedzaitoon.tiktokcoin.admin',
    label: 'نسخة الأدمن القديمة',
  );

  static const List<LegacyAppInfo> _legacyApps = [_legacyUser, _legacyAdmin];
  static List<LegacyAppInfo> get legacyApps => _legacyApps;

  static Future<List<LegacyAppInfo>> detectInstalled() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const [];
    }

    final List<LegacyAppInfo> installed = [];
    for (final app in _legacyApps) {
      final isInstalled = await _isPackageInstalled(app.packageName);
      if (isInstalled) {
        installed.add(app);
      }
    }
    return installed;
  }

  static Future<void> requestUninstall(String packageName) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<bool>(
        'requestUninstallPackage',
        {'packageName': packageName},
      );
    } catch (_) {
      // Ignore; the OS may block uninstall intents on some devices.
    }
  }

  static void notifyCleanupDialogClosed() {
    cleanupDialogClosed.value++;
  }

  static Future<bool> _isPackageInstalled(String packageName) async {
    try {
      final bool? ok = await _channel.invokeMethod<bool>(
        'isPackageInstalled',
        {'packageName': packageName},
      );
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }
}
