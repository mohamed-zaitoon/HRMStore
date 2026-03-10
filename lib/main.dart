// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'services/app_check_service.dart';
import 'services/notification_service.dart';
import 'services/app_links_service.dart';
import 'services/easy_loading_service.dart';
import 'services/remote_config_service.dart';
import 'services/theme_service.dart';
import 'services/update_manager.dart';
import 'app/hrm_store_app.dart';
import 'core/app_info.dart';
import 'core/app_navigator.dart';

// EN: App entry point.
// AR: نقطة بدء التطبيق.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  usePathUrlStrategy();

  const desktopOnlyForAdmin = {
    TargetPlatform.windows,
    TargetPlatform.macOS,
    TargetPlatform.linux,
  };
  final isBlockedDesktop =
      !kIsWeb && desktopOnlyForAdmin.contains(defaultTargetPlatform);
  if (isBlockedDesktop) {
    runApp(const _UserDesktopBlockedApp());
    return;
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Desktop (Windows/macOS/Linux) and Web lack Crashlytics/App Check support.
  const mobilePlatforms = {TargetPlatform.android, TargetPlatform.iOS};
  final isMobile = !kIsWeb && mobilePlatforms.contains(defaultTargetPlatform);

  if (isMobile) {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      kReleaseMode,
    );
    if (kReleaseMode) {
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;

      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }
  }

  final prefs = await SharedPreferences.getInstance();
  ThemeService.init(prefs);
  EasyLoadingService.configure();
  final whatsapp = prefs.getString('user_whatsapp') ?? '';
  const bool isAdmin = false;
  final bool isMerchant = prefs.getBool('is_merchant') ?? false;

  AppInfo.isAdminApp = isAdmin;
  AppInfo.isMerchantApp = isMerchant;

  await prefs.setBool('is_admin', isAdmin);
  await prefs.setBool('is_merchant', isMerchant);

  runApp(
    HrmStoreApp(prefs: prefs, isAdminApp: isAdmin, isMerchantApp: isMerchant),
  );

  unawaited(AppLinksService.start(isAdminApp: isAdmin));
  unawaited(_postInit(whatsapp: whatsapp, isAdmin: isAdmin));
}

Future<void> _postInit({
  required String whatsapp,
  required bool isAdmin,
}) async {
  // Skip App Check on unsupported platforms (desktop / web without key).
  const mobilePlatforms = {TargetPlatform.android, TargetPlatform.iOS};
  final isMobile = !kIsWeb && mobilePlatforms.contains(defaultTargetPlatform);
  if (isMobile) {
    await AppCheckService.activate();
  }

  await RemoteConfigService.instance.init();

  await NotificationService.init();
  // Auto permission prompt on startup is kept for mobile only.
  if (isMobile) {
    await NotificationService.requestPermission();
  }

  if (whatsapp.isNotEmpty) {
    if (isAdmin) {
      await NotificationService.initAdminNotifications(
        whatsapp,
        requestPermission: isMobile,
      );
      NotificationService.listenToAdminOrders();
      NotificationService.listenToAdminRamadanCodes();
    } else {
      await NotificationService.initUserNotifications(
        whatsapp,
        requestPermission: isMobile,
      );
      NotificationService.listenToUserRamadanCodes(whatsapp);
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

class _UserDesktopBlockedApp extends StatelessWidget {
  const _UserDesktopBlockedApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'نسخة سطح المكتب مخصصة للإدمن فقط. استخدم نسخة الويب أو تطبيق الموبايل.',
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
