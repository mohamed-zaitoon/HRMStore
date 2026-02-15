// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/tt_colors.dart';
import '../services/access_control_service.dart';
import '../services/integrity_service.dart';

class AccessBlocker extends StatefulWidget {
  final Widget child;

  // EN: Creates AccessBlocker.
  // AR: ينشئ AccessBlocker.
  const AccessBlocker({super.key, required this.child});

  @override
  State<AccessBlocker> createState() => _AccessBlockerState();
}

class _AccessBlockerState extends State<AccessBlocker> {
  bool _checking = true;
  AccessDecision _decision = const AccessDecision.allow();

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final decision = await AccessControlService.checkAccess();
    var resolvedDecision = decision;
    if (decision.allowed) {
      final integrityOk = await IntegrityService.verify();
      if (!integrityOk) {
        resolvedDecision = const AccessDecision(
          allowed: false,
          reason: 'integrity',
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _decision = resolvedDecision;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return Scaffold(
        backgroundColor: TTColors.cardBg,
        body: const Center(
          child: CircularProgressIndicator(color: TTColors.primaryCyan),
        ),
      );
    }

    if (_decision.allowed) {
      return widget.child;
    }

    return Scaffold(
      backgroundColor: TTColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.block, size: 64, color: TTColors.primaryPink),
                const SizedBox(height: 16),
                const Text(
                  "الموقع/التطبيق غير متاح",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _decision.reason == 'integrity'
                      ? "تم اكتشاف نسخة غير موثوقة من التطبيق. استخدم النسخة الرسمية فقط."
                      : "يرجى التأكد أن موقعك غير محظور.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: TTColors.textGray,
                    height: 1.4,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: _checkAccess,
                      child: const Text("إعادة المحاولة"),
                    ),
                    const SizedBox(width: 12),
                    if (!kIsWeb)
                      ElevatedButton(
                        onPressed: () => SystemNavigator.pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TTColors.primaryPink,
                        ),
                        child: const Text("خروج"),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
