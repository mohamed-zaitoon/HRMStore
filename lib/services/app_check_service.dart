// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

class AppCheckService {
  static const String webRecaptchaSiteKey =
      String.fromEnvironment('WEB_RECAPTCHA_SITE_KEY');

  // EN: Activates Firebase App Check.
  // AR: تفعيل Firebase App Check.
  static Future<void> activate() async {
    if (kIsWeb && webRecaptchaSiteKey.isEmpty) {
      return;
    }

    final androidProvider =
        kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity;

    final webProvider = kIsWeb
        ? ReCaptchaV3Provider(webRecaptchaSiteKey)
        : null;

    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: androidProvider,
        webProvider: webProvider,
      );
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('AppCheck activate failed: $e');
      }
    }
  }
}
