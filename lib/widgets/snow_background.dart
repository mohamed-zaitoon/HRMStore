// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/tt_colors.dart';

class SnowBackground extends StatefulWidget {
  // EN: Creates SnowBackground.
  // AR: ينشئ SnowBackground.
  const SnowBackground({super.key});

  // EN: Creates state object.
  // AR: تنشئ كائن الحالة.
  @override
  State<SnowBackground> createState() => _SnowBackgroundState();
}

class _SnowBackgroundState extends State<SnowBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // EN: Initializes widget state.
  // AR: تهيّئ حالة الودجت.
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  // EN: Releases resources.
  // AR: تفرّغ الموارد.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // EN: Builds widget UI.
  // AR: تبني واجهة الودجت.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isDark = brightness == Brightness.dark;
    final gradientColors = TTColors.backgroundGradientFor(brightness);
    final accentBlue = TTColors.primaryCyan.withAlpha(isDark ? 70 : 48);
    final accentGreen = TTColors.primaryPink.withAlpha(isDark ? 66 : 44);
    final accentGold = TTColors.goldAccent.withAlpha(isDark ? 48 : 34);
    final lineColor = (isDark ? Colors.white : TTColors.primaryCyan).withAlpha(
      isDark ? 15 : 16,
    );
    final dotColor = (isDark ? Colors.white : TTColors.primaryPink).withAlpha(
      isDark ? 20 : 18,
    );

    return IgnorePointer(
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _controller,
              builder: (_, child) {
                final phase = _controller.value;
                final t = phase * math.pi * 2;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: _StorePatternPainter(
                        phase: phase,
                        lineColor: lineColor,
                        dotColor: dotColor,
                      ),
                    ),
                    Positioned(
                      top: -120 + (math.sin(t) * 20),
                      right: -55 + (math.cos(t * 0.9) * 18),
                      child: _GlowingBlob(color: accentBlue, size: 300),
                    ),
                    Positioned(
                      top: 90 + (math.cos(t * 0.8) * 14),
                      left: -90 + (math.sin(t * 0.7) * 16),
                      child: _GlowingBlob(color: accentGreen, size: 250),
                    ),
                    Positioned(
                      bottom: -145 + (math.sin(t * 0.65) * 18),
                      right: 25 + (math.cos(t * 0.6) * 14),
                      child: _GlowingBlob(color: accentGold, size: 280),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StorePatternPainter extends CustomPainter {
  final double phase;
  final Color lineColor;
  final Color dotColor;

  _StorePatternPainter({
    required this.phase,
    required this.lineColor,
    required this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    final dotPaint = Paint()..color = dotColor;
    final offsetX = phase * 64;

    for (int i = -2; i <= 22; i++) {
      final x = i * 82 + offsetX;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x - (size.height * 0.22), size.height),
        linePaint,
      );
    }

    for (double x = -24; x <= size.width + 30; x += 46) {
      for (double y = -24; y <= size.height + 30; y += 46) {
        final wobble = math.sin((x + y) * 0.018 + (phase * math.pi * 2)) * 1.6;
        canvas.drawCircle(Offset(x + wobble, y), 1.0, dotPaint);
      }
    }
  }

  // EN: Handles should Repaint.
  // AR: تتعامل مع should Repaint.
  @override
  bool shouldRepaint(covariant _StorePatternPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.dotColor != dotColor;
}

class _GlowingBlob extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowingBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withAlpha(0)]),
      ),
    );
  }
}
