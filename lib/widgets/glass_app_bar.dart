// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:ui';

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

  // EN: Builds a glassmorphism app bar.
  // AR: تبني شريط علوي زجاجي.
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final Color base = brightness == Brightness.dark
        ? Colors.black
        : Colors.white;
    final Color tint = base.withValues(
      alpha: brightness == Brightness.dark ? 0.35 : 0.7,
    );
    final Color borderColor =
        (brightness == Brightness.dark ? Colors.white : Colors.black)
            .withValues(alpha: 0.08);

    return AppBar(
      title: title,
      actions: actions,
      leading: leading,
      centerTitle: centerTitle,
      automaticallyImplyLeading: automaticallyImplyLeading,
      toolbarHeight: height,
      titleSpacing: titleSpacing,
      backgroundColor: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: TTColors.textWhite),
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            decoration: BoxDecoration(
              color: tint,
              border: Border(bottom: BorderSide(color: borderColor, width: 1)),
            ),
          ),
        ),
      ),
    );
  }
}
