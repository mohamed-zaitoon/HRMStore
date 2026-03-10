// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../core/app_navigator.dart';

class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final bool automaticallyImplyLeading;
  final double blur;
  final double height;
  final double? titleSpacing;

  // EN: Creates GlassAppBar.
  // AR: ينشئ GlassAppBar.
  const GlassAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.centerTitle = true,
    this.automaticallyImplyLeading = true,
    this.blur = 14,
    this.height = kToolbarHeight,
    this.titleSpacing,
  });

  // EN: Gets preferred size.
  // AR: تجلب الحجم المفضل.
  @override
  Size get preferredSize => Size.fromHeight(height);

  // EN: Builds a Material app bar.
  // AR: تبني شريط علوي بنمط Material.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final fallbackLeading = _buildFallbackLeading(context);
    final effectiveLeading = leading ?? fallbackLeading;
    final effectiveImplyLeading = effectiveLeading == null
        ? automaticallyImplyLeading
        : false;

    return AppBar(
      title: title,
      actions: actions,
      leading: effectiveLeading,
      centerTitle: centerTitle,
      automaticallyImplyLeading: effectiveImplyLeading,
      toolbarHeight: height,
      titleSpacing: titleSpacing,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: (blur / 7).clamp(1, 4).toDouble(),
      shadowColor: Colors.black.withAlpha(isDark ? 90 : 36),
      surfaceTintColor: colorScheme.primary.withAlpha(16),
      iconTheme: IconThemeData(color: colorScheme.onSurface),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: colorScheme.outline.withAlpha(40)),
      ),
    );
  }

  Widget? _buildFallbackLeading(BuildContext context) {
    if (leading != null || !automaticallyImplyLeading) return null;

    final navigator = Navigator.maybeOf(context);
    if (navigator != null && navigator.canPop()) return null;

    final currentPath = _currentPath(context);
    if (!_shouldShowFallbackBack(currentPath)) return null;

    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: 'رجوع',
      onPressed: () async {
        final nav = Navigator.maybeOf(context);
        if (nav != null && nav.canPop()) {
          nav.pop();
          return;
        }

        final fallback = _fallbackRouteFor(currentPath);
        if (_normalizePath(currentPath) == _normalizePath(fallback)) return;
        await AppNavigator.pushReplacementNamed(context, fallback);
      },
    );
  }

  bool _shouldShowFallbackBack(String path) {
    final normalized = _normalizePath(path);
    return !_topLevelNoBackRoutes.contains(normalized);
  }

  String _fallbackRouteFor(String path) {
    final normalized = _normalizePath(path);
    if (normalized.startsWith('/admin')) return '/admin/users';
    return '/home';
  }

  String _currentPath(BuildContext context) {
    try {
      final routeData = RouteData.of(context);
      final routePath = routeData.path.trim();
      if (routePath.isNotEmpty) return routePath;
    } catch (_) {}

    final routeInfo = Router.maybeOf(context)?.routeInformationProvider?.value;
    final infoPath = routeInfo?.uri.path.trim() ?? '';
    if (infoPath.isNotEmpty) return infoPath;

    final modalName = ModalRoute.of(context)?.settings.name?.trim() ?? '';
    if (modalName.isNotEmpty) {
      return Uri.parse(modalName).path;
    }

    return '/';
  }

  String _normalizePath(String value) {
    var path = value.trim();
    if (path.isEmpty) return '/';
    if (!path.startsWith('/')) path = '/$path';
    if (path.endsWith('/') && path.length > 1) {
      path = path.substring(0, path.length - 1);
    }
    return path;
  }

  static const Set<String> _topLevelNoBackRoutes = <String>{
    '/',
    '/login',
    '/home',
    '/admin',
    '/admin/login',
    '/admin/users',
    '/admin/orders',
    '/android',
  };
}
