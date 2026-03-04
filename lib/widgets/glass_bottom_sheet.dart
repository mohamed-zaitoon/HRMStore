// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

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

  // EN: Builds a Material bottom sheet container.
  // AR: تبني حاوية قائمة بنمط Material.
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double elevationValue = (blur / 3).clamp(8, 20).toDouble();
    final Color borderColor = colorScheme.outline.withAlpha(isDark ? 90 : 45);

    return Padding(
      padding: margin,
      child: Material(
        elevation: elevationValue,
        shadowColor: Colors.black.withAlpha(isDark ? 110 : 46),
        color: Theme.of(context).cardColor,
        surfaceTintColor: colorScheme.primary.withAlpha(16),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
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
                      color: borderColor,
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
    );
  }
}
