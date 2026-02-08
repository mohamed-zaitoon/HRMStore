// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'services/onesignal_service.dart';
import 'services/app_check_service.dart';
import 'services/remote_config_service.dart';
import 'services/theme_service.dart';
import 'app/hrm_store_app.dart';
import 'core/app_info.dart';

// EN: App entry point.
// AR: نقطة بدء التطبيق.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  usePathUrlStrategy();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (!kIsWeb) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  final prefs = await SharedPreferences.getInstance();
  ThemeService.init(prefs);
  final whatsapp = prefs.getString('user_whatsapp') ?? '';
  final isAdmin = prefs.getBool('is_admin') ?? false;
  AppInfo.isAdminApp = isAdmin;

  runApp(HrmStoreApp(prefs: prefs, isAdminApp: isAdmin));

  unawaited(
    _postInit(
      whatsapp: whatsapp,
      isAdmin: isAdmin,
    ),
  );
}

Future<void> _postInit({
  required String whatsapp,
  required bool isAdmin,
}) async {
  await AppCheckService.activate();

  await RemoteConfigService.instance.init();

  await OneSignalService.init();
  await OneSignalService.requestPermission();

  if (whatsapp.isNotEmpty) {
    await OneSignalService.registerUser(whatsapp: whatsapp, isAdmin: isAdmin);
  }
}
