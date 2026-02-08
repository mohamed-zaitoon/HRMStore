// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants.dart';
import '../core/tt_colors.dart';
import '../utils/url_sanitizer.dart';
import '../widgets/glass_card.dart';
import '../widgets/top_snackbar.dart';

enum ReleaseStage { alpha, beta, rc, stable }

class UpdateManager {
  static const String _githubApi =
      "https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO/releases";

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

      try {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        final abi = androidInfo.supportedAbis.first.toLowerCase();

        final assets = (release['assets'] as List<dynamic>?) ?? [];
        for (final a in assets) {
          final name = a['name'].toString().toLowerCase();
          if (name.endsWith('.apk') && name.contains(abi)) {
            downloadUrl = a['browser_download_url'].toString();
            break;
          }
        }
      } catch (_) {}

      if (!context.mounted) return;
      if (manual) Navigator.pop(context);

      _showUpdateDialog(context, targetVersion, downloadUrl);
    } catch (e) {
      if (manual && context.mounted) Navigator.pop(context);
    }
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

    while (nums.length < 3) nums.add(0);

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
                    onPressed: () => launchUrl(
                      Uri.parse(ensureHttps(url)),
                      mode: LaunchMode.externalApplication,
                    ),
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
