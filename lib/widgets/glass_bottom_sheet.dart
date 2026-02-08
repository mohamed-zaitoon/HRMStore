// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:ui';

import 'package:flutter/material.dart';

class GlassBottomSheet extends StatelessWidget {
  final Widget child;
  final EdgeInsets margin;
  final EdgeInsets padding;
  final double blur;
  final bool showHandle;

  // EN: Creates GlassBottomSheet.
  // AR: ينشئ GlassBottomSheet.
  const GlassBottomSheet({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.fromLTRB(12, 0, 12, 12),
    this.padding = const EdgeInsets.fromLTRB(16, 10, 16, 16),
    this.blur = 18,
    this.showHandle = true,
  });

  // EN: Builds a glassmorphism bottom sheet container.
  // AR: تبني حاوية قائمة زجاجية شفافة.
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final Color base = brightness == Brightness.dark
        ? Colors.black
        : Colors.white;
    final Color tint = base.withOpacity(
      brightness == Brightness.dark ? 0.35 : 0.7,
    );
    final Color borderColor =
        (brightness == Brightness.dark ? Colors.white : Colors.black)
            .withOpacity(0.08);

    return Padding(
      padding: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [tint.withOpacity(0.9), tint.withOpacity(0.75)],
              ),
            ),
            child: Padding(
              padding: padding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showHandle) ...[
                    Container(
                      width: 42,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: borderColor.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ],
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
