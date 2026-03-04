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
  bool _isOpeningApp = false;
  final List<_ApkAsset> _apkAssets = [];
  late final String _userAgent =
      kIsWeb ? html.window.navigator.userAgent.toLowerCase() : '';

  bool get _isAndroidBrowser => _userAgent.contains('android');
  bool get _isSamsungBrowser => _userAgent.contains('samsungbrowser');

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
      // GitHub release asset links redirect عبر عدة نطاقات.
      // نستخدم رابط مباشر مع عنصر <a download> لتحسين التوافق مع Chrome على أندرويد.
      try {
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..target = '_blank'
          ..rel = 'noopener'
          ..download = apk.suggestedFileName;
        html.document.body?.append(anchor);
        anchor.click();
        anchor.remove();
      } catch (_) {
        // في حال منع النوافذ المنبثقة أو أي استثناء، نستعمل نفس التبويب.
        html.window.location.assign(url);
      }
      return;
    }

    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  String _buildOpenAppDeepLink() {
    final location = html.window.location;
    String path = (location.pathname ?? '').trim();
    if (path.isEmpty || path == '/' || path == '/android') {
      path = '/home';
    }
    final query = (location.search ?? '').trim();
    return 'hrmstoreapp://open$path$query';
  }

  Future<void> _tryOpenApp() async {
    if (!kIsWeb || _isOpeningApp) return;
    setState(() => _isOpeningApp = true);
    try {
      final deepLink = _buildOpenAppDeepLink();
      if (_isAndroidBrowser) {
        _openIntentLink(deepLink);
      } else {
        html.window.location.assign(deepLink);
      }
      await Future<void>.delayed(
        _isSamsungBrowser
            ? const Duration(milliseconds: 1400)
            : const Duration(milliseconds: 900),
      );
    } catch (e) {
      debugPrint('Error opening app: $e');
    } finally {
      if (mounted) {
        setState(() => _isOpeningApp = false);
      }
    }
  }

  void _openIntentLink(String deepLink) {
    try {
      final clean = deepLink.replaceFirst('hrmstoreapp://', '');
      final location = html.window.location;
      final origin = location.origin?.isNotEmpty == true
          ? location.origin!
          : 'https://hrmstore.mohamedzaitoon.com';
      final path = location.pathname ?? '/android';
      final search = location.search ?? '';
      final fallbackUrl = '$origin$path$search';
      final intentUrl =
          'intent://$clean#Intent;scheme=hrmstoreapp;package=com.mohamedzaitoon.hrmstore;S.browser_fallback_url=$fallbackUrl;end';
      html.window.location.assign(intentUrl);
    } catch (e) {
      debugPrint('Error intent link: $e');
    }
  }

  Future<void> _openAppThenDownload(_ApkAsset apk) async {
    if (kIsWeb) {
      // على الويب: حمل مباشرة بدون محاولة فتح التطبيق أو انتظار hidden flag.
      await _downloadApk(apk);
      return;
    }

    // المسار غير الويب (احتياطي): افتح التطبيق ثم نزّل إذا لم يُفتح.
    await _tryOpenApp();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await _downloadApk(apk);
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

                  ElevatedButton.icon(
                    onPressed: _isOpeningApp ? null : _tryOpenApp,
                    icon: Icon(Icons.open_in_new, color: TTColors.textWhite),
                    label: Text(
                      _isOpeningApp ? "جارٍ فتح التطبيق..." : "فتح التطبيق",
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

                  const SizedBox(height: 12),

                  Text(
                    "يتم التحميل من GitHub Releases وقد يفتح في تبويب جديد.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: TTColors.textGray,
                      fontSize: 13,
                      fontFamily: 'Cairo',
                    ),
                  ),

                  const SizedBox(height: 12),

                  if (_isLoading)
                    const CircularProgressIndicator(color: TTColors.primaryCyan)
                  else ...[
                    if (_apkAssets.isNotEmpty)
                      ..._apkAssets.map(
                        (apk) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ElevatedButton.icon(
                            onPressed: () => _openAppThenDownload(apk),
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

  // EN: Provide a safe filename hint for downloads.
  // AR: اسم ملف مقترح للتحميل.
  String get suggestedFileName {
    final parsed = Uri.tryParse(url);
    final path = parsed?.pathSegments.isNotEmpty == true
        ? parsed!.pathSegments.last
        : name;
    if (path.trim().isNotEmpty) return path;
    return 'hrmstore.apk';
  }

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
