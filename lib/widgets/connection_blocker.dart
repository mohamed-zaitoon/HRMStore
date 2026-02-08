// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../core/tt_colors.dart';

class ConnectionBlocker extends StatefulWidget {
  final Widget child;

  // EN: Creates ConnectionBlocker.
  // AR: ينشئ ConnectionBlocker.
  const ConnectionBlocker({super.key, required this.child});

  // EN: Creates state object.
  // AR: تنشئ كائن الحالة.
  @override
  State<ConnectionBlocker> createState() => _ConnectionBlockerState();
}

class _ConnectionBlockerState extends State<ConnectionBlocker> {
  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  // EN: Initializes widget state.
  // AR: تهيّئ حالة الودجت.
  @override
  void initState() {
    super.initState();

    _checkInitial();

    _listenToChanges();
  }

  // EN: Checks Initial.
  // AR: تفحص Initial.
  Future<void> _checkInitial() async {
    final List<ConnectivityResult> results = await Connectivity()
        .checkConnectivity();

    _updateFromList(results);
  }

  // EN: Listens to To Changes.
  // AR: تستمع إلى To Changes.
  void _listenToChanges() {
    _sub = Connectivity().onConnectivityChanged.listen(_updateFromList);
  }

  // EN: Updates From List.
  // AR: تحدّث From List.
  void _updateFromList(List<ConnectivityResult> results) {
    final bool hasConnection = !results.contains(ConnectivityResult.none);
    if (_isOnline != hasConnection) {
      setState(() => _isOnline = hasConnection);
    }
  }

  // EN: Handles refresh.
  // AR: تتعامل مع refresh.
  Future<void> _refresh() async {
    await _checkInitial();
    await Future.delayed(const Duration(milliseconds: 500));
  }

  // EN: Releases resources.
  // AR: تفرّغ الموارد.
  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // EN: Builds widget UI.
  // AR: تبني واجهة الودجت.
  @override
  Widget build(BuildContext context) {
    if (_isOnline) return widget.child;

    return Scaffold(
      backgroundColor: TTColors.background,
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: TTColors.primaryCyan,
        backgroundColor: TTColors.cardBg,
        child: Stack(
          children: [
            ListView(),

            Center(
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.wifi_off_rounded,
                      size: 80,
                      color: TTColors.primaryPink,
                    ),

                    const SizedBox(height: 25),

                    const Text(
                      "لا يوجد اتصال بالإنترنت",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      "تأكد من الاتصال ثم اسحب لأسفل لإعادة المحاولة",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: TTColors.textGray,
                        fontFamily: 'Cairo',
                      ),
                    ),

                    const SizedBox(height: 40),
                    ElevatedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text(
                        "إعادة المحاولة الآن",
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TTColors.primaryCyan,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(200, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
