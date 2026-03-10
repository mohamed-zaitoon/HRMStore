// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  ThemeService._();

  static const String _key = 'theme_mode';

  static final ValueNotifier<ThemeMode> modeNotifier = ValueNotifier<ThemeMode>(
    ThemeMode.system,
  );
  static ColorScheme? _dynamicLightScheme;
  static ColorScheme? _dynamicDarkScheme;

  // EN: Sets dynamic color schemes.
  // AR: تضبط مخططات الألوان الديناميكية.
  static void setDynamicSchemes(ColorScheme? light, ColorScheme? dark) {
    _dynamicLightScheme = light;
    _dynamicDarkScheme = dark;
  }

  // EN: Gets dynamic scheme by brightness.
  // AR: تجلب المخطط الديناميكي حسب السطوع.
  static ColorScheme? schemeFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? _dynamicDarkScheme
        : _dynamicLightScheme;
  }

  // EN: Initializes init.
  // AR: تهيّئ init.
  static void init(SharedPreferences prefs) {
    final saved = prefs.getString(_key);
    modeNotifier.value = _parse(saved);
  }

  // EN: Sets Mode.
  // AR: تضبط Mode.
  static Future<void> setMode(ThemeMode mode, SharedPreferences prefs) async {
    modeNotifier.value = mode;
    await prefs.setString(_key, _encode(mode));
  }

  // EN: Parses parse.
  // AR: تحلّل parse.
  static ThemeMode _parse(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
    }
    return ThemeMode.system;
  }

  // EN: Handles encode.
  // AR: تتعامل مع encode.
  static String _encode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
