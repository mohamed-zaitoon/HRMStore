// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'services/onesignal_service.dart';
import 'services/app_check_service.dart';
import 'services/app_links_service.dart';
import 'services/easy_loading_service.dart';
import 'services/remote_config_service.dart';
import 'services/theme_service.dart';
import 'services/admin_session_service.dart';
import 'services/update_manager.dart';
import 'app/hrm_store_app.dart';
import 'core/app_info.dart';
import 'core/app_navigator.dart';

// EN: App entry point.
// AR: نقطة بدء التطبيق.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  usePathUrlStrategy();

  const supportedPlatforms = {TargetPlatform.android};
  final isSupportedPlatform =
      !kIsWeb && supportedPlatforms.contains(defaultTargetPlatform);
  if (!isSupportedPlatform) {
    runApp(const _AdminPlatformBlockedApp());
    return;
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Crashlytics متاحة عمليًا على Android/iOS فقط.
  const mobilePlatforms = {TargetPlatform.android, TargetPlatform.iOS};
  final isMobile = !kIsWeb && mobilePlatforms.contains(defaultTargetPlatform);

  if (isMobile) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  final prefs = await SharedPreferences.getInstance();
  ThemeService.init(prefs);
  EasyLoadingService.configure();
  final adminSession = await AdminSessionService.getLocalSession();
  final whatsapp =
      (adminSession?.whatsapp ?? prefs.getString('admin_whatsapp') ?? '')
          .trim();

  // هذه نسخة الأدمن: نثبّت العلم لكل تشغيل لضمان تحميل مسارات الأدمن
  const bool isAdmin = true;
  const bool isMerchant = false;
  await prefs.setBool('is_admin', isAdmin);
  await prefs.setBool('is_merchant', isMerchant);
  AppInfo.isAdminApp = isAdmin;
  AppInfo.isMerchantApp = isMerchant;

  runApp(HrmStoreApp(prefs: prefs, isAdminApp: isAdmin));

  unawaited(AppLinksService.start(isAdminApp: isAdmin));
  unawaited(_postInit(whatsapp: whatsapp, isAdmin: isAdmin));
}

Future<void> _postInit({
  required String whatsapp,
  required bool isAdmin,
}) async {
  const mobilePlatforms = {TargetPlatform.android, TargetPlatform.iOS};
  final isMobile = !kIsWeb && mobilePlatforms.contains(defaultTargetPlatform);

  // App Check (Android/iOS فقط أو Web بمفتاح).
  if (isMobile) {
    await AppCheckService.activate();
  }

  await RemoteConfigService.instance.init();

  // Push/OneSignal للموبايل فقط.
  if (isMobile) {
    await OneSignalService.init();
    await OneSignalService.requestPermission();

    if (whatsapp.isNotEmpty) {
      await OneSignalService.registerUser(whatsapp: whatsapp, isAdmin: isAdmin);
    }
  }

  unawaited(_runGlobalUpdateCheck());
}

Future<void> _runGlobalUpdateCheck() async {
  if (kIsWeb) return;
  for (var i = 0; i < 30; i++) {
    final context = AppNavigator.context;
    if (context != null && context.mounted) {
      unawaited(UpdateManager.check(context));
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
}

class _AdminPlatformBlockedApp extends StatelessWidget {
  const _AdminPlatformBlockedApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'نسخة الأدمن متاحة على أندرويد فقط.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.red.shade700,
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
