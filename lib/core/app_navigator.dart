// Open-source code. Copyright Mohamed Zaitoon 2025-2026.
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

// EN: Global navigator access for dialogs that are triggered above the app Navigator.
// AR: وصول عام للـ Navigator لعرض الحوارات التي تُشغّل فوق الـ Navigator.
class AppNavigator {
  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
  static final Map<String, Object?> _argumentsByPath = <String, Object?>{};

  static BuildContext? get context => key.currentState?.overlay?.context;

  static Future<T?> pushNamed<T extends Object?>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    final path = _buildPath(routeName);
    _rememberArguments(path, arguments);
    return context.router.pushPath<T>(path);
  }

  static Future<T?> pushReplacementNamed<T extends Object?, TO extends Object?>(
    BuildContext context,
    String routeName, {
    TO? result,
    Object? arguments,
  }) {
    final path = _buildPath(routeName);
    _rememberArguments(path, arguments);
    return context.router.replacePath<T>(path);
  }

  static Future<T?> pushNamedAndRemoveUntil<T extends Object?>(
    BuildContext context,
    String newRouteName,
    RoutePredicate predicate, {
    Object? arguments,
  }) {
    context.router.popUntilRoot();
    final path = _buildPath(newRouteName);
    _rememberArguments(path, arguments);
    return context.router.replacePath<T>(path);
  }

  static Object? argsForPath(String routeName) {
    return _argumentsByPath[_normalizePath(routeName)];
  }

  static String _buildPath(String routeName) {
    return Uri.parse(routeName).toString();
  }

  static void _rememberArguments(String routeName, Object? arguments) {
    final path = _normalizePath(routeName);
    if (arguments == null) {
      _argumentsByPath.remove(path);
      return;
    }
    _argumentsByPath[path] = _cloneArguments(arguments);
  }

  static String _normalizePath(String routeName) {
    final path = Uri.parse(routeName).path.trim();
    if (path.isEmpty) return '/';
    return path;
  }

  static Object _cloneArguments(Object arguments) {
    if (arguments is Map<String, dynamic>) {
      return Map<String, dynamic>.from(arguments);
    }
    if (arguments is Map) {
      final copied = <String, dynamic>{};
      for (final entry in arguments.entries) {
        copied[entry.key.toString()] = entry.value;
      }
      return copied;
    }
    if (arguments is List) {
      return List<Object?>.from(arguments);
    }
    return arguments;
  }
}
