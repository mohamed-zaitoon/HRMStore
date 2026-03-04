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
    final viewportSize = MediaQuery.sizeOf(context);
    final canvasWidth = viewportSize.width;
    final shortestSide = math.min(viewportSize.width, viewportSize.height);
    final bool isTabletLike = shortestSide >= 600;
    final bool isLargeLayout = canvasWidth >= 1024 || isTabletLike;
    final bool isCompactLayout = !isLargeLayout && canvasWidth < 700;
    final gradientColors = TTColors.backgroundGradientFor(brightness);
    final accentBlue = TTColors.primaryCyan.withAlpha(isDark ? 70 : 48);
    final accentGreen = TTColors.primaryPink.withAlpha(isDark ? 66 : 44);
    final accentGold = TTColors.goldAccent.withAlpha(isDark ? 48 : 34);
    final pyramidSand = Color.alphaBlend(
      theme.colorScheme.surface.withAlpha(isDark ? 60 : 26),
      TTColors.goldAccent.withAlpha(isDark ? 94 : 66),
    );
    final pyramidShade = Color.alphaBlend(
      theme.colorScheme.primary.withAlpha(isDark ? 52 : 34),
      TTColors.brandEmerald.withAlpha(isDark ? 56 : 30),
    );
    final pyramidRidge = Color.alphaBlend(
      theme.colorScheme.outline.withAlpha(isDark ? 132 : 110),
      TTColors.goldAccent.withAlpha(isDark ? 58 : 42),
    );
    final pyramidGlow = TTColors.goldAccent.withAlpha(isDark ? 38 : 26);
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
            _PyramidBackdrop(
              isLargeLayout: isLargeLayout,
              isCompactLayout: isCompactLayout,
              sandColor: pyramidSand,
              shadeColor: pyramidShade,
              ridgeColor: pyramidRidge,
              glowColor: pyramidGlow,
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

class _PyramidBackdrop extends StatelessWidget {
  final bool isLargeLayout;
  final bool isCompactLayout;
  final Color sandColor;
  final Color shadeColor;
  final Color ridgeColor;
  final Color glowColor;

  const _PyramidBackdrop({
    required this.isLargeLayout,
    required this.isCompactLayout,
    required this.sandColor,
    required this.shadeColor,
    required this.ridgeColor,
    required this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return CustomPaint(
            size: size,
            painter: _PyramidBackdropPainter(
              isLargeLayout: isLargeLayout,
              isCompactLayout: isCompactLayout,
              sandColor: sandColor,
              shadeColor: shadeColor,
              ridgeColor: ridgeColor,
              glowColor: glowColor,
            ),
          );
        },
      ),
    );
  }
}

class _PyramidBackdropPainter extends CustomPainter {
  final bool isLargeLayout;
  final bool isCompactLayout;
  final Color sandColor;
  final Color shadeColor;
  final Color ridgeColor;
  final Color glowColor;

  _PyramidBackdropPainter({
    required this.isLargeLayout,
    required this.isCompactLayout,
    required this.sandColor,
    required this.shadeColor,
    required this.ridgeColor,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    if (isLargeLayout) {
      _paintLargeLayout(canvas, size);
      return;
    }
    _paintCompactLayout(canvas, size);
  }

  void _paintLargeLayout(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    final rightGlowCenter = Offset(width * 0.88, height * 0.78);
    final rightGlowRadius = math.min(width, height) * 0.42;
    final rightGlowRect = Rect.fromCircle(
      center: rightGlowCenter,
      radius: rightGlowRadius,
    );
    canvas.drawCircle(
      rightGlowCenter,
      rightGlowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [glowColor.withAlpha(52), glowColor.withAlpha(0)],
        ).createShader(rightGlowRect),
    );

    final leftGlowCenter = Offset(width * 0.12, height * 0.82);
    final leftGlowRadius = math.min(width, height) * 0.32;
    final leftGlowRect = Rect.fromCircle(
      center: leftGlowCenter,
      radius: leftGlowRadius,
    );
    canvas.drawCircle(
      leftGlowCenter,
      leftGlowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [glowColor.withAlpha(34), glowColor.withAlpha(0)],
        ).createShader(leftGlowRect),
    );

    _drawPyramid(
      canvas,
      apex: Offset(width * 0.86, height * 0.30),
      baseY: height * 0.93,
      baseWidth: math.min(width * 0.48, 600),
      linesCount: 11,
      alphaScale: 1,
      strokeScale: 1.05,
    );

    _drawPyramid(
      canvas,
      apex: Offset(width * 0.70, height * 0.40),
      baseY: height * 0.90,
      baseWidth: math.min(width * 0.30, 320),
      linesCount: 8,
      alphaScale: 0.56,
      strokeScale: 0.9,
    );

    _drawPyramid(
      canvas,
      apex: Offset(width * 0.98, height * 0.47),
      baseY: height * 0.89,
      baseWidth: math.min(width * 0.18, 190),
      linesCount: 6,
      alphaScale: 0.42,
      strokeScale: 0.82,
    );

    _drawPyramid(
      canvas,
      apex: Offset(width * 0.15, height * 0.37),
      baseY: height * 0.94,
      baseWidth: math.min(width * 0.34, 430),
      linesCount: 8,
      alphaScale: 0.5,
      strokeScale: 0.92,
    );

    _drawPyramid(
      canvas,
      apex: Offset(width * 0.04, height * 0.52),
      baseY: height * 0.91,
      baseWidth: math.min(width * 0.20, 230),
      linesCount: 6,
      alphaScale: 0.36,
      strokeScale: 0.84,
    );
  }

  void _paintCompactLayout(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    final alphaScale = isCompactLayout ? 0.32 : 0.42;
    final glowCenter = Offset(width * 0.52, height * 0.86);
    final glowRadius = math.min(width, height) * (isCompactLayout ? 0.55 : 0.5);
    final glowRect = Rect.fromCircle(center: glowCenter, radius: glowRadius);

    canvas.drawCircle(
      glowCenter,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [glowColor.withAlpha(34), glowColor.withAlpha(0)],
        ).createShader(glowRect),
    );

    _drawPyramid(
      canvas,
      apex: Offset(width * 0.52, height * (isCompactLayout ? 0.49 : 0.46)),
      baseY: height * 0.98,
      baseWidth: width * (isCompactLayout ? 0.88 : 0.72),
      linesCount: isCompactLayout ? 7 : 8,
      alphaScale: alphaScale,
      strokeScale: 0.95,
    );
  }

  void _drawPyramid(
    Canvas canvas, {
    required Offset apex,
    required double baseY,
    required double baseWidth,
    required int linesCount,
    required double alphaScale,
    required double strokeScale,
  }) {
    final clampedAlpha = alphaScale.clamp(0.0, 1.0);
    final halfWidth = baseWidth / 2;
    final leftBase = Offset(apex.dx - halfWidth, baseY);
    final rightBase = Offset(apex.dx + halfWidth, baseY);
    final baseCenter = Offset(apex.dx, baseY);
    final trianglePath = Path()
      ..moveTo(apex.dx, apex.dy)
      ..lineTo(leftBase.dx, leftBase.dy)
      ..lineTo(rightBase.dx, rightBase.dy)
      ..close();

    final leftFacePath = Path()
      ..moveTo(apex.dx, apex.dy)
      ..lineTo(leftBase.dx, leftBase.dy)
      ..lineTo(baseCenter.dx, baseCenter.dy)
      ..close();
    final rightFacePath = Path()
      ..moveTo(apex.dx, apex.dy)
      ..lineTo(baseCenter.dx, baseCenter.dy)
      ..lineTo(rightBase.dx, rightBase.dy)
      ..close();

    final leftFill = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomLeft,
            colors: [
              sandColor.withAlpha((255 * clampedAlpha * 0.82).round()),
              shadeColor.withAlpha((255 * clampedAlpha * 0.55).round()),
            ],
          ).createShader(
            Rect.fromPoints(
              Offset(leftBase.dx, apex.dy),
              Offset(baseCenter.dx, baseY),
            ),
          );
    final rightFill = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomRight,
            colors: [
              sandColor.withAlpha((255 * clampedAlpha * 0.62).round()),
              shadeColor.withAlpha((255 * clampedAlpha * 0.88).round()),
            ],
          ).createShader(
            Rect.fromPoints(
              Offset(baseCenter.dx, apex.dy),
              Offset(rightBase.dx, baseY),
            ),
          );

    canvas.drawPath(leftFacePath, leftFill);
    canvas.drawPath(rightFacePath, rightFill);

    final edgePaint = Paint()
      ..color = ridgeColor.withAlpha((255 * clampedAlpha * 0.75).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * strokeScale;
    canvas.drawPath(trianglePath, edgePaint);

    final seamPaint = Paint()
      ..color = ridgeColor.withAlpha((255 * clampedAlpha * 0.68).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.95 * strokeScale;
    canvas.drawLine(apex, baseCenter, seamPaint);

    final layerPaint = Paint()
      ..color = ridgeColor.withAlpha((255 * clampedAlpha * 0.35).round())
      ..strokeWidth = 0.7 * strokeScale;
    for (int i = 1; i <= linesCount; i++) {
      final t = i / (linesCount + 1);
      final y = apex.dy + ((baseY - apex.dy) * t);
      final half = halfWidth * t;
      canvas.drawLine(
        Offset(apex.dx - half, y),
        Offset(apex.dx + half, y),
        layerPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PyramidBackdropPainter oldDelegate) =>
      oldDelegate.isLargeLayout != isLargeLayout ||
      oldDelegate.isCompactLayout != isCompactLayout ||
      oldDelegate.sandColor != sandColor ||
      oldDelegate.shadeColor != shadeColor ||
      oldDelegate.ridgeColor != ridgeColor ||
      oldDelegate.glowColor != glowColor;
}
