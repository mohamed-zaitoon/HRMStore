// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/tt_colors.dart';
import '../core/app_navigator.dart';
import '../services/theme_service.dart';
import '../widgets/connection_blocker.dart';
import '../widgets/access_blocker.dart';
import '../widgets/availability_blocker.dart';
import '../widgets/snow_background.dart';

import '../features/calculator/calculator_screen.dart';
import '../features/orders/orders_screen.dart';
import '../features/calculator/privacy_screen.dart';
import '../features/auth/account_screen.dart';
import '../features/auth/user_auth_screen.dart';

import '../features/admin/admin_login_screen.dart';
import '../features/admin/admin_orders_screen.dart';
import '../features/admin/admin_code_requests_screen.dart';
import '../features/admin/admin_promo_codes_screen.dart';
import '../features/admin/admin_prices_screen.dart';
import '../features/admin/admin_availability_screen.dart';
import '../features/admin/admin_game_packages_screen.dart';
import '../features/admin/admin_users_screen.dart';

import '../features/platform/android_landing_page.dart';
import '../features/orders/ramadan_codes_screen.dart';
import '../utils/html_meta.dart';
import '../core/app_info.dart';

class HrmStoreApp extends StatelessWidget {
  final SharedPreferences prefs;
  final bool isAdminApp;
  final NavigatorObserver _titleObserver;

  // EN: Creates HrmStoreApp.
  // AR: ينشئ HrmStoreApp.
  HrmStoreApp({
    super.key,
    required this.prefs,
    required this.isAdminApp,
  }) : _titleObserver = _WebTitleObserver(isAdminApp: isAdminApp);

  // EN: Handles Generate Route.
  // AR: تتعامل مع Generate Route.
  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    String name = settings.name ?? '/';
    final parsed = Uri.tryParse(name);
    if (parsed != null) {
      name = parsed.path;
    }
    name = _normalizeRoute(name);

    switch (name) {
      case '/':
        if (isAdminApp) {
          return MaterialPageRoute(builder: (_) => const AdminLoginScreen());
        } else {
          return MaterialPageRoute(builder: (_) => const UserAuthScreen());
        }

      case '/login':
        return MaterialPageRoute(builder: (_) => const UserAuthScreen());

      case '/android':
        return MaterialPageRoute(builder: (_) => const AndroidLandingPage());

      case '/home':
        {
          final args = settings.arguments as Map<String, dynamic>?;

          final name =
              (args != null ? args['name'] as String? : null) ??
              prefs.getString('user_name') ??
              '';
          final whatsapp =
              (args != null ? args['whatsapp'] as String? : null) ??
              prefs.getString('user_whatsapp') ??
              '';
          final tiktok =
              (args != null ? args['tiktok'] as String? : null) ??
              prefs.getString('user_tiktok') ??
              '';

          if (name.isEmpty || whatsapp.isEmpty) {
            return MaterialPageRoute(builder: (_) => const UserAuthScreen());
          }

          return MaterialPageRoute(
            builder: (_) => CalculatorScreen(
              name: name,
              whatsapp: whatsapp,
              tiktok: tiktok,
              prefillPoints: args?['prefill_points'] as int?,
              autolaunchPayment:
                  (args?['autolaunch_payment'] as bool?) ?? false,
            ),
          );
        }

      case '/orders':
        {
          String? whatsappArg = settings.arguments as String?;
          whatsappArg ??= prefs.getString('user_whatsapp');

          final String whatsapp = whatsappArg ?? '';

          if (whatsapp.isEmpty) {
            return MaterialPageRoute(builder: (_) => const UserAuthScreen());
          }

          return MaterialPageRoute(
            builder: (_) => OrdersScreen(whatsapp: whatsapp),
          );
        }

      case '/account':
        return MaterialPageRoute(builder: (_) => AccountScreen());

      case '/privacy':
      case '/privacy_policy':
        return MaterialPageRoute(builder: (_) => const PrivacyScreen());

      case '/code_requests':
        {
          String? whatsappArg = settings.arguments as String?;
          whatsappArg ??= prefs.getString('user_whatsapp');

          final name = prefs.getString('user_name') ?? '';
          final tiktok = prefs.getString('user_tiktok') ?? '';

          final String whatsapp = whatsappArg ?? '';

          if (whatsapp.isEmpty || name.isEmpty) {
            return MaterialPageRoute(builder: (_) => const UserAuthScreen());
          }

          return MaterialPageRoute(
            builder: (_) => RamadanCodesScreen(
              name: name,
              whatsapp: whatsapp,
              tiktok: tiktok,
            ),
          );
        }

      case '/admin':
      case '/admin/login':
        return MaterialPageRoute(builder: (_) => const AdminLoginScreen());

      case '/admin/orders':
        return MaterialPageRoute(builder: (_) => const AdminOrdersScreen());

      case '/admin/codes':
        return MaterialPageRoute(builder: (_) => const AdminPromoCodesScreen());

      case '/admin/requests':
        return MaterialPageRoute(
          builder: (_) => const AdminCodeRequestsScreen(),
        );

      case '/admin/prices':
        return MaterialPageRoute(builder: (_) => const AdminPricesScreen());

      case '/admin/availability':
        return MaterialPageRoute(
          builder: (_) => const AdminAvailabilityScreen(),
        );

      case '/admin/games':
        return MaterialPageRoute(
          builder: (_) => const AdminGamePackagesScreen(),
        );
      case '/admin/users':
        return MaterialPageRoute(
          builder: (_) => const AdminUsersScreen(),
        );

      default:
        return MaterialPageRoute(builder: (_) => const _NotFoundScreen());
    }
  }

  String _normalizeRoute(String name) {
    // أزل index.html إن وُجد
    if (name.endsWith('/index.html')) {
      name = name.substring(0, name.length - '/index.html'.length);
    }
    // أزل الشرطة المائلة في النهاية مع الحفاظ على الجذر
    if (name.endsWith('/') && name.length > 1) {
      name = name.substring(0, name.length - 1);
    }
    if (name.isEmpty) return '/';
    return name;
  }

  // EN: Builds widget UI.
  // AR: تبني واجهة الودجت.
  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        ThemeService.setDynamicSchemes(lightDynamic, darkDynamic);
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: ThemeService.modeNotifier,
          builder: (context, mode, _) {
            return MaterialApp(
              title: AppInfo.appName,
              debugShowCheckedModeBanner: false,
              navigatorKey: AppNavigator.key,
              initialRoute:
                  kIsWeb ? (Uri.base.path.isEmpty ? '/' : Uri.base.path) : '/',
              theme: _buildTheme(Brightness.light, lightDynamic),
              darkTheme: _buildTheme(Brightness.dark, darkDynamic),
              themeMode: mode,
              locale: const Locale('ar'),
              supportedLocales: const [Locale('ar')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              onGenerateRoute: _onGenerateRoute,
              navigatorObservers: [_titleObserver],

              builder: (context, child) {
                final content = child ?? const SizedBox.shrink();

                if (kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
                  return const AndroidLandingPage();
                }

                final brightness = Theme.of(context).brightness;
                final background = TTColors.backgroundFor(brightness);
                final bool isDark = brightness == Brightness.dark;
                final overlayStyle = SystemUiOverlayStyle(
                  statusBarColor: background,
                  statusBarIconBrightness:
                      isDark ? Brightness.light : Brightness.dark,
                  statusBarBrightness:
                      isDark ? Brightness.dark : Brightness.light,
                  systemNavigationBarColor: background,
                  systemNavigationBarIconBrightness:
                      isDark ? Brightness.light : Brightness.dark,
                );
                SystemChrome.setSystemUIOverlayStyle(overlayStyle);

                final wrapped = kIsWeb
                    ? content
                    : ConnectionBlocker(child: content);

                final availabilityWrapped = isAdminApp
                    ? wrapped
                    : AvailabilityBlocker(child: wrapped);

                final gated = AccessBlocker(child: availabilityWrapped);

                return AnnotatedRegion<SystemUiOverlayStyle>(
                  value: overlayStyle,
                  child: Stack(
                    children: [
                      const SnowBackground(),
                      // نجعل المحتوى فوق الخلفية
                      Theme(
                        data: Theme.of(context).copyWith(
                          scaffoldBackgroundColor: Colors.transparent,
                          canvasColor: Colors.transparent,
                        ),
                        child: gated,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // EN: Builds Theme.
  // AR: تبني Theme.
  ThemeData _buildTheme(Brightness brightness, ColorScheme? dynamicScheme) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    final background = TTColors.backgroundFor(brightness);
    final cardBg = TTColors.cardBgFor(brightness);
    final text = TTColors.textFor(brightness);
    final textMuted = TTColors.textMutedFor(brightness);

    final colorScheme =
        (dynamicScheme ??
                (brightness == Brightness.dark
                    ? ColorScheme.dark(
                        primary: TTColors.primaryCyan,
                        secondary: TTColors.primaryPink,
                        surface: cardBg,
                        onPrimary: Colors.black,
                        onSecondary: Colors.white,
                        onSurface: text,
                      )
                    : ColorScheme.light(
                        primary: TTColors.primaryCyan,
                        secondary: TTColors.primaryPink,
                        surface: cardBg,
                        onPrimary: Colors.black,
                        onSecondary: Colors.white,
                        onSurface: text,
                      )))
            .copyWith(
              primary: TTColors.primaryCyan,
              secondary: TTColors.primaryPink,
            );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.transparent,
      primaryColor: TTColors.primaryCyan,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: text),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: background,
          statusBarIconBrightness:
              brightness == Brightness.dark ? Brightness.light : Brightness.dark,
          statusBarBrightness:
              brightness == Brightness.dark ? Brightness.dark : Brightness.light,
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: text,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: brightness == Brightness.dark
                ? Colors.white12
                : Colors.black12,
          ),
        ),
      ),
      cardColor: cardBg,
      dividerColor: brightness == Brightness.dark
          ? Colors.white12
          : Colors.black12,
      textTheme: base.textTheme
          .apply(fontFamily: 'Cairo', bodyColor: text, displayColor: text)
          .copyWith(
            bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 15),
            bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 17),
            titleLarge: base.textTheme.titleLarge?.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
      iconTheme: IconThemeData(color: text),
      listTileTheme: ListTileThemeData(textColor: text, iconColor: text),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        labelStyle: TextStyle(
          color: textMuted,
          fontSize: 14,
          fontFamily: 'Cairo',
        ),
        floatingLabelStyle: TextStyle(
          color: text,
          fontFamily: 'Cairo',
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(
          color: brightness == Brightness.dark
              ? Colors.white38
              : Colors.black38,
          fontSize: 14,
          fontFamily: 'Cairo',
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: brightness == Brightness.dark
                ? Colors.white24
                : Colors.black12,
          ),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: TTColors.primaryCyan, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: TTColors.primaryPink,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: text,
          textStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: const BorderSide(color: TTColors.primaryPink, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: TTColors.primaryPink,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _WebTitleObserver extends NavigatorObserver {
  final bool isAdminApp;

  _WebTitleObserver({required this.isAdminApp});

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _updateTitle(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _updateTitle(newRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _updateTitle(previousRoute);
    super.didPop(route, previousRoute);
  }

  void _updateTitle(Route<dynamic>? route) {
    if (!kIsWeb) return;
    final name = route?.settings.name ?? '/';
    setPageTitle(_titleForRoute(name));
  }

  String _titleForRoute(String name) {
    return AppInfo.appName;
  }
}

class _NotFoundScreen extends StatelessWidget {
  // EN: Creates NotFoundScreen.
  // AR: ينشئ NotFoundScreen.
  const _NotFoundScreen();

  // EN: Builds widget UI.
  // AR: تبني واجهة الودجت.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          '404 - الصفحة غير موجودة',
          style: TextStyle(
            color: TTColors.textGray,
            fontSize: 20,
            fontFamily: 'Cairo',
          ),
        ),
      ),
    );
  }
}
