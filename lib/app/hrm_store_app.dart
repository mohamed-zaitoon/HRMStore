// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
import '../features/admin/admin_wallets_screen.dart';
import '../features/admin/admin_route_guard.dart';

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
  HrmStoreApp({super.key, required this.prefs, required this.isAdminApp})
    : _titleObserver = _WebTitleObserver(isAdminApp: isAdminApp);

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
        return MaterialPageRoute(
          builder: (_) => const AdminRouteGuard(child: AdminOrdersScreen()),
        );

      case '/admin/codes':
        return MaterialPageRoute(
          builder: (_) => const AdminRouteGuard(child: AdminPromoCodesScreen()),
        );

      case '/admin/requests':
        return MaterialPageRoute(
          builder: (_) =>
              const AdminRouteGuard(child: AdminCodeRequestsScreen()),
        );

      case '/admin/prices':
        return MaterialPageRoute(
          builder: (_) => const AdminRouteGuard(child: AdminPricesScreen()),
        );

      case '/admin/availability':
        return MaterialPageRoute(
          builder: (_) =>
              const AdminRouteGuard(child: AdminAvailabilityScreen()),
        );

      case '/admin/games':
        return MaterialPageRoute(
          builder: (_) =>
              const AdminRouteGuard(child: AdminGamePackagesScreen()),
        );
      case '/admin/users':
        return MaterialPageRoute(
          builder: (_) => const AdminRouteGuard(child: AdminUsersScreen()),
        );
      case '/admin/wallets':
        return MaterialPageRoute(
          builder: (_) => const AdminRouteGuard(child: AdminWalletsScreen()),
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
              initialRoute: kIsWeb
                  ? (Uri.base.path.isEmpty ? '/' : Uri.base.path)
                  : '/',
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

                final brightness = Theme.of(context).brightness;
                final background = TTColors.backgroundFor(brightness);
                final bool isDark = brightness == Brightness.dark;
                final overlayStyle = SystemUiOverlayStyle(
                  statusBarColor: background,
                  statusBarIconBrightness: isDark
                      ? Brightness.light
                      : Brightness.dark,
                  statusBarBrightness: isDark
                      ? Brightness.dark
                      : Brightness.light,
                  systemNavigationBarColor: background,
                  systemNavigationBarIconBrightness: isDark
                      ? Brightness.light
                      : Brightness.dark,
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
                  child: gated,
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
    dynamicScheme; // نحافظ على التوقيع مع تعطيل الاعتماد على Dynamic Color
    final bool isDark = brightness == Brightness.dark;
    final text = TTColors.textFor(brightness);
    final textMuted = TTColors.textMutedFor(brightness);
    final background = TTColors.backgroundFor(brightness);
    final cardBg = TTColors.cardBgFor(brightness);
    final primary = isDark ? const Color(0xFFE5E7EB) : const Color(0xFF111827);
    final onPrimary = isDark ? const Color(0xFF111827) : Colors.white;
    final secondary = isDark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF374151);
    final onSecondary = isDark ? const Color(0xFF111827) : Colors.white;
    final outline = isDark ? const Color(0xFF3F4653) : const Color(0xFFD1D5DB);
    final outlineVariant = isDark
        ? const Color(0xFF2A2F39)
        : const Color(0xFFE5E7EB);

    final base = ThemeData(
      brightness: brightness,
      useMaterial3: true,
      fontFamily: 'Cairo',
      splashFactory: InkSparkle.splashFactory,
    );

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: brightness,
        ).copyWith(
          primary: primary,
          onPrimary: onPrimary,
          secondary: secondary,
          onSecondary: onSecondary,
          tertiary: TTColors.goldAccent,
          onTertiary: const Color(0xFF2A1700),
          surface: cardBg,
          onSurface: text,
          outline: outline,
          outlineVariant: outlineVariant,
          error: const Color(0xFFDC2626),
          onError: Colors.white,
          shadow: Colors.black.withAlpha(isDark ? 180 : 36),
          scrim: Colors.black.withAlpha(136),
        );

    final textTheme = base.textTheme
        .apply(fontFamily: 'Cairo', bodyColor: text, displayColor: text)
        .copyWith(
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 16),
          bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 15),
          bodySmall: base.textTheme.bodySmall?.copyWith(
            color: textMuted,
            fontSize: 13,
          ),
        );

    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: isDark ? Colors.white24 : outline),
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      primaryColor: colorScheme.primary,
      textTheme: textTheme,
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withAlpha(isDark ? 170 : 210),
        thickness: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface.withAlpha(isDark ? 240 : 248),
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: true,
        shadowColor: Colors.black.withAlpha(isDark ? 110 : 24),
        surfaceTintColor: colorScheme.primary.withAlpha(isDark ? 34 : 18),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 20),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: background,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
      ),
      cardColor: cardBg,
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: isDark ? 1.5 : 2,
        shadowColor: Colors.black.withAlpha(isDark ? 96 : 22),
        surfaceTintColor: colorScheme.primary.withAlpha(isDark ? 28 : 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: colorScheme.outlineVariant.withAlpha(155)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        textColor: colorScheme.onSurface,
        iconColor: colorScheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1D2129) : const Color(0xFFFAFAFA),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        labelStyle: TextStyle(
          color: textMuted,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: TextStyle(
          color: colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: TextStyle(color: textMuted.withAlpha(178), fontSize: 14),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        disabledBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: colorScheme.outline.withAlpha(120)),
        ),
        focusedBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: colorScheme.primary, width: 1.7),
        ),
        errorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: colorScheme.error, width: 1.2),
        ),
        focusedErrorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: colorScheme.error, width: 1.7),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(50)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
          shape: WidgetStatePropertyAll(buttonShape),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          elevation: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return 0;
            if (states.contains(WidgetState.pressed)) return 1;
            return isDark ? 1.6 : 2.6;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colorScheme.primary.withAlpha(120);
            }
            return colorScheme.primary;
          }),
          foregroundColor: WidgetStatePropertyAll(colorScheme.onPrimary),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            final pressedOverlay = colorScheme.onPrimary.withAlpha(
              isDark ? 20 : 26,
            );
            final hoverOverlay = colorScheme.onPrimary.withAlpha(
              isDark ? 12 : 16,
            );
            if (states.contains(WidgetState.pressed)) {
              return pressedOverlay;
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return hoverOverlay;
            }
            return null;
          }),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(50)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
          shape: WidgetStatePropertyAll(buttonShape),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colorScheme.secondary.withAlpha(120);
            }
            return colorScheme.secondary;
          }),
          foregroundColor: WidgetStatePropertyAll(colorScheme.onSecondary),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(50)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          shape: WidgetStatePropertyAll(buttonShape),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w700,
              fontSize: 14.5,
            ),
          ),
          foregroundColor: WidgetStatePropertyAll(colorScheme.primary),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return BorderSide(
                color: colorScheme.outline.withAlpha(110),
                width: 1.1,
              );
            }
            if (states.contains(WidgetState.pressed)) {
              return BorderSide(color: colorScheme.primary, width: 1.5);
            }
            return BorderSide(
              color: colorScheme.primary.withAlpha(170),
              width: 1.2,
            );
          }),
          overlayColor: WidgetStatePropertyAll(
            colorScheme.primary.withAlpha(isDark ? 28 : 20),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          foregroundColor: WidgetStatePropertyAll(colorScheme.primary),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
      iconTheme: IconThemeData(color: colorScheme.onSurface),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(colorScheme.primary),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(10)),
          overlayColor: WidgetStatePropertyAll(
            colorScheme.primary.withAlpha(isDark ? 28 : 18),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide(color: colorScheme.outline.withAlpha(140)),
        selectedColor: colorScheme.secondary.withAlpha(isDark ? 90 : 52),
        disabledColor: colorScheme.outlineVariant.withAlpha(80),
        labelStyle: TextStyle(
          color: colorScheme.onSurface,
          fontFamily: 'Cairo',
          fontWeight: FontWeight.w700,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      // ignore: deprecated_member_use
      buttonBarTheme: const ButtonBarThemeData(
        layoutBehavior: ButtonBarLayoutBehavior.padded,
        buttonPadding: EdgeInsets.symmetric(horizontal: 4),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardBg,
        surfaceTintColor: colorScheme.primary.withAlpha(isDark ? 22 : 14),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? const Color(0xFF1F2937)
            : const Color(0xFF111827),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontFamily: 'Cairo',
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.secondary,
        foregroundColor: colorScheme.onSecondary,
        elevation: isDark ? 1 : 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
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
