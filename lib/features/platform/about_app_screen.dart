// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_info.dart';
import '../../core/constants.dart';
import '../../services/remote_config_service.dart';
import '../../widgets/glass_app_bar.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/snow_background.dart';

class AboutAppScreen extends StatefulWidget {
  const AboutAppScreen({super.key});

  @override
  State<AboutAppScreen> createState() => _AboutAppScreenState();
}

class _AboutAppScreenState extends State<AboutAppScreen> {
  late final Future<PackageInfo> _infoFuture;

  @override
  void initState() {
    super.initState();
    _infoFuture = PackageInfo.fromPlatform();
  }

  String _normalizeHandle(String value) {
    var out = value.trim();
    if (out.isEmpty) return '';
    if (out.startsWith('http://') || out.startsWith('https://')) {
      final uri = Uri.tryParse(out);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        out = uri.pathSegments.last;
      }
    }
    out = out.replaceFirst(RegExp(r'^@+'), '').trim();
    return out;
  }

  Uri? _platformUri(String platform, String handle) {
    final user = _normalizeHandle(handle);
    if (user.isEmpty) return null;
    switch (platform) {
      case 'facebook':
        return Uri.parse('https://facebook.com/$user');
      case 'instagram':
        return Uri.parse('https://instagram.com/$user');
      case 'tiktok':
        return Uri.parse('https://www.tiktok.com/@$user');
      case 'telegram':
        return Uri.parse('https://t.me/$user');
      default:
        return null;
    }
  }

  Uri _githubUri(String username, String repo) {
    final normalizedUser = _normalizeHandle(username);
    final normalizedRepo = _normalizeHandle(repo);
    final user = normalizedUser.isEmpty ? GITHUB_USER : normalizedUser;
    final repoName = normalizedRepo.isEmpty ? GITHUB_REPO : normalizedRepo;
    return Uri.parse('https://github.com/$user/$repoName');
  }

  Future<void> _openLink(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر فتح الرابط')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rc = RemoteConfigService.instance;
    final githubUsername = rc.socialGithubUsername.isEmpty
        ? GITHUB_USER
        : rc.socialGithubUsername;
    final githubRepo = rc.socialGithubRepo.isEmpty
        ? GITHUB_REPO
        : rc.socialGithubRepo;
    final githubUri = _githubUri(githubUsername, githubRepo);
    final socialLinks = <_SocialLink>[
      _SocialLink(
        label: 'Facebook',
        icon: FontAwesomeIcons.facebookF,
        uri: _platformUri('facebook', rc.socialFacebookUrl),
      ),
      _SocialLink(
        label: 'Instagram',
        icon: FontAwesomeIcons.instagram,
        uri: _platformUri('instagram', rc.socialInstagramUrl),
      ),
      _SocialLink(
        label: 'TikTok',
        icon: FontAwesomeIcons.tiktok,
        uri: _platformUri('tiktok', rc.socialTiktokUrl),
      ),
      _SocialLink(
        label: 'Telegram',
        icon: FontAwesomeIcons.telegram,
        uri: _platformUri('telegram', rc.socialTelegramUrl),
      ),
    ].where((item) => item.uri != null).toList();

    return Scaffold(
      appBar: const GlassAppBar(title: Text('حول التطبيق')),
      body: Stack(
        children: [
          const SnowBackground(),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: GlassCard(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.all(18),
                  child: FutureBuilder<PackageInfo>(
                    future: _infoFuture,
                    builder: (context, snapshot) {
                      final info = snapshot.data;
                      final version = info?.version ?? '...';
                      final build = info?.buildNumber ?? '...';

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            AppInfo.appName,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: textColor,
                              fontFamily: 'Cairo',
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _InfoRow(label: 'الإصدار', value: version),
                          const SizedBox(height: 10),
                          _InfoRow(label: 'رقم البناء', value: build),
                          const SizedBox(height: 10),
                          const _InfoRow(
                            label: 'تم التطوير بواسطة',
                            value: 'Mohamed Zaitoon',
                          ),
                          const SizedBox(height: 10),
                          Center(
                            child: _LinkRow(
                              label: 'GitHub',
                              icon: FontAwesomeIcons.github,
                              accentColor: isDark
                                  ? const Color(0xFFE6EDF3)
                                  : const Color(0xFF24292F),
                              onTap: () => _openLink(githubUri),
                            ),
                          ),
                          if (socialLinks.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              'صفحات التواصل',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 10,
                              runSpacing: 12,
                              children: socialLinks
                                  .map(
                                    (item) => _LinkRow(
                                      label: item.label,
                                      icon: item.icon,
                                      accentColor: switch (item.label) {
                                        'Facebook' => const Color(0xFF1877F2),
                                        'Instagram' => const Color(0xFFE1306C),
                                        'TikTok' => const Color(0xFF00C7B7),
                                        'Telegram' => const Color(0xFF229ED9),
                                        _ => null,
                                      },
                                      onTap: () => _openLink(item.uri!),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final labelColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final valueColor = Theme.of(context).colorScheme.onSurface;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: valueColor,
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? accentColor;
  final VoidCallback onTap;

  const _LinkRow({
    required this.label,
    required this.icon,
    this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelColor = colorScheme.onSurfaceVariant;
    final accent = accentColor ?? colorScheme.primary;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: SizedBox(
            width: 88,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: accent.withAlpha(30),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accent.withAlpha(95), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withAlpha(28),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: FaIcon(icon, size: 22, color: accent),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: labelColor,
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialLink {
  final String label;
  final IconData icon;
  final Uri? uri;

  const _SocialLink({
    required this.label,
    required this.icon,
    required this.uri,
  });
}
