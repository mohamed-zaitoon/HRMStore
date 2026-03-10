// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';

import '../core/tt_colors.dart';
import '../services/network_health_service.dart';

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
  bool _firestoreNetworkEnabled = true;
  int _probeGeneration = 0;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  // EN: Initializes widget state.
  // AR: تهيّئ حالة الودجت.
  @override
  void initState() {
    super.initState();

    unawaited(_checkInitial());

    _listenToChanges();
  }

  // EN: Checks Initial.
  // AR: تفحص Initial.
  Future<void> _checkInitial() async {
    final List<ConnectivityResult> results = await Connectivity()
        .checkConnectivity();

    await _syncNetworkState(results);
  }

  // EN: Listens to To Changes.
  // AR: تستمع إلى To Changes.
  void _listenToChanges() {
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      unawaited(_syncNetworkState(results));
    });
  }

  // EN: Syncs UI/network state from connectivity + endpoint reachability.
  // AR: يزامن حالة الواجهة/الشبكة من الاتصال ونقطة الوصول الحقيقية.
  Future<void> _syncNetworkState(List<ConnectivityResult> results) async {
    final bool hasTransport = !results.contains(ConnectivityResult.none);

    if (!hasTransport) {
      _setOnline(false);
      await _setFirestoreNetwork(enabled: false);
      return;
    }

    final int generation = ++_probeGeneration;
    final bool canReachFirestore = await _probeFirestoreReachability();
    if (!mounted || generation != _probeGeneration) return;

    _setOnline(canReachFirestore);
    await _setFirestoreNetwork(enabled: canReachFirestore);
  }

  // EN: Probes Firestore host to detect real online state.
  // AR: يفحص خادم Firestore لاكتشاف الحالة الفعلية للاتصال.
  Future<bool> _probeFirestoreReachability() async {
    return NetworkHealthService.canReachFirestore();
  }

  // EN: Updates online flag safely.
  // AR: يحدّث حالة الاتصال بشكل آمن.
  void _setOnline(bool hasConnection) {
    if (!mounted || _isOnline == hasConnection) return;
    setState(() => _isOnline = hasConnection);
  }

  // EN: Enables/disables Firestore network to avoid noisy retries.
  // AR: يفعّل/يعطّل شبكة Firestore لتقليل محاولات إعادة الاتصال المزعجة.
  Future<void> _setFirestoreNetwork({required bool enabled}) async {
    if (_firestoreNetworkEnabled == enabled) return;

    final didSet = await NetworkHealthService.setFirestoreNetwork(
      enabled: enabled,
    );
    if (didSet) {
      _firestoreNetworkEnabled = enabled;
    }
  }

  // EN: Handles refresh.
  // AR: تتعامل مع refresh.
  Future<void> _refresh() async {
    await _checkInitial();
  }

  // EN: Releases resources.
  // AR: تفرّغ الموارد.
  @override
  void dispose() {
    _probeGeneration++;
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
      body: CustomMaterialIndicator(
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
                      "تعذر الوصول لخوادم التطبيق. تأكد من DNS أو VPN ثم اسحب لإعادة المحاولة",
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
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimary,
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
