// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:another_flutter_splash_screen/another_flutter_splash_screen.dart';
import 'package:card_loading/card_loading.dart';
import 'package:flutter/material.dart';

import '../core/app_info.dart';
import '../core/tt_colors.dart';

class StartupSplashGate extends StatelessWidget {
  const StartupSplashGate({
    super.key,
    required this.child,
    required this.enabled,
  });

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }

    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: FlutterSplashScreen.fadeIn(
        duration: const Duration(milliseconds: 1700),
        setStateTimer: const Duration(milliseconds: 120),
        backgroundColor: TTColors.backgroundFor(brightness),
        nextScreen: child,
        childWidget: const _StartupSplashBody(),
      ),
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
    final brightness = Theme.of(context).brightness;
    final textColor = TTColors.textFor(brightness);
    final loadingTheme = _loadingTheme(brightness);

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(
                          brightness == Brightness.dark ? 80 : 20,
                        ),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: const _AnimatedAppIcon(),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  AppInfo.appName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontFamily: 'Cairo',
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 24),
                CardLoading(
                  height: 13,
                  borderRadius: BorderRadius.circular(99),
                  cardLoadingTheme: loadingTheme,
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Expanded(
                      child: CardLoading(
                        height: 11,
                        borderRadius: BorderRadius.circular(99),
                        cardLoadingTheme: loadingTheme,
                      ),
                    ),
                    const SizedBox(width: 9),
                    SizedBox(
                      width: 88,
                      child: CardLoading(
                        height: 11,
                        borderRadius: BorderRadius.circular(99),
                        cardLoadingTheme: loadingTheme,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                CardLoading(
                  height: 64,
                  borderRadius: BorderRadius.circular(18),
                  cardLoadingTheme: loadingTheme,
                ),
              ],
            ),
          ),
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
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<double> _scale = Tween<double>(
    begin: 0.92,
    end: 1.04,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Image.asset(
        'assets/icon/app_icon.png',
        width: 104,
        height: 104,
        fit: BoxFit.cover,
      ),
    );
  }
}

CardLoadingTheme _loadingTheme(Brightness brightness) {
  return CardLoadingTheme(
    colorOne: brightness == Brightness.dark
        ? const Color(0xFF1F2632)
        : const Color(0xFFE6EBF2),
    colorTwo: brightness == Brightness.dark
        ? const Color(0xFF2A3342)
        : const Color(0xFFF4F7FB),
  );
}
