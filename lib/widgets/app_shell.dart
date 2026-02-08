// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:flutter/material.dart';
import 'snow_background.dart';

class AppShell extends StatelessWidget {
  final Widget child;

  // EN: Creates AppShell.
  // AR: ينشئ AppShell.
  const AppShell({super.key, required this.child});

  // EN: Builds widget UI.
  // AR: تبني واجهة الودجت.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const SnowBackground(),

          Center(child: child),
        ],
      ),
    );
  }
}
