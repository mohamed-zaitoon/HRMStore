// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_html/html.dart' as html;

import '../core/tt_colors.dart';
import '../core/app_navigator.dart';
import '../services/theme_service.dart';
import '../widgets/connection_blocker.dart';
import '../widgets/access_blocker.dart';
import '../widgets/account_status_blocker.dart';
import '../widgets/availability_blocker.dart';
import '../widgets/pull_to_retry.dart';

import '../features/home/home_screen.dart';
import '../features/orders/orders_screen.dart';
import '../features/home/privacy_screen.dart';
import '../features/auth/account_screen.dart';
import '../features/auth/user_auth_screen.dart';
import '../features/support/support_chat_screen.dart';
import '../features/support/order_chat_screen.dart';
import '../features/support/support_inquiry_screen.dart';

import '../features/admin/admin_login_screen.dart';
import '../features/admin/admin_code_requests_screen.dart';
import '../features/admin/admin_promo_codes_screen.dart';
import '../features/admin/admin_prices_screen.dart';
import '../features/admin/admin_offers_screen.dart';
import '../features/admin/admin_cost_calculator_screen.dart';
import '../features/admin/admin_game_packages_screen.dart';
import '../features/admin/admin_availability_screen.dart';
import '../features/admin/admin_users_screen.dart';
import '../features/admin/admin_devices_screen.dart';
import '../features/admin/admin_support_inquiries_screen.dart';
import '../features/admin/admin_route_guard.dart';
import '../features/merchant/merchant_orders_screen.dart';
import '../features/merchant/merchant_verification_screen.dart';

import '../features/platform/android_landing_page.dart';
import '../features/platform/about_app_screen.dart';
import '../features/orders/ramadan_codes_screen.dart';
import '../utils/html_meta.dart';
import '../core/app_info.dart';

class HrmStoreApp extends StatelessWidget {
  final SharedPreferences prefs;
  final bool isAdminApp;
  final bool isMerchantApp;
  final NavigatorObserver _titleObserver;
  late final RootStackRouter _appRouter = RootStackRouter.build(
    navigatorKey: AppNavigator.key,
    routes: [
      NamedRouteDef(
        path: '/',
        name: 'RootRoute',
        builder: (context, data) => _buildRootPage('/'),
      ),
      NamedRouteDef(
        path: '/login',
        name: 'LoginRoute',
        builder: (context, data) => _buildRootPage('/login'),
      ),
      NamedRouteDef(
        path: '/android',
        name: 'AndroidLandingRoute',
        builder: (context, data) => const AndroidLandingPage(),
      ),
      NamedRouteDef(
        path: '/home',
        name: 'HomeRoute',
        builder: (context, data) => _buildHomePage(data, '/home'),
      ),
      NamedRouteDef(
        path: '/home/tiktok',
        name: 'HomeTikTokRoute',
        builder: (context, data) => _buildHomePage(data, '/home/tiktok'),
      ),
      NamedRouteDef(
        path: '/home/games',
        name: 'HomeGamesRoute',
        builder: (context, data) => _buildHomePage(data, '/home/games'),
      ),
      NamedRouteDef(
        path: '/orders',
        name: 'OrdersRoute',
        builder: (context, data) => _buildOrdersPage(data),
      ),
      NamedRouteDef(
        path: '/merchant/orders',
        name: 'MerchantOrdersRoute',
        builder: (context, data) => _buildMerchantOrdersPage(),
      ),
      NamedRouteDef(
        path: '/merchant/verify',
        name: 'MerchantVerifyRoute',
        builder: (context, data) => _withAndroidLanding(
          '/merchant/verify',
          const MerchantVerificationScreen(),
        ),
      ),
      NamedRouteDef(
        path: '/support_chat',
        name: 'SupportChatRoute',
        builder: (context, data) => _buildSupportChatPage(data),
      ),
      NamedRouteDef(
        path: '/order_chat',
        name: 'OrderChatRoute',
        builder: (context, data) => _buildOrderChatPage(data),
      ),
      NamedRouteDef(
        path: '/support_inquiry',
        name: 'SupportInquiryRoute',
        builder: (context, data) => _buildSupportInquiryPage(data),
      ),
      NamedRouteDef(
        path: '/account',
        name: 'AccountRoute',
        builder: (context, data) =>
            _withAndroidLanding('/account', AccountScreen()),
      ),
      if (!kIsWeb)
        NamedRouteDef(
          path: '/about',
          name: 'AboutRoute',
          builder: (context, data) =>
              _withAndroidLanding('/about', const AboutAppScreen()),
        ),
      NamedRouteDef(
        path: '/privacy',
        name: 'PrivacyRoute',
        builder: (context, data) =>
            _withAndroidLanding('/privacy', const PrivacyScreen()),
      ),
      NamedRouteDef(
        path: '/privacy_policy',
        name: 'PrivacyPolicyRoute',
        builder: (context, data) =>
            _withAndroidLanding('/privacy_policy', const PrivacyScreen()),
      ),
      NamedRouteDef(
        path: '/code_requests',
        name: 'CodeRequestsRoute',
        builder: (context, data) => _buildCodeRequestsPage(data),
      ),
      NamedRouteDef(
        path: '/admin',
        name: 'AdminRootRoute',
        builder: (context, data) => const AdminLoginScreen(),
      ),
      NamedRouteDef(
        path: '/admin/login',
        name: 'AdminLoginRoute',
        builder: (context, data) => const AdminLoginScreen(),
      ),
      NamedRouteDef(
        path: '/admin/orders',
        name: 'AdminOrdersRoute',
        builder: (context, data) =>
            const AdminRouteGuard(child: AdminUsersScreen()),
      ),
      NamedRouteDef(
        path: '/admin/codes',
        name: 'AdminCodesRoute',
        builder: (context, data) =>
            const AdminRouteGuard(child: AdminPromoCodesScreen()),
      ),
      NamedRouteDef(
        path: '/admin/requests',
        name: 'AdminRequestsRoute',
        builder: (context, data) =>
            const AdminRouteGuard(child: AdminCodeRequestsScreen()),
      ),
      NamedRouteDef(
        path: '/admin/prices',
        name: 'AdminPricesRoute',
        builder: (context, data) =>
            const AdminRouteGuard(child: AdminPricesScreen()),
      ),
      NamedRouteDef(
        path: '/admin/offers',
        name: 'AdminOffersRoute',
        builder: (context, data) =>
            const AdminRouteGuard(child: AdminOffersScreen()),
      ),
      NamedRouteDef(
        path: '/admin/cost-calculator',
        name: 'AdminCostCalculatorRoute',
        builder: (context, data) =>
            const AdminRouteGuard(child: AdminCostCalculatorScreen()),
      ),
      NamedRouteDef(
        path: '/admin/availability',
        name: 'AdminAvailabilityRoute',
        builder: (context, data) =>
            const AdminRouteGuard(child: AdminAvailabilityScreen()),
      ),
      NamedRouteDef(
        path: '/admin/games',
        name: 'AdminGamesRoute',
        builder: (context, data) =>
            const AdminRouteGuard(child: AdminGamePackagesScreen()),
      ),
      NamedRouteDef(
        path: '/admin/users',
        name: 'AdminUsersRoute',
        builder: (context, data) =>
            const AdminRouteGuard(child: AdminUsersScreen()),
      ),
      NamedRouteDef(
        path: '/admin/wallets',
        name: 'AdminWalletsRoute',
        builder: (context, data) =>
            const AdminRouteGuard(child: AdminUsersScreen()),
      ),
      NamedRouteDef(
        path: '/admin/devices',
        name: 'AdminDevicesRoute',
        builder: (context, data) => _buildAdminDevicesPage(data),
      ),
      NamedRouteDef(
        path: '/admin/support_inquiries',
        name: 'AdminSupportInquiriesRoute',
        builder: (context, data) =>
            const AdminRouteGuard(child: AdminSupportInquiriesScreen()),
      ),
      NamedRouteDef(
        path: '*',
        name: 'NotFoundRoute',
        builder: (context, data) =>
            _withAndroidLanding(data.match, const _NotFoundScreen()),
      ),
    ],
  );

  // EN: Creates HrmStoreApp.
  // AR: ينشئ HrmStoreApp.
  HrmStoreApp({
    super.key,
    required this.prefs,
    required this.isAdminApp,
    required this.isMerchantApp,
  }) : _titleObserver = _WebTitleObserver(
         isAdminApp: isAdminApp,
         isMerchantApp: isMerchantApp,
       ) {
    AppNavigator.bindRootRouter(_appRouter);
  }

  Widget _buildRootPage(String routeName) {
    if (isAdminApp) {
      return const AdminLoginScreen();
    }
    if (isMerchantApp || AppInfo.isMerchantApp) {
      return _buildMerchantOrdersPage();
    }
    return _withAndroidLanding(routeName, const UserAuthScreen());
  }

  Widget _buildHomePage(RouteData data, String routeName) {
    if (_isMerchantModeActive()) {
      return _buildMerchantOrdersPage();
    }

    final args = _resolveArgsMap(data, routeName);
    final query = data.queryParams;

    final name =
        _stringArg(args, 'name') ??
        query.optString('name') ??
        prefs.getString('user_name') ??
        '';
    final whatsapp =
        _stringArg(args, 'whatsapp') ??
        query.optString('whatsapp') ??
        prefs.getString('user_whatsapp') ??
        '';
    final tiktok =
        _stringArg(args, 'tiktok') ??
        query.optString('tiktok') ??
        prefs.getString('user_tiktok') ??
        '';

    if (name.isEmpty || whatsapp.isEmpty) {
      return _withAndroidLanding(routeName, const UserAuthScreen());
    }

    final bool routeForTikTok = routeName == '/home/tiktok';
    final bool routeForGames = routeName == '/home/games';
    final bool forceTikTokCharge =
        _boolArg(args, 'force_tiktok_charge') ??
        _boolText(query.optString('force_tiktok_charge')) ??
        routeForTikTok;
    final bool showRamadanPromo =
        _boolArg(args, 'show_ramadan_promo') ??
        _boolText(query.optString('show_ramadan_promo')) ??
        true;
    final bool showGamesOnly =
        _boolArg(args, 'show_games_only') ??
        _boolText(query.optString('show_games_only')) ??
        routeForGames;

    final int? prefillPoints =
        _intArg(args, 'prefill_points') ?? query.optInt('prefill_points');
    final bool autolaunchPayment =
        _boolArg(args, 'autolaunch_payment') ??
        _boolText(query.optString('autolaunch_payment')) ??
        false;

    return _withAndroidLanding(
      routeName,
      HomeScreen(
        name: name,
        whatsapp: whatsapp,
        tiktok: tiktok,
        forceTikTokCharge: forceTikTokCharge,
        showRamadanPromo: showRamadanPromo,
        showGamesOnly: showGamesOnly,
        prefillPoints: prefillPoints,
        autolaunchPayment: autolaunchPayment,
      ),
    );
  }

  Widget _buildOrdersPage(RouteData data) {
    if (_isMerchantModeActive()) {
      return _buildMerchantOrdersPage();
    }
    final args = _resolveArgsMap(data, '/orders');
    final routeArgs = _resolveRawArgs(data, '/orders');
    String? whatsapp = _stringFromDynamic(routeArgs);
    whatsapp ??= _stringArg(args, 'whatsapp');
    whatsapp ??= data.queryParams.optString('whatsapp');
    whatsapp ??= prefs.getString('user_whatsapp');
    final orderId =
        _stringArg(args, 'order_id') ?? data.queryParams.optString('order_id');
    final resolved = (whatsapp ?? '').trim();
    final resolvedOrderId = (orderId ?? '').trim();

    if (resolved.isEmpty) {
      return _withAndroidLanding('/orders', const UserAuthScreen());
    }

    return _withAndroidLanding(
      '/orders',
      OrdersScreen(
        whatsapp: resolved,
        initialOrderId: resolvedOrderId.isEmpty ? null : resolvedOrderId,
      ),
    );
  }

  Widget _buildMerchantOrdersPage() {
    final bool merchantFlag =
        AppInfo.isMerchantApp || (prefs.getBool('is_merchant') ?? false);
    final merchantId = prefs.getString('user_uid') ?? '';
    final merchantName = prefs.getString('user_name') ?? '';
    final merchantWhatsapp = prefs.getString('user_whatsapp') ?? '';

    if (!merchantFlag || merchantId.isEmpty || merchantWhatsapp.isEmpty) {
      return _withAndroidLanding('/login', const UserAuthScreen());
    }

    return _withAndroidLanding(
      '/merchant/orders',
      MerchantOrdersScreen(
        merchantId: merchantId,
        merchantName: merchantName,
        merchantWhatsapp: merchantWhatsapp,
      ),
    );
  }

  Widget _buildCodeRequestsPage(RouteData data) {
    if (_isMerchantModeActive()) {
      return _buildMerchantOrdersPage();
    }
    final args = _resolveArgsMap(data, '/code_requests');
    final routeArgs = _resolveRawArgs(data, '/code_requests');
    String? whatsapp = _stringFromDynamic(routeArgs);
    whatsapp ??= _stringArg(args, 'whatsapp');
    whatsapp ??= data.queryParams.optString('whatsapp');
    whatsapp ??= prefs.getString('user_whatsapp');

    final name =
        _stringArg(args, 'name') ??
        data.queryParams.optString('name') ??
        prefs.getString('user_name') ??
        '';
    final tiktok =
        _stringArg(args, 'tiktok') ??
        data.queryParams.optString('tiktok') ??
        prefs.getString('user_tiktok') ??
        '';
    final resolvedWhatsapp = (whatsapp ?? '').trim();

    if (resolvedWhatsapp.isEmpty || name.isEmpty) {
      return _withAndroidLanding('/code_requests', const UserAuthScreen());
    }

    return _withAndroidLanding(
      '/code_requests',
      RamadanCodesScreen(
        name: name,
        whatsapp: resolvedWhatsapp,
        tiktok: tiktok,
      ),
    );
  }

  Widget _buildSupportChatPage(RouteData data) {
    if (_isMerchantModeActive()) {
      return _buildMerchantOrdersPage();
    }
    final args = _resolveArgsMap(data, '/support_chat');
    final query = data.queryParams;
    final name =
        _stringArg(args, 'name') ??
        query.optString('name') ??
        prefs.getString('user_name') ??
        '';
    final whatsapp =
        _stringArg(args, 'whatsapp') ??
        query.optString('whatsapp') ??
        prefs.getString('user_whatsapp') ??
        '';
    final initialOrderId =
        _stringArg(args, 'order_id') ?? query.optString('order_id') ?? '';
    final resolvedName = name.trim();
    final resolvedWhatsapp = whatsapp.trim();
    final resolvedOrderId = initialOrderId.trim();

    if (resolvedName.isEmpty || resolvedWhatsapp.isEmpty) {
      return _withAndroidLanding('/support_chat', const UserAuthScreen());
    }

    return _withAndroidLanding(
      '/support_chat',
      SupportChatScreen(
        name: resolvedName,
        whatsapp: resolvedWhatsapp,
        initialOrderId: resolvedOrderId.isEmpty ? null : resolvedOrderId,
      ),
    );
  }

  Widget _buildOrderChatPage(RouteData data) {
    final args = _resolveArgsMap(data, '/order_chat');
    final query = data.queryParams;
    final orderId =
        _stringArg(args, 'order_id') ?? query.optString('order_id') ?? '';
    final requestedRole =
        _stringArg(args, 'viewer_role') ??
        query.optString('viewer_role') ??
        (isAdminApp
            ? 'admin'
            : (_isMerchantModeActive() ? 'merchant' : 'user'));
    final viewerRole = requestedRole.trim().toLowerCase();
    final viewerName =
        _stringArg(args, 'viewer_name') ??
        query.optString('viewer_name') ??
        (viewerRole == 'admin'
            ? 'الدعم'
            : (prefs.getString('user_name') ?? ''));
    final fallbackWhatsapp =
        _stringArg(args, 'whatsapp') ??
        query.optString('whatsapp') ??
        prefs.getString('user_whatsapp') ??
        '';
    final resolvedOrderId = orderId.trim();

    if (resolvedOrderId.isEmpty) {
      return _buildRootPage('/order_chat');
    }
    if (viewerRole == 'merchant' && !_isMerchantModeActive()) {
      return _buildMerchantOrdersPage();
    }

    final page = OrderChatScreen(
      orderId: resolvedOrderId,
      viewerRole: viewerRole,
      viewerName: viewerName.trim(),
      fallbackUserWhatsapp: fallbackWhatsapp.trim(),
    );

    if (viewerRole == 'admin') {
      return AdminRouteGuard(child: page);
    }

    return _withAndroidLanding('/order_chat', page);
  }

  Widget _buildSupportInquiryPage(RouteData data) {
    final args = _resolveArgsMap(data, '/support_inquiry');
    final query = data.queryParams;
    final allowMerchantSupport =
        _boolArg(args, 'merchant_support') ??
        _boolText(query.optString('merchant_support')) ??
        false;
    if (_isMerchantModeActive() && !allowMerchantSupport) {
      return _buildMerchantOrdersPage();
    }
    final name =
        _stringArg(args, 'name') ??
        query.optString('name') ??
        prefs.getString('user_name') ??
        '';
    final whatsapp =
        _stringArg(args, 'whatsapp') ??
        query.optString('whatsapp') ??
        prefs.getString('user_whatsapp') ??
        '';
    final resolvedName = name.trim();
    final resolvedWhatsapp = whatsapp.trim();

    if (resolvedName.isEmpty || resolvedWhatsapp.isEmpty) {
      return _withAndroidLanding('/support_inquiry', const UserAuthScreen());
    }

    return _withAndroidLanding(
      '/support_inquiry',
      SupportInquiryScreen(name: resolvedName, whatsapp: resolvedWhatsapp),
    );
  }

  Widget _buildAdminDevicesPage(RouteData data) {
    final routeArgs = _resolveRawArgs(data, '/admin/devices');
    final adminId = _extractAdminId(
      args: routeArgs,
      queryParams: data.queryParams.rawMap,
    );
    if (adminId.isEmpty) {
      return const AdminRouteGuard(child: AdminUsersScreen());
    }
    return AdminRouteGuard(child: AdminDevicesScreen(adminId: adminId));
  }

  Widget _withAndroidLanding(String routeName, Widget child) {
    if (_shouldForceAndroidLanding(routeName)) {
      return const AndroidLandingPage();
    }
    return _withGlobalPullToRefresh(routeName, child);
  }

  bool _isMerchantModeActive() {
    // اعتمد على الحالة المتغيرة (prefs/AppInfo) فقط حتى ينتقل
    // المستخدم فوراً من وضع التاجر إلى وضع المستخدم بدون loop.
    return AppInfo.isMerchantApp || (prefs.getBool('is_merchant') ?? false);
  }

  Widget _withGlobalPullToRefresh(String routeName, Widget child) {
    final normalized = _normalizeRoute(routeName);
    const localRefreshRoutes = <String>{
      '/home',
      '/home/tiktok',
      '/home/games',
      '/orders',
      '/code_requests',
      '/support_inquiry',
      '/order_chat',
      '/admin/users',
      '/merchant/orders',
    };
    if (localRefreshRoutes.contains(normalized)) {
      return child;
    }
    return PullToRetry(child: child);
  }

  Map<String, dynamic>? _mapArgs(Object? args) {
    if (args is Map<String, dynamic>) return args;
    return null;
  }

  Object? _resolveRawArgs(RouteData data, String routeName) {
    return data.args ?? AppNavigator.argsForPath(routeName);
  }

  Map<String, dynamic>? _resolveArgsMap(RouteData data, String routeName) {
    final fromCache = _mapArgs(AppNavigator.argsForPath(routeName));
    final fromData = _mapArgs(data.args);
    if (fromCache == null) return fromData;
    if (fromData == null) return fromCache;
    return <String, dynamic>{...fromCache, ...fromData};
  }

  String? _stringArg(Map<String, dynamic>? args, String key) {
    final value = args?[key];
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return text;
  }

  String? _stringFromDynamic(Object? value) {
    if (value is String) {
      final text = value.trim();
      return text.isEmpty ? null : text;
    }
    return null;
  }

  int? _intArg(Map<String, dynamic>? args, String key) {
    final value = args?[key];
    if (value is int) return value;
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  bool? _boolArg(Map<String, dynamic>? args, String key) {
    final value = args?[key];
    if (value is bool) return value;
    if (value is String) {
      return _boolText(value);
    }
    return null;
  }

  bool? _boolText(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
    return null;
  }

  String _extractAdminId({
    required dynamic args,
    required Map<String, dynamic> queryParams,
  }) {
    if (args is String) return args.trim();
    if (args is Map<String, dynamic>) {
      final raw = args['admin_id'];
      if (raw is String) return raw.trim();
    }
    final queryRaw = queryParams['admin_id'];
    if (queryRaw is String) return queryRaw.trim();
    return '';
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

  bool _shouldForceAndroidLanding(String route) {
    if (!kIsWeb || isAdminApp) return false;
    if (route == '/android' ||
        route.startsWith('/admin') ||
        route.startsWith('/merchant')) {
      return false;
    }
    final userAgent = html.window.navigator.userAgent;
    final lowered = userAgent.toLowerCase();
    if (!lowered.contains('android')) return false;

    // EN: Force Android landing only for Android versions > 9.
    // AR: فرض صفحة تحميل التطبيق فقط لإصدارات أندرويد الأعلى من 9.
    final majorVersion = _extractAndroidMajorVersion(userAgent);
    if (majorVersion == null) return false;
    return majorVersion > 9;
  }

  int? _extractAndroidMajorVersion(String userAgent) {
    final match = RegExp(
      r'Android\s+(\d+)',
      caseSensitive: false,
    ).firstMatch(userAgent);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }

  Future<Uri> _normalizeDeepLink(Uri uri) async {
    final path = _normalizeRoute(uri.path);
    if (kIsWeb && !isAdminApp && path == '/about') {
      return uri.replace(path: '/home');
    }
    if (path == uri.path) return uri;
    return uri.replace(path: path);
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
            return MaterialApp.router(
              title: AppInfo.appName,
              debugShowCheckedModeBanner: false,
              routerConfig: _appRouter.config(
                includePrefixMatches: false,
                deepLinkTransformer: _normalizeDeepLink,
                navigatorObservers: () => [_titleObserver],
              ),
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

                final accountWrapped = isAdminApp
                    ? availabilityWrapped
                    : AccountStatusBlocker(child: availabilityWrapped);

                final gated = AccessBlocker(child: accountWrapped);

                final appContent = AnnotatedRegion<SystemUiOverlayStyle>(
                  value: overlayStyle,
                  child: gated,
                );
                return EasyLoading.init()(context, appContent);
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
  final bool isMerchantApp;

  _WebTitleObserver({required this.isAdminApp, required this.isMerchantApp});

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
