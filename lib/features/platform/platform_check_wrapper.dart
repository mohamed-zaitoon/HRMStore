// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;

import '../../core/tt_colors.dart';
import '../auth/user_auth_screen.dart';
import 'android_landing_page.dart';

class PlatformCheckWrapper extends StatefulWidget {
  // EN: Creates PlatformCheckWrapper.
  // AR: ينشئ PlatformCheckWrapper.
  const PlatformCheckWrapper({super.key});

  // EN: Creates state object.
  // AR: تنشئ كائن الحالة.
  @override
  State<PlatformCheckWrapper> createState() => _PlatformCheckWrapperState();
}

class _PlatformCheckWrapperState extends State<PlatformCheckWrapper> {
  bool _isAndroidWeb = false;
  bool _checkingLogin = true;

  // EN: Initializes widget state.
  // AR: تهيّئ حالة الودجت.
  @override
  void initState() {
    super.initState();

    _checkPlatformAndLogin();
  }

  // EN: Checks Platform And Login.
  // AR: تفحص Platform And Login.
  Future<void> _checkPlatformAndLogin() async {
    if (kIsWeb) {
      final userAgent = html.window.navigator.userAgent.toLowerCase();
      if (userAgent.contains('android')) {
        setState(() {
          _isAndroidWeb = true;
          _checkingLogin = false;
        });
        return;
      }
    }

    if (mounted) setState(() => _checkingLogin = false);
  }

  // EN: Builds widget UI.
  // AR: تبني واجهة الودجت.
  @override
  Widget build(BuildContext context) {
    if (_isAndroidWeb) return const AndroidLandingPage();
    if (_checkingLogin) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: TTColors.primaryCyan),
        ),
      );
    }
    return const UserAuthScreen();
  }
}
