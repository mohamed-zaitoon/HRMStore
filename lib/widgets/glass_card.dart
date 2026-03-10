// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets margin;
  final EdgeInsets padding;
  final double blur;
  final double radius;
  final Color? borderColor;
  final Color? tint;

  // EN: Creates GlassCard.
  // AR: ينشئ GlassCard.
  const GlassCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.symmetric(vertical: 10),
    this.padding = const EdgeInsets.all(18),
    this.blur = 20,
    this.radius = 22,
    this.borderColor,
    this.tint,
  });

  // EN: Builds a Material card.
  // AR: تبني بطاقة Material.
  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final Color fill = tint ?? Theme.of(context).cardColor;
    final Color border =
        borderColor ?? colorScheme.outlineVariant.withAlpha(isDark ? 180 : 210);
    final double elevationValue = (blur / 9).clamp(1.2, 4.2).toDouble();

    return Padding(
      padding: margin,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: elevationValue,
        shadowColor: Colors.black.withAlpha(isDark ? 90 : 28),
        surfaceTintColor: colorScheme.primary.withAlpha(isDark ? 24 : 12),
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: border),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
