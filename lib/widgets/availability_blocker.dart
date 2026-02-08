// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../core/tt_colors.dart';
import '../services/availability_service.dart';

class AvailabilityBlocker extends StatelessWidget {
  final Widget child;

  // EN: Creates AvailabilityBlocker.
  // AR: ينشئ AvailabilityBlocker.
  const AvailabilityBlocker({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AvailabilityDecision>(
      stream: AvailabilityService.stream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return child;
        }
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: TTColors.cardBg,
            body: const Center(
              child: CircularProgressIndicator(color: TTColors.primaryCyan),
            ),
          );
        }

        final decision = snapshot.data!;
        if (decision.allowed) return child;

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
                    Icon(
                      decision.maintenance
                          ? Icons.construction
                          : Icons.schedule,
                      size: 64,
                      color: TTColors.primaryPink,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      decision.maintenance
                          ? "الشحن غير متاح حاليا"
                          : "نحن خارج مواعيد العمل",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      decision.message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: TTColors.textGray,
                        height: 1.4,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "أعد المحاولة لاحقًا.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: TTColors.textGray,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (!kIsWeb)
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Text("حسنا"),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
