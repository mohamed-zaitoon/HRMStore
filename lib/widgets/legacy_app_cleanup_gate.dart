// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../core/app_navigator.dart';
import '../services/legacy_app_cleanup_service.dart';

class LegacyAppCleanupGate extends StatefulWidget {
  final Widget child;

  const LegacyAppCleanupGate({
    super.key,
    required this.child,
  });

  @override
  State<LegacyAppCleanupGate> createState() => _LegacyAppCleanupGateState();
}

class _LegacyAppCleanupGateState extends State<LegacyAppCleanupGate>
    with WidgetsBindingObserver {
  bool _dialogOpen = false;
  bool _checking = false;
  bool _shownNoLegacyOnce = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _maybePrompt();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybePrompt();
    }
  }

  void _maybePrompt() {
    if (!mounted) return;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (_dialogOpen || _checking) return;

    final navContext = AppNavigator.context;
    if (navContext == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybePrompt());
      return;
    }

    _checking = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final activeContext = AppNavigator.context;
      if (activeContext == null) {
        _checking = false;
        return;
      }
      final installed = await LegacyAppCleanupService.detectInstalled();
      _checking = false;
      if (!mounted || _dialogOpen) return;

      final bool hasInstalled = installed.isNotEmpty;
      if (!hasInstalled && _shownNoLegacyOnce) return;
      if (!hasInstalled) _shownNoLegacyOnce = true;

      final appsToShow =
          hasInstalled ? installed : LegacyAppCleanupService.legacyApps;

      _dialogOpen = true;
      await showDialog<void>(
        context: activeContext,
        barrierDismissible: false,
        builder: (dialogContext) {
          return PopScope(
            canPop: false,
            child: AlertDialog(
              title: const Text('إزالة النسخة القديمة'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'تحقق من النسخ القديمة.\n'
                    'إذا كانت موجودة يُفضل حذفها لتجنب التعارض.',
                  ),
                  const SizedBox(height: 12),
                  ...appsToShow.map((app) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(child: Text(app.label)),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              LegacyAppCleanupService.requestUninstall(
                                app.packageName,
                              );
                            },
                            child: const Text('إزالة'),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
              actions: hasInstalled
                  ? null
                  : [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('متابعة'),
                      ),
                    ],
            ),
          );
        },
      );
      LegacyAppCleanupService.notifyCleanupDialogClosed();
      _dialogOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
