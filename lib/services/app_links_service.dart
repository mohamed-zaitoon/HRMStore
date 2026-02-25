// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/app_navigator.dart';

class AppLinksService {
  AppLinksService._();

  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription<Uri>? _uriSub;
  static bool _started = false;
  static bool _isAdminApp = false;
  static String? _lastHandledRoute;
  static DateTime? _lastHandledAt;

  static Future<void> start({required bool isAdminApp}) async {
    if (_started || kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    _started = true;
    _isAdminApp = isAdminApp;

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        unawaited(_handleIncomingUri(initialUri));
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AppLinksService initial link error: $e');
      }
    }

    _uriSub = _appLinks.uriLinkStream.listen(
      (uri) => unawaited(_handleIncomingUri(uri)),
      onError: (Object error) {
        if (kDebugMode) {
          debugPrint('AppLinksService stream error: $error');
        }
      },
    );
  }

  static Future<void> stop() async {
    await _uriSub?.cancel();
    _uriSub = null;
    _started = false;
    _lastHandledRoute = null;
    _lastHandledAt = null;
  }

  static Future<void> _handleIncomingUri(Uri uri) async {
    final route = _resolveRoute(uri);
    if (route == null || route.isEmpty || _isDuplicateRoute(route)) {
      return;
    }

    final navContext = await _waitForNavigatorContext();
    if (navContext == null || !navContext.mounted) return;

    try {
      await AppNavigator.pushReplacementNamed(navContext, route);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AppLinksService navigation error: $e');
      }
    }
  }

  static bool _isDuplicateRoute(String route) {
    final now = DateTime.now();
    if (_lastHandledRoute == route &&
        _lastHandledAt != null &&
        now.difference(_lastHandledAt!).inMilliseconds < 1500) {
      return true;
    }
    _lastHandledRoute = route;
    _lastHandledAt = now;
    return false;
  }

  static Future<BuildContext?> _waitForNavigatorContext() async {
    for (var i = 0; i < 40; i++) {
      final ctx = AppNavigator.context;
      if (ctx != null && ctx.mounted) {
        return ctx;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return null;
  }

  static String? _resolveRoute(Uri uri) {
    final normalizedPath = _normalizePath(_extractPath(uri));
    final routePath = _mapPathToRoute(normalizedPath);
    if (routePath == null) return null;

    if (uri.query.isEmpty) {
      return routePath;
    }
    return '$routePath?${uri.query}';
  }

  static String _extractPath(Uri uri) {
    var path = uri.path.trim();

    if (uri.scheme == 'hrmstoreapp') {
      final host = uri.host.trim();
      if (host == 'open') {
        if (path.isEmpty) {
          path = uri.queryParameters['path']?.trim() ?? '';
        }
      } else if (host.isNotEmpty) {
        final suffix = path.isEmpty ? '' : path;
        path = '/$host$suffix';
      }
    } else if (path.isEmpty && uri.host.isNotEmpty) {
      path = '/${uri.host.trim()}';
    }

    return path;
  }

  static String _normalizePath(String path) {
    var out = path.trim();
    if (out.isEmpty) return '/';
    if (!out.startsWith('/')) out = '/$out';
    if (out.endsWith('/')) {
      out = out.length == 1 ? out : out.substring(0, out.length - 1);
    }
    return out;
  }

  static String? _mapPathToRoute(String path) {
    switch (path) {
      case '/':
      case '/login':
        return '/login';
      case '/home':
      case '/home/tiktok':
      case '/home/games':
      case '/orders':
      case '/support_inquiry':
      case '/privacy':
      case '/privacy_policy':
      case '/code_requests':
      case '/admin':
      case '/admin/login':
      case '/admin/orders':
      case '/admin/codes':
      case '/admin/requests':
      case '/admin/prices':
      case '/admin/offers':
      case '/admin/cost-calculator':
      case '/admin/availability':
      case '/admin/games':
      case '/admin/users':
      case '/admin/wallets':
      case '/admin/devices':
      case '/admin/support_inquiries':
        return path;
      case '/account':
      case '/about':
        return '/home';
      default:
        if (path.startsWith('/admin/')) {
          return '/admin/orders';
        }
        return _isAdminApp ? '/admin/orders' : '/home';
    }
  }
}
