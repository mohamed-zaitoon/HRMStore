// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../admin/admin_login_screen.dart';
import '../auth/user_auth_screen.dart';

class PlatformRouter extends StatelessWidget {
  // EN: Creates PlatformRouter.
  // AR: ينشئ PlatformRouter.
  const PlatformRouter({super.key});

  // EN: Builds widget UI.
  // AR: تبني واجهة الودجت.
  @override
  Widget build(BuildContext context) {
    final path = kIsWeb ? Uri.base.path : "/";

    if (kIsWeb && path.startsWith("/admin")) {
      return const AdminLoginScreen();
    }

    return const UserAuthScreen();
  }
}
