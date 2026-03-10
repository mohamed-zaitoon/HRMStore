// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/theme_service.dart';
import '../widgets/glass_bottom_sheet.dart';

// EN: Shows Theme Mode Sheet.
// AR: تعرض Theme Mode Sheet.
Future<void> showThemeModeSheet(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        child: GlassBottomSheet(
          child: ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeService.modeNotifier,
            builder: (context, mode, _) {
              return RadioGroup<ThemeMode>(
                groupValue: mode,
                onChanged: (value) async {
                  if (value == null) return;
                  await ThemeService.setMode(value, prefs);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "اختيار وضع التطبيق",
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 10),
                    const RadioListTile<ThemeMode>(
                      value: ThemeMode.system,
                      title: Text('تلقائي (حسب النظام)'),
                    ),
                    const RadioListTile<ThemeMode>(
                      value: ThemeMode.dark,
                      title: Text('داكن'),
                    ),
                    const RadioListTile<ThemeMode>(
                      value: ThemeMode.light,
                      title: Text('فاتح'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    },
  );
}
