// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

import '../../core/tt_colors.dart';
import '../../utils/url_sanitizer.dart';

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
  String _latestVersion = "";
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
          "https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO/releases?per_page=5",
        ),
      );

      if (res.statusCode == 200) {
        final List releases = jsonDecode(res.body);
        for (final release in releases) {
          final List assets = release['assets'];
          final apks = assets
              .where((a) => a['name'].toString().toLowerCase().endsWith('.apk'))
              .map(
                (a) =>
                    _ApkAsset(name: a['name'], url: a['browser_download_url']),
              )
              .toList();

          if (apks.isNotEmpty) {
            _apkAssets.addAll(apks);
            _latestVersion = release['tag_name'] ?? "";
            break;
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching APKs: $e");
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // EN: Builds widget UI.
  // AR: تبني واجهة الودجت.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TTColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.android, size: 80, color: TTColors.primaryCyan),

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
                if (_latestVersion.isNotEmpty)
                  Text(
                    "الإصدار الأخير: $_latestVersion",
                    style: TextStyle(color: TTColors.textWhite),
                  ),

                const SizedBox(height: 15),

                if (_apkAssets.isNotEmpty)
                  ..._apkAssets.map(
                    (apk) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ElevatedButton.icon(
                        onPressed: () => launchUrl(
                          Uri.parse(ensureHttps(apk.url)),
                          mode: LaunchMode.externalApplication,
                        ),
                        icon: Icon(Icons.download, color: TTColors.textWhite),
                        label: Text(
                          "تحميل نسخة: ${apk.displayName}",
                          style: TextStyle(
                            color: TTColors.textWhite,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TTColors.cardBg,
                          side: const BorderSide(color: TTColors.primaryCyan),
                          minimumSize: const Size(double.infinity, 55),
                        ),
                      ),
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(
                        "https://github.com/$GITHUB_USER/$GITHUB_REPO/releases/latest",
                      ),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.public, color: Colors.white),
                    label: const Text(
                      "الذهاب لصفحة التحميل",
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TTColors.primaryPink,
                      minimumSize: const Size(double.infinity, 55),
                    ),
                  ),
              ],
            ],
          ),
        ),
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
