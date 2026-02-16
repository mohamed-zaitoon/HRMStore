// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:flutter/material.dart';

import '../services/theme_service.dart';

class TTColors {
  static const Color brandBlue = Color(0xFF4B5563);
  static const Color brandEmerald = Color(0xFF374151);
  static const Color brandGold = Color(0xFFF59E0B);

  // المحافظة على الأسماء القديمة لتجنّب كسر الاستدعاءات في المشروع.
  static const Color primaryCyan = brandBlue;
  static const Color primaryPink = brandEmerald;
  static const Color goldAccent = brandGold;

  static const Color _darkBackground = Color(0xFF0F1115);
  static const Color _darkCard = Color(0xFF171A20);
  static const Color _darkText = Color(0xFFF3F4F6);
  static const Color _darkTextMuted = Color(0xFF9CA3AF);

  static const Color _lightBackground = Color(0xFFFFFFFF);
  static const Color _lightCard = Color(0xFFFFFFFF);
  static const Color _lightText = Color(0xFF111827);
  static const Color _lightTextMuted = Color(0xFF6B7280);

  // EN: Gets background color for brightness.
  // AR: تجلب لون الخلفية حسب السطوع.
  static Color backgroundFor(Brightness brightness) =>
      brightness == Brightness.dark ? _darkBackground : _lightBackground;

  // EN: Gets card background color for brightness.
  // AR: تجلب لون البطاقات حسب السطوع.
  static Color cardBgFor(Brightness brightness) =>
      brightness == Brightness.dark ? _darkCard : _lightCard;

  // EN: Gets text color for brightness.
  // AR: تجلب لون النص حسب السطوع.
  static Color textFor(Brightness brightness) =>
      brightness == Brightness.dark ? _darkText : _lightText;

  // EN: Gets muted text color for brightness.
  // AR: تجلب لون النص الخافت حسب السطوع.
  static Color textMutedFor(Brightness brightness) =>
      brightness == Brightness.dark ? _darkTextMuted : _lightTextMuted;

  // EN: Gets gradient colors for branded app background.
  // AR: تجلب ألوان التدرج لخلفية التطبيق.
  static List<Color> backgroundGradientFor(Brightness brightness) =>
      brightness == Brightness.dark
      ? const [Color(0xFF0F1115), Color(0xFF15181F), Color(0xFF1A1E26)]
      : const [Color(0xFFFFFFFF), Color(0xFFFAFAFA), Color(0xFFF2F4F7)];

  // EN: Handles is Dark.
  // AR: تتعامل مع is Dark.
  static bool get _isDark {
    final mode = ThemeService.modeNotifier.value;
    if (mode == ThemeMode.dark) return true;
    if (mode == ThemeMode.light) return false;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
  }

  // EN: Gets background color from current theme.
  // AR: تجلب لون الخلفية من الثيم الحالي.
  static Color get background =>
      backgroundFor(_isDark ? Brightness.dark : Brightness.light);

  // EN: Gets card background from current theme.
  // AR: تجلب خلفية البطاقات من الثيم الحالي.
  static Color get cardBg =>
      cardBgFor(_isDark ? Brightness.dark : Brightness.light);

  // EN: Gets text color from current theme.
  // AR: تجلب لون النص من الثيم الحالي.
  static Color get textWhite =>
      textFor(_isDark ? Brightness.dark : Brightness.light);

  // EN: Gets muted text color from current theme.
  // AR: تجلب لون النص الخافت من الثيم الحالي.
  static Color get textGray =>
      textMutedFor(_isDark ? Brightness.dark : Brightness.light);
}
