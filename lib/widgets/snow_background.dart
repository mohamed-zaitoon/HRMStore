// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:flutter/material.dart';

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
  late AnimationController _c;

  // EN: Initializes widget state.
  // AR: تهيّئ حالة الودجت.
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 15))
      ..repeat();
  }

  // EN: Releases resources.
  // AR: تفرّغ الموارد.
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // EN: Builds widget UI.
  // AR: تبني واجهة الودجت.
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final gradientColors = isDark
        ? const [
            Color(0xFF0A0F1C),
            Color(0xFF0F1D2F),
            Color(0xFF0B1323),
          ]
        : const [
            Color(0xFFF7FBFF),
            Color(0xFFEAF4FF),
            Color(0xFFE9FFF8),
          ];

    final accent1 = isDark
        ? const Color(0xFF1E3A8A).withValues(alpha: 0.25)
        : const Color(0xFF3B82F6).withValues(alpha: 0.18);
    final accent2 = isDark
        ? const Color(0xFF0EA5E9).withValues(alpha: 0.22)
        : const Color(0xFF06B6D4).withValues(alpha: 0.18);

    return SizedBox.expand(
      child: Stack(
        children: [
          // خلفية متدرجة ناعمة
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
            ),
          ),

          // بقع ضوء خفيفة لإحساس حيوي
          Positioned(
            top: -120,
            left: -40,
            child: _GlowingBlob(color: accent1, size: 260),
          ),
          Positioned(
            bottom: -140,
            right: -60,
            child: _GlowingBlob(color: accent2, size: 300),
          ),

          // طبقة الثلج/النجوم المتحركة
          AnimatedBuilder(
            animation: _c,
            builder: (_, __) => CustomPaint(
              painter: _SnowPainter(_c.value, isDark: isDark),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }
}

class _SnowPainter extends CustomPainter {
  final double val;
   final bool isDark;

  _SnowPainter(this.val, {required this.isDark});

  // EN: Handles paint.
  // AR: تتعامل مع paint.
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withAlpha(isDark ? 18 : 16);
    for (int i = 0; i < 50; i++) {
      final y = (val * s.height + (i * 35)) % s.height;
      c.drawCircle(Offset((i * 23.0) % s.width, y), 1.5, p);
    }
  }

  // EN: Handles should Repaint.
  // AR: تتعامل مع should Repaint.
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
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
        gradient: RadialGradient(
          colors: [
            color,
            color.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}
