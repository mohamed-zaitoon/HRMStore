// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:flutter/material.dart';

import '../../core/app_navigator.dart';
import '../../services/admin_session_service.dart';
import '../../widgets/snow_background.dart';

class AdminRouteGuard extends StatefulWidget {
  final Widget child;

  const AdminRouteGuard({super.key, required this.child});

  @override
  State<AdminRouteGuard> createState() => _AdminRouteGuardState();
}

class _AdminRouteGuardState extends State<AdminRouteGuard> {
  bool _checking = true;
  bool _allowed = false;

  @override
  void initState() {
    super.initState();
    _validateSession();
  }

  Future<void> _validateSession() async {
    final allowed = await AdminSessionService.validateCurrentSession();

    if (!mounted) return;

    if (!allowed) {
      await AdminSessionService.clearLocalSession();
    }

    if (!mounted) return;
    setState(() {
      _allowed = allowed;
      _checking = false;
    });

    if (!allowed && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AppNavigator.pushNamedAndRemoveUntil(
          context,
          '/admin',
          (route) => false,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Stack(
          children: [
            SnowBackground(),
            Center(child: CircularProgressIndicator()),
          ],
        ),
      );
    }

    if (!_allowed) {
      return const Scaffold(
        body: Stack(
          children: [
            SnowBackground(),
            Center(child: CircularProgressIndicator()),
          ],
        ),
      );
    }

    return widget.child;
  }
}
