// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_navigator.dart';
import '../core/tt_colors.dart';
import '../services/remote_config_service.dart';
import '../utils/whatsapp_utils.dart';

class AccountStatusBlocker extends StatefulWidget {
  final Widget child;

  const AccountStatusBlocker({super.key, required this.child});

  @override
  State<AccountStatusBlocker> createState() => _AccountStatusBlockerState();
}

class _AccountStatusBlockerState extends State<AccountStatusBlocker> {
  late final Future<_AccountSession> _sessionFuture = _loadSession();
  bool _loggingOut = false;

  String _normalizedMerchantVerificationStatus(dynamic raw) {
    final status = (raw ?? '').toString().trim().toLowerCase();
    if (status == 'approved') return 'approved';
    if (status == 'pending') return 'pending';
    if (status == 'rejected') return 'rejected';
    return 'not_submitted';
  }

  bool _isMerchantVerified(Map<String, dynamic> userData) {
    final status = _normalizedMerchantVerificationStatus(
      userData['merchant_verification_status'],
    );
    return userData['merchant_verified'] == true || status == 'approved';
  }

  String _normalizedPath(String raw) {
    var path = raw.trim();
    if (path.isEmpty) return '/';
    if (!path.startsWith('/')) path = '/$path';
    if (path.endsWith('/') && path.length > 1) {
      path = path.substring(0, path.length - 1);
    }
    return path;
  }

  bool _isVerificationRoute(BuildContext context) {
    final routeInfo = Router.maybeOf(context)?.routeInformationProvider?.value;
    final path = _normalizedPath(routeInfo?.uri.path ?? '');
    return path == '/merchant/verify';
  }

  bool _isSupportInquiryRoute(BuildContext context) {
    final routeInfo = Router.maybeOf(context)?.routeInformationProvider?.value;
    final path = _normalizedPath(routeInfo?.uri.path ?? '');
    return path == '/support_inquiry';
  }

  Future<_AccountSession> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    return _AccountSession(
      uid: (prefs.getString('user_uid') ?? '').trim(),
      name: (prefs.getString('user_name') ?? '').trim(),
      email: (prefs.getString('user_email') ?? '').trim().toLowerCase(),
      whatsapp: (prefs.getString('user_whatsapp') ?? '').trim(),
      isAdmin: prefs.getBool('is_admin') ?? false,
      merchantMode: prefs.getBool('is_merchant') ?? false,
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>? _userStream(_AccountSession s) {
    final users = FirebaseFirestore.instance.collection('users');
    if (s.email.isNotEmpty) {
      return users.where('email', isEqualTo: s.email).snapshots();
    }
    if (s.uid.isNotEmpty) {
      return users.where('uid', isEqualTo: s.uid).snapshots();
    }
    if (s.whatsapp.isNotEmpty) {
      return users.where('whatsapp', isEqualTo: s.whatsapp).snapshots();
    }
    return null;
  }

  int _accountStatusWeight(Map<String, dynamic> userData) {
    final status = (userData['account_status'] ?? 'active')
        .toString()
        .trim()
        .toLowerCase();
    if (status == 'blocked') return 3;
    if (status == 'suspended') return 2;
    return 1;
  }

  Map<String, dynamic>? _pickMostRestrictedUserData(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (docs.isEmpty) return null;
    Map<String, dynamic>? selected;
    var selectedWeight = -1;
    for (final doc in docs) {
      final data = doc.data();
      final weight = _accountStatusWeight(data);
      if (selected == null || weight > selectedWeight) {
        selected = data;
        selectedWeight = weight;
      }
      if (selectedWeight >= 3) break;
    }
    return selected;
  }

  _AccountGateDecision _evaluate({
    required Map<String, dynamic>? userData,
    required _AccountSession session,
  }) {
    if (userData == null) return const _AccountGateDecision.allow();

    final status = (userData['account_status'] ?? 'active')
        .toString()
        .trim()
        .toLowerCase();
    final note = (userData['account_status_note'] ?? '').toString().trim();

    if (status == 'blocked') {
      return _AccountGateDecision.deny(
        title: 'الحساب محظور',
        message: note.isEmpty
            ? 'تم حظر حسابك نهائياً من الإدارة، ولا يمكن استعادته.'
            : note,
        canOpenSupport: false,
      );
    }

    if (status == 'suspended') {
      return _AccountGateDecision.deny(
        title: 'الحساب موقوف',
        message: note.isEmpty ? 'تم إيقاف حسابك مؤقتاً من الإدارة.' : note,
        canOpenSupport: true,
      );
    }

    final isMerchantAccount = userData['is_merchant'] == true;
    if (isMerchantAccount && !_isMerchantVerified(userData)) {
      final verificationStatus = _normalizedMerchantVerificationStatus(
        userData['merchant_verification_status'],
      );
      if (verificationStatus == 'pending') {
        return const _AccountGateDecision.deny(
          title: 'توثيق التاجر قيد المراجعة',
          message:
              'لا يمكن استخدام التطبيق أو الموقع قبل اعتماد التوثيق. المراجعة من ساعة إلى 24 ساعة.',
          canOpenMerchantVerification: true,
        );
      }
      if (verificationStatus == 'rejected') {
        final note = (userData['merchant_verification_note'] ?? '')
            .toString()
            .trim();
        return _AccountGateDecision.deny(
          title: 'تم رفض توثيق البطاقة',
          message: note.isEmpty
              ? 'عدّل الاسم أو صور البطاقة (وش + ظهر) ثم أعد الإرسال.'
              : note,
          canOpenMerchantVerification: true,
        );
      }
      return const _AccountGateDecision.deny(
        title: 'توثيق البطاقة مطلوب',
        message: 'ارفع بطاقة الهوية (وش + ظهر) لإكمال تفعيل الحساب.',
        canOpenMerchantVerification: true,
      );
    }

    if (session.merchantMode) {
      final isMerchant = userData['is_merchant'] == true;
      if (!isMerchant) {
        return const _AccountGateDecision.deny(
          title: 'لا توجد صلاحية تاجر',
          message: 'هذا الحساب لا يملك صلاحية التاجر حالياً.',
        );
      }

      final merchantActive = userData['merchant_active'] != false;
      final now = DateTime.now();
      final trialEnds = userData['merchant_trial_ends_at'];
      final paidUntil = userData['merchant_paid_until'];
      final bool trialActive =
          trialEnds is Timestamp && now.isBefore(trialEnds.toDate());
      final bool paidActive =
          paidUntil is Timestamp && now.isBefore(paidUntil.toDate());

      if (!merchantActive) {
        return const _AccountGateDecision.deny(
          title: 'حساب التاجر غير مفعل',
          message: 'تم إيقاف حساب التاجر من الأدمن. تواصل مع الدعم.',
        );
      }

      if (!trialActive && !paidActive) {
        return const _AccountGateDecision.deny(
          title: 'اشتراك التاجر غير مفعل',
          message:
              'انتهت صلاحية الاشتراك. تواصل مع الأدمن لإعادة تفعيل حساب التاجر.',
        );
      }
    }

    return const _AccountGateDecision.allow();
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    try {
      await FirebaseAuth.instance.signOut().catchError((_) {});
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_uid');
      await prefs.remove('user_name');
      await prefs.remove('user_whatsapp');
      await prefs.remove('user_tiktok');
      await prefs.setBool('is_merchant', false);
      await prefs.setBool('is_admin', false);
      if (!mounted) return;
      if (kIsWeb) {
        AppNavigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
        return;
      }
      await SystemNavigator.pop();
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  String _resolveSupportWhatsapp() {
    final candidates = <String>[
      RemoteConfigService.instance.adminWhatsapp,
      RemoteConfigService.instance.cloudflareAdminWhatsapp,
    ];
    for (final raw in candidates) {
      final normalized = WhatsappUtils.normalizeEgyptianWhatsapp(raw);
      if (normalized.isNotEmpty) return normalized;
    }
    return '';
  }

  String _toWhatsappInternational(String raw) {
    final digits = WhatsappUtils.normalizeEgyptianWhatsapp(raw);
    if (digits.isEmpty) return '';
    if (digits.length == 11 && digits.startsWith('0')) {
      return '2$digits';
    }
    if (digits.length == 10 && digits.startsWith('1')) {
      return '20$digits';
    }
    if (digits.length == 12 && digits.startsWith('20')) {
      return digits;
    }
    return digits;
  }

  Future<void> _openSupportWhatsapp({
    required _AccountSession session,
    required Map<String, dynamic>? userData,
    required _AccountGateDecision decision,
  }) async {
    final supportWhatsapp = _toWhatsappInternational(_resolveSupportWhatsapp());
    if (supportWhatsapp.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رقم واتساب الدعم غير متاح حالياً')),
      );
      return;
    }

    final name = (userData?['name'] ?? '').toString().trim();
    final whatsapp = (userData?['whatsapp'] ?? '').toString().trim();
    final resolvedName = name.isNotEmpty ? name : session.displayName;
    final resolvedWhatsapp = whatsapp.isNotEmpty ? whatsapp : session.whatsapp;
    final normalizedUserWhatsapp =
        WhatsappUtils.normalizeEgyptianWhatsapp(resolvedWhatsapp);

    final textLines = <String>[
      'مرحباً، أحتاج مساعدة بخصوص الحساب.',
      'حالة الحساب: ${decision.title}',
      if (resolvedName.isNotEmpty) 'الاسم: $resolvedName',
      if (normalizedUserWhatsapp.isNotEmpty) 'رقم الحساب: $normalizedUserWhatsapp',
      if (decision.message.trim().isNotEmpty) 'التفاصيل: ${decision.message.trim()}',
    ];
    final text = Uri.encodeComponent(textLines.join('\n'));
    final uri = Uri.parse('https://wa.me/$supportWhatsapp?text=$text');

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر فتح واتساب الآن')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AccountSession>(
      future: _sessionFuture,
      builder: (context, sessionSnap) {
        if (!sessionSnap.hasData) return widget.child;
        final session = sessionSnap.data!;
        final onVerificationRoute = _isVerificationRoute(context);
        final onSupportInquiryRoute = _isSupportInquiryRoute(context);
        if (onVerificationRoute) {
          return widget.child;
        }
        if (session.isAdmin || !session.hasIdentity) return widget.child;

        final stream = _userStream(session);
        if (stream == null) return widget.child;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, userSnap) {
            if (!userSnap.hasData) return widget.child;
            final userData = _pickMostRestrictedUserData(userSnap.data!.docs);
            final decision = _evaluate(userData: userData, session: session);
            if (onSupportInquiryRoute && decision.canOpenSupport) {
              return widget.child;
            }
            if (decision.allowed) return widget.child;

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
                        const Icon(
                          Icons.lock_outline,
                          size: 64,
                          color: TTColors.primaryPink,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          decision.title,
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
                        const SizedBox(height: 20),
                        if (decision.canOpenSupport) ...[
                          OutlinedButton.icon(
                            onPressed: () => _openSupportWhatsapp(
                              session: session,
                              userData: userData,
                              decision: decision,
                            ),
                            icon: const Icon(Icons.support_agent),
                            label: const Text('تواصل مع الدعم'),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (!kIsWeb)
                          ElevatedButton.icon(
                            onPressed: _loggingOut ? null : _logout,
                            icon: _loggingOut
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.logout),
                            label: const Text('خروج من التطبيق'),
                          ),
                        if (decision.canOpenMerchantVerification) ...[
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: () => AppNavigator.pushNamed(
                              context,
                              '/merchant/verify',
                            ),
                            icon: const Icon(Icons.verified_user_outlined),
                            label: const Text('رفع البطاقة الآن'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _AccountSession {
  final String uid;
  final String name;
  final String email;
  final String whatsapp;
  final bool isAdmin;
  final bool merchantMode;

  const _AccountSession({
    required this.uid,
    required this.name,
    required this.email,
    required this.whatsapp,
    required this.isAdmin,
    required this.merchantMode,
  });

  String get displayName => name.trim().isEmpty ? 'المستخدم' : name.trim();

  bool get hasIdentity =>
      uid.isNotEmpty || email.isNotEmpty || whatsapp.isNotEmpty;
}

class _AccountGateDecision {
  final bool allowed;
  final String title;
  final String message;
  final bool canOpenMerchantVerification;
  final bool canOpenSupport;

  const _AccountGateDecision.allow()
    : allowed = true,
      title = '',
      message = '',
      canOpenMerchantVerification = false,
      canOpenSupport = false;

  const _AccountGateDecision.deny({
    required this.title,
    required this.message,
    this.canOpenMerchantVerification = false,
    this.canOpenSupport = false,
  }) : allowed = false;
}
