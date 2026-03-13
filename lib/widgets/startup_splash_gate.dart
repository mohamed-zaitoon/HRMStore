// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:math' as math;

import 'package:another_flutter_splash_screen/another_flutter_splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/tt_colors.dart';

class StartupSplashGate extends StatelessWidget {
  const StartupSplashGate({
    super.key,
    required this.child,
    required this.enabled,
    this.waitForInitBeforeNextScreen,
  });

  final Widget child;
  final bool enabled;
  final Future<void> Function()? waitForInitBeforeNextScreen;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }

    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;

    final splashHome = waitForInitBeforeNextScreen == null
        ? FlutterSplashScreen.fadeIn(
            duration: const Duration(milliseconds: 950),
            setStateTimer: const Duration(milliseconds: 60),
            animationDuration: const Duration(milliseconds: 550),
            animationCurve: Curves.easeOutQuart,
            backgroundColor: TTColors.backgroundFor(brightness),
            nextScreen: child,
            childWidget: const _StartupSplashBody(),
          )
        : FlutterSplashScreen.fadeIn(
            setStateTimer: const Duration(milliseconds: 60),
            animationDuration: const Duration(milliseconds: 550),
            animationCurve: Curves.easeOutQuart,
            backgroundColor: TTColors.backgroundFor(brightness),
            nextScreen: child,
            asyncNavigationCallback: () async {
              await Future.wait<void>([
                waitForInitBeforeNextScreen!().catchError((_) {}),
                Future<void>.delayed(const Duration(milliseconds: 700)),
              ]);
            },
            childWidget: const _StartupSplashBody(),
          );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: splashHome,
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Cairo',
      scaffoldBackgroundColor: TTColors.backgroundFor(brightness),
    );
  }
}

class _StartupSplashBody extends StatelessWidget {
  const _StartupSplashBody();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _SplashBackdrop(),
            Center(child: _AnimatedAppIcon()),
          ],
        ),
      ),
    );
  }
}

class _SplashBackdrop extends StatefulWidget {
  const _SplashBackdrop();

  @override
  State<_SplashBackdrop> createState() => _SplashBackdropState();
}

class _SplashBackdropState extends State<_SplashBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    final base = TTColors.backgroundFor(brightness);
    final accentA = isDark ? const Color(0xFF162234) : const Color(0xFFE2ECF9);
    final accentB = isDark ? const Color(0xFF1D2C40) : const Color(0xFFF5FAFF);
    final glow = isDark ? const Color(0xFF6FA8FF) : const Color(0xFF8CB9FF);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final orbitX = math.cos(t * 2 * math.pi) * 0.55;
        final orbitY = math.sin(t * 2 * math.pi) * 0.38;
        final blend = (math.sin(t * 2 * math.pi) + 1) / 2;

        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + orbitX, -1 + orbitY),
              end: Alignment(1 - orbitX, 1 - orbitY),
              colors: [
                base,
                Color.lerp(accentA, accentB, blend) ?? accentA,
                base,
              ],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Align(
                alignment: Alignment(orbitX, -0.8),
                child: _BackdropOrb(
                  size: 220,
                  color: glow.withAlpha(isDark ? 90 : 70),
                ),
              ),
              Align(
                alignment: Alignment(-orbitX * 0.9, 0.95),
                child: _BackdropOrb(
                  size: 260,
                  color: glow.withAlpha(isDark ? 54 : 44),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BackdropOrb extends StatelessWidget {
  const _BackdropOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: size * 0.55,
              spreadRadius: size * 0.12,
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedAppIcon extends StatefulWidget {
  const _AnimatedAppIcon();

  @override
  State<_AnimatedAppIcon> createState() => _AnimatedAppIconState();
}

class _AnimatedAppIconState extends State<_AnimatedAppIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1650),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final glowBase = isDark ? const Color(0xFF4B5563) : const Color(0xFF6B7280);
    final ringPrimary = isDark
        ? const Color(0xFF8AB6FF)
        : const Color(0xFF5D8DDA);
    final ringSecondary = isDark
        ? const Color(0xFF2A3E58)
        : const Color(0xFFAEC6E8);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final iconWave = (math.sin(t * 2 * math.pi) + 1) / 2;
        final iconScale = 0.96 + (0.08 * iconWave);
        final glowAlpha = (100 + (90 * iconWave)).round().clamp(0, 255).toInt();
        final borderAlpha = (35 + (40 * iconWave))
            .round()
            .clamp(0, 255)
            .toInt();

        return SizedBox(
          width: 240,
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: ringSecondary.withAlpha(
                      (60 + (36 * iconWave)).round().clamp(0, 255).toInt(),
                    ),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ringPrimary.withAlpha(
                        (35 + (45 * iconWave)).round().clamp(0, 255).toInt(),
                      ),
                      blurRadius: 24 + (14 * iconWave),
                      spreadRadius: 1 + (4 * iconWave),
                    ),
                  ],
                ),
              ),
              Transform.scale(
                scale: iconScale,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withAlpha(borderAlpha),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: glowBase.withAlpha(glowAlpha),
                        blurRadius: 22 + (18 * iconWave),
                        spreadRadius: 2 + (4 * iconWave),
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
