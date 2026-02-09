// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:ui';

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
    this.blur = 18,
    this.radius = 18,
    this.borderColor,
    this.tint,
  });

  // EN: Builds a glassmorphism card.
  // AR: تبني بطاقة زجاجية.
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final Color base =
        brightness == Brightness.dark ? Colors.black : Colors.white;
    final Color fill = tint ??
        base.withValues(alpha: brightness == Brightness.dark ? 0.32 : 0.7);
    final Color border = borderColor ??
        (brightness == Brightness.dark ? Colors.white : Colors.black)
            .withValues(alpha: 0.08);

    return Padding(
      padding: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: border, width: 1),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  fill.withValues(alpha: 0.9),
                  fill.withValues(alpha: 0.75),
                ],
              ),
            ),
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
