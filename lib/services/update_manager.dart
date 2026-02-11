// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants.dart';
import '../core/tt_colors.dart';
import '../utils/url_sanitizer.dart';
import '../widgets/glass_card.dart';
import '../widgets/top_snackbar.dart';

enum ReleaseStage { alpha, beta, rc, stable }

class UpdateManager {
  static const MethodChannel _androidChannel = MethodChannel('tt_android_info');
  static const String _githubApi =
      "https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO/releases";
  static const _downloadDirName = "Download";

  // EN: Checks check.
  // AR: تفحص check.
  static Future<void> check(BuildContext context, {bool manual = false}) async {
    try {
      if (manual) _showLoading(context);

      final pi = await PackageInfo.fromPlatform();
      final String currentVersion = pi.version.trim();

      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: Duration.zero,
        ),
      );
      await rc.fetchAndActivate();

      final String rcVersion = rc.getString('latest_version_name').trim();
      final bool allowBeta = rc.getBool('allow_beta_updates');
      final bool allowAlpha = rc.getBool('allow_alpha_updates');

      final ghRes = await http.get(Uri.parse(_githubApi));
      if (ghRes.statusCode != 200) {
        if (manual && context.mounted) Navigator.pop(context);
        return;
      }

      final List<dynamic> releases = jsonDecode(ghRes.body);
      if (releases.isEmpty) {
        if (manual && context.mounted) Navigator.pop(context);
        return;
      }

      String githubVersion = "";
      Map<String, dynamic>? selectedRelease;

      for (final r in releases) {
        final tag = r['tag_name'].toString().replaceAll('v', '').trim();
        if (tag.isEmpty) continue;

        if (githubVersion.isEmpty || _compareVersions(tag, githubVersion) > 0) {
          githubVersion = tag;
          selectedRelease = Map<String, dynamic>.from(r as Map);
        }
      }

      final release = selectedRelease;
      if (release == null || githubVersion.isEmpty) {
        if (manual && context.mounted) Navigator.pop(context);
        return;
      }

      String targetVersion = githubVersion;
      if (rcVersion.isNotEmpty &&
          _compareVersions(rcVersion, githubVersion) > 0) {
        targetVersion = rcVersion;
      }

      final parsedTarget = _parseVersion(targetVersion);

      if ((parsedTarget.stage == ReleaseStage.alpha && !allowAlpha) ||
          (parsedTarget.stage == ReleaseStage.beta && !allowBeta)) {
        if (manual && context.mounted) {
          Navigator.pop(context);
          TopSnackBar.show(
            context,
            "لا توجد تحديثات متاحة (alpha/beta غير مفعّلين)",
            backgroundColor: Colors.orange.shade800,
            textColor: Colors.white,
            icon: Icons.info,
          );
        }
        return;
      }

      final bool hasUpdate =
          _compareVersions(targetVersion, currentVersion) > 0;

      if (!hasUpdate) {
        if (manual && context.mounted) {
          Navigator.pop(context);
          TopSnackBar.show(
            context,
            "أنت تستخدم أحدث إصدار ✅",
            backgroundColor: Colors.green,
            textColor: Colors.white,
            icon: Icons.check_circle,
          );
        } else if (manual && context.mounted) {
          Navigator.pop(context);
        }
        return;
      }

      String downloadUrl = release['html_url']?.toString() ?? "";

      // اختر أول أصل APK
      final assets = (release['assets'] as List<dynamic>?) ?? [];
      for (final a in assets) {
        final name = a['name']?.toString().toLowerCase() ?? "";
        final url = a['browser_download_url']?.toString();
        if (name.endsWith('.apk')) {
          downloadUrl = url ?? downloadUrl;
          break;
        }
      }

      if (!context.mounted) return;
      if (manual) Navigator.pop(context);

      _showUpdateDialog(context, targetVersion, downloadUrl);
    } catch (e) {
      if (manual && context.mounted) Navigator.pop(context);
    }
  }

  // EN: Downloads latest APK then triggers native installer.
  // AR: يحفظ الـAPK في مجلد Download الخاص بالتطبيق ثم يطلق شاشة التثبيت.
  static Future<void> _downloadAndInstall(
    BuildContext context,
    String version,
    String url,
  ) async {
    if (!context.mounted) return;
    if (url.trim().isEmpty) {
      TopSnackBar.show(
        context,
        "تعذّر إيجاد رابط التحميل.",
        backgroundColor: Colors.orange.shade800,
        textColor: Colors.white,
        icon: Icons.link_off,
      );
      return;
    }

    // على الويب أو iOS نفتح الرابط في المتصفح.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      await launchUrl(Uri.parse(ensureHttps(url)));
      return;
    }

    final sanitizedUrl = ensureHttps(url);
    final isDirectApk = sanitizedUrl.toLowerCase().endsWith('.apk');
    if (!isDirectApk) {
      await launchUrl(Uri.parse(sanitizedUrl));
      return;
    }

    final progress = ValueNotifier<double>(0);
    bool dialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ValueListenableBuilder<double>(
        valueListenable: progress,
        builder: (_, value, child) {
          final percent = (value * 100).clamp(0, 100);
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 24,
            ),
            child: GlassCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(18),
              borderColor: TTColors.primaryCyan.withAlpha(140),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "جاري تنزيل التحديث...",
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      color: TTColors.primaryCyan,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: value == 0 ? null : value,
                    backgroundColor: TTColors.textGray.withValues(alpha: 0.2),
                    color: TTColors.primaryCyan,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${percent.toStringAsFixed(0)}%",
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: TTColors.textGray,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() => dialogOpen = false);

    try {
      final downloadDir = await _resolveDownloadDir();

      final filePath = p
          .join(downloadDir.path, "hrmstore-$version.apk")
          .replaceAll('\\', '/');

      final uri = Uri.parse(sanitizedUrl);
      final request = http.Request('GET', uri);
      final client = http.Client();
      final total = <int?>[null]; // mutable box to use in finally for progress
      final file = File(filePath).openWrite();
      try {
        final streamResponse = await client.send(request);

        if (streamResponse.statusCode != 200) {
          throw Exception("فشل التحميل (رمز ${streamResponse.statusCode})");
        }

        total[0] = streamResponse.contentLength;
        int received = 0;

        await for (final chunk in streamResponse.stream) {
          file.add(chunk);
          received += chunk.length;
          if ((total[0] ?? 0) > 0) {
            progress.value = received / (total[0]!);
          }
        }
      } finally {
        await file.close();
        client.close();
      }

      progress.value = 1;

      if (dialogOpen && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogOpen = false;
      }

      // حاول التثبيت بالروت أولاً، ثم بالأسلوب العادي.
      bool installedOk = await _tryRootInstall(filePath);
      if (!installedOk) {
        final bool? installed = await _androidChannel.invokeMethod<bool>(
          'installApk',
          {'path': filePath},
        );
        installedOk = installed == true;
      }

      if (!installedOk && context.mounted) {
        TopSnackBar.show(
          context,
          "تم التنزيل في مجلد $_downloadDirName، افتح الملف يدويًا للتثبيت.",
          backgroundColor: Colors.orange.shade800,
          textColor: Colors.white,
          icon: Icons.info,
        );
      }
    } catch (e) {
      if (dialogOpen && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogOpen = false;
      }
      if (context.mounted) {
        TopSnackBar.show(
          context,
          "تعذّر إتمام التحديث: ${e.toString()}",
          backgroundColor: Colors.red.shade800,
          textColor: Colors.white,
          icon: Icons.error,
        );
      }
    } finally {
      progress.dispose();
    }
  }

  static Future<bool> _tryRootInstall(String filePath) async {
    try {
      final bool? rooted = await _androidChannel.invokeMethod<bool>('isRooted');
      if (rooted != true) return false;
      final bool? ok = await _androidChannel.invokeMethod<bool>(
        'installApkRooted',
        {'path': filePath},
      );
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  // EN: Finds a writable app-specific Download directory, with fallbacks.
  // AR: يحدد مجلد تنزيل قابل للكتابة خاص بالتطبيق مع حلول احتياطية.
  static Future<Directory> _resolveDownloadDir() async {
    // 1) Internal files dir (works with FileProvider `files-path`).
    try {
      final support = await getApplicationSupportDirectory();
      final dir = Directory(p.join(support.path, _downloadDirName));
      if (await _ensureDir(dir)) return dir;
    } catch (_) {}

    // 2) App-specific external (if the device allows).
    try {
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        final dir = Directory(p.join(ext.path, _downloadDirName));
        if (await _ensureDir(dir)) return dir;
      }
    } catch (_) {}

    // 3) Last resort: cache dir.
    final cache = await getTemporaryDirectory();
    final dir = Directory(p.join(cache.path, _downloadDirName));
    await dir.create(recursive: true);
    return dir;
  }

  static Future<bool> _ensureDir(Directory dir) async {
    if (await dir.exists()) return true;
    await dir.create(recursive: true);
    return await dir.exists();
  }

  // EN: Handles compare Versions.
  // AR: تتعامل مع compare Versions.
  static int _compareVersions(String a, String b) {
    final va = _parseVersion(a);
    final vb = _parseVersion(b);

    for (int i = 0; i < 3; i++) {
      if (va.numbers[i] != vb.numbers[i]) {
        return va.numbers[i].compareTo(vb.numbers[i]);
      }
    }

    if (va.stage != vb.stage) {
      return va.stage.index.compareTo(vb.stage.index);
    }

    return va.stageNumber.compareTo(vb.stageNumber);
  }

  // EN: Parses Version.
  // AR: تحلّل Version.
  static _ParsedVersion _parseVersion(String v) {
    v = v.toLowerCase().replaceAll('v', '').trim();

    ReleaseStage stage = ReleaseStage.stable;
    int stageNumber = 0;

    if (v.contains('alpha')) {
      stage = ReleaseStage.alpha;
      stageNumber =
          int.tryParse(RegExp(r'alpha(\d+)').firstMatch(v)?.group(1) ?? '0') ??
          0;
    } else if (v.contains('beta')) {
      stage = ReleaseStage.beta;
      stageNumber =
          int.tryParse(RegExp(r'beta(\d+)').firstMatch(v)?.group(1) ?? '0') ??
          0;
    } else if (v.contains('rc')) {
      stage = ReleaseStage.rc;
      stageNumber =
          int.tryParse(RegExp(r'rc(\d+)').firstMatch(v)?.group(1) ?? '0') ?? 0;
    }

    final nums = v
        .split(RegExp(r'[-+]'))[0]
        .split('.')
        .map((e) => int.tryParse(e) ?? 0)
        .toList();

    while (nums.length < 3) {
      nums.add(0);
    }

    return _ParsedVersion(nums.take(3).toList(), stage, stageNumber);
  }

  // EN: Shows Loading.
  // AR: تعرض Loading.
  static void _showLoading(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: TTColors.primaryCyan),
      ),
    );
  }

  // EN: Shows Update Dialog.
  // AR: تعرض Update Dialog.
  static void _showUpdateDialog(
    BuildContext context,
    String version,
    String url,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: GlassCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(22),
          borderColor: TTColors.primaryCyan.withAlpha(140),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "تحديث جديد متوفر 🚀",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: TTColors.primaryCyan,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                "الإصدار الجديد: $version",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: TTColors.textWhite,
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 14),

              Text(
                "يوجد تحديث أحدث من نسختك الحالية. ننصح بالتحديث الآن.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: TTColors.textGray,
                ),
              ),

              const SizedBox(height: 18),

              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      "لاحقاً",
                      style: TextStyle(
                        color: TTColors.textGray,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await _downloadAndInstall(context, version, url);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TTColors.primaryCyan,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text(
                      "تحديث الآن",
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParsedVersion {
  final List<int> numbers;
  final ReleaseStage stage;
  final int stageNumber;

  _ParsedVersion(this.numbers, this.stage, this.stageNumber);
}
