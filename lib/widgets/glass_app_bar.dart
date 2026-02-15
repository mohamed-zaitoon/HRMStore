// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:flutter/material.dart';

import '../core/tt_colors.dart';

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

    return AppBar(
      title: title,
      actions: actions,
      leading: leading,
      centerTitle: centerTitle,
      automaticallyImplyLeading: automaticallyImplyLeading,
      toolbarHeight: height,
      titleSpacing: titleSpacing,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: (blur / 7).clamp(1, 4).toDouble(),
      shadowColor: Colors.black.withAlpha(isDark ? 90 : 36),
      surfaceTintColor: colorScheme.primary.withAlpha(16),
      iconTheme: IconThemeData(color: TTColors.textWhite),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: colorScheme.outline.withAlpha(40)),
      ),
    );
  }
}
