// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;

import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

import '../../core/tt_colors.dart';
import '../../utils/url_sanitizer.dart';
import '../../widgets/snow_background.dart';

const String GITHUB_USER = "mohamed-zaitoon";
const String GITHUB_REPO = "HRMStore";

class AndroidLandingPage extends StatefulWidget {
  // EN: Creates AndroidLandingPage.
  // AR: ينشئ AndroidLandingPage.
  const AndroidLandingPage({super.key});

  // EN: Creates state object.
  // AR: تنشئ كائن الحالة.
  @override
  State<AndroidLandingPage> createState() => _AndroidLandingPageState();
}

class _AndroidLandingPageState extends State<AndroidLandingPage> {
  bool _isLoading = true;
  final List<_ApkAsset> _apkAssets = [];

  // EN: Initializes widget state.
  // AR: تهيّئ حالة الودجت.
  @override
  void initState() {
    super.initState();

    _fetchLatestApks();
  }

  // EN: Fetches Latest Apks.
  // AR: تجلب Latest Apks.
  Future<void> _fetchLatestApks() async {
    try {
      final res = await http.get(
        Uri.parse(
          "https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO/releases/latest",
        ),
      );

      if (res.statusCode == 200) {
        final Map<String, dynamic> release = jsonDecode(res.body);
        final List assets = (release['assets'] as List?) ?? [];
        final apks = assets
            .where((a) => a['name'].toString().toLowerCase().endsWith('.apk'))
            .map(
              (a) => _ApkAsset(name: a['name'], url: a['browser_download_url']),
            )
            .toList();
        _apkAssets.addAll(apks);
      }
    } catch (e) {
      debugPrint("Error fetching APKs: $e");
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // EN: Starts direct apk download without opening a new tab.
  // AR: يبدأ تنزيل apk مباشر بدون فتح تبويب جديد.
  Future<void> _downloadApk(_ApkAsset apk) async {
    final url = _withCacheBuster(ensureHttps(apk.url));
    if (kIsWeb) {
      // GitHub release asset links redirect across domains.
      // Using same-tab navigation is generally more reliable than
      // forcing the HTML download attribute with cross-origin redirects.
      html.window.location.assign(url);
      return;
    }

    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  String _withCacheBuster(String url) {
    final uri = Uri.parse(url);
    final updatedQuery = Map<String, String>.from(uri.queryParameters)
      ..['_ts'] = DateTime.now().millisecondsSinceEpoch.toString();
    return uri.replace(queryParameters: updatedQuery).toString();
  }

  Future<void> _retryFetchApks() async {
    setState(() {
      _isLoading = true;
      _apkAssets.clear();
    });
    await _fetchLatestApks();
  }

  // EN: Builds widget UI.
  // AR: تبني واجهة الودجت.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TTColors.background,
      body: Stack(
        children: [
          const SnowBackground(),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(25),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.android,
                    size: 80,
                    color: TTColors.primaryCyan,
                  ),

                  const SizedBox(height: 20),

                  Text(
                    "تحميل تطبيق الأندرويد",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: TTColors.textWhite,
                      fontFamily: 'Cairo',
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    "للحصول على أفضل تجربة، يرجى استخدام التطبيق الرسمي.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: TTColors.textGray,
                      fontFamily: 'Cairo',
                    ),
                  ),

                  const SizedBox(height: 30),

                  if (_isLoading)
                    const CircularProgressIndicator(color: TTColors.primaryCyan)
                  else ...[
                    if (_apkAssets.isNotEmpty)
                      ..._apkAssets.map(
                        (apk) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ElevatedButton.icon(
                            onPressed: () => _downloadApk(apk),
                            icon: Icon(
                              Icons.download,
                              color: TTColors.textWhite,
                            ),
                            label: Text(
                              "تحميل نسخة: ${apk.displayName}",
                              style: TextStyle(
                                color: TTColors.textWhite,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: TTColors.cardBg,
                              side: const BorderSide(
                                color: TTColors.primaryCyan,
                              ),
                              minimumSize: const Size(double.infinity, 55),
                            ),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: [
                          Text(
                            "تعذّر جلب روابط التحميل الآن. جرّب مرة أخرى.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: TTColors.textGray,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: _retryFetchApks,
                            icon: const Icon(Icons.refresh),
                            label: const Text(
                              "إعادة المحاولة",
                              style: TextStyle(fontFamily: 'Cairo'),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.secondary,
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onSecondary,
                              minimumSize: const Size(double.infinity, 55),
                            ),
                          ),
                        ],
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApkAsset {
  final String name;
  final String url;

  _ApkAsset({required this.name, required this.url});

  // EN: Handles display Name.
  // AR: تتعامل مع display Name.
  String get displayName {
    final n = name.toLowerCase();
    if (n.contains('arm64')) return "aarch64 / arm64-v8a";
    if (n.contains('armeabi') || n.contains('v7a')) return "armebi-v7a";
    if (n.contains('x86_64')) return "x86";
    return name;
  }
}
