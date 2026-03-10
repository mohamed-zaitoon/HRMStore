// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/app_navigator.dart';
import '../../services/admin_session_service.dart';
import '../../utils/whatsapp_utils.dart';
import '../../widgets/glass_app_bar.dart';
import '../../widgets/glass_bottom_sheet.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/modal_utils.dart';
import '../../widgets/snow_background.dart';
import '../../widgets/theme_mode_sheet.dart';
import '../../widgets/top_snackbar.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  static const double _fixedMerchantMonthlyFee = 750;
  bool _isMigratingBilling = false;
  bool _autoMigrationTriggered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runAutoBillingMigration());
    });
  }

  String _normalizeWhatsapp(String value) {
    return WhatsappUtils.normalizeEgyptianWhatsapp(value);
  }

  String _userKeyFromWhatsapp(String value) {
    final normalized = _normalizeWhatsapp(value);
    if (normalized.isNotEmpty) return normalized;
    return value.trim();
  }

  int _toInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse((raw ?? '').toString().trim()) ?? 0;
  }

  double _toDouble(dynamic raw) {
    if (raw is double) return raw;
    if (raw is int) return raw.toDouble();
    if (raw is num) return raw.toDouble();
    return double.tryParse((raw ?? '').toString().trim()) ?? 0;
  }

  String _merchantIdFromUser(Map<String, dynamic> user) {
    final ref = user['ref'];
    if (ref is DocumentReference) {
      final id = ref.id.trim();
      if (id.isNotEmpty) return id;
    }
    final uid = (user['uid'] ?? '').toString().trim();
    if (uid.isNotEmpty) return uid;
    final whatsapp = _normalizeWhatsapp((user['whatsapp'] ?? '').toString());
    if (whatsapp.isNotEmpty) return whatsapp;
    return '';
  }

  String _normalizeBillingMode(dynamic raw) {
    final mode = (raw ?? '').toString().trim().toLowerCase();
    if (mode == 'percent_revenue') return 'percent_revenue';
    return 'monthly_fixed';
  }

  String _normalizeMerchantVerificationStatus(dynamic raw) {
    final status = (raw ?? '').toString().trim().toLowerCase();
    if (status == 'approved') return 'approved';
    if (status == 'pending') return 'pending';
    if (status == 'rejected') return 'rejected';
    return 'not_submitted';
  }

  String _merchantVerificationLabel(String status) {
    switch (status) {
      case 'approved':
        return 'موثق بالبطاقة';
      case 'pending':
        return 'التوثيق قيد المراجعة';
      case 'rejected':
        return 'التوثيق مرفوض';
      default:
        return 'غير موثق';
    }
  }

  bool _isMerchantVerified(Map<String, dynamic> user) {
    final status = _normalizeMerchantVerificationStatus(
      user['merchant_verification_status'],
    );
    return user['merchant_verified'] == true || status == 'approved';
  }

  String _billingModeLabel() => '750ج شهري';

  String _accountStatusLabel(String status) {
    switch (status) {
      case 'blocked':
        return 'الحالة: محظور';
      case 'suspended':
        return 'الحالة: موقوف';
      default:
        return 'الحالة: نشط';
    }
  }

  String _formatMoney(double amount) {
    if (amount % 1 == 0) return amount.toInt().toString();
    return amount.toStringAsFixed(2);
  }

  Future<void> _runAutoBillingMigration() async {
    if (_autoMigrationTriggered) return;
    _autoMigrationTriggered = true;
    final migrated = await _migrateMerchantsToFixedBilling(showFeedback: false);
    if (!mounted || migrated <= 0) return;
    TopSnackBar.show(
      context,
      'تم ترحيل $migrated حساب تاجر تلقائياً إلى اشتراك 750ج.',
      icon: Icons.price_check,
    );
  }

  Future<void> _logoutAdmin() async {
    final adminId = await AdminSessionService.getLocalAdminId();
    await AdminSessionService.logoutCurrentDevice(adminId);
    await AdminSessionService.clearLocalSession();
    if (!mounted) return;
    AppNavigator.pushNamedAndRemoveUntil(context, '/admin', (route) => false);
  }

  Future<void> _openDevicesScreen() async {
    final adminId = await AdminSessionService.getLocalAdminId();
    if (adminId == null || adminId.isEmpty) {
      if (!mounted) return;
      TopSnackBar.show(
        context,
        'لم يتم العثور على هوية الأدمن (admin_id)',
        icon: Icons.error,
        backgroundColor: Colors.red,
      );
      return;
    }
    if (!mounted) return;
    AppNavigator.pushNamed(context, '/admin/devices', arguments: adminId);
  }

  ListTile _menuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontFamily: 'Cairo')),
      onTap: onTap,
    );
  }

  void _showAdminMenuSheet() {
    showLockedModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Theme.of(context).colorScheme.scrim.withAlpha(140),
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: GlassBottomSheet(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _menuTile(
                  icon: Icons.card_giftcard,
                  title: 'طلبات أكواد المستخدمين',
                  onTap: () {
                    Navigator.pop(ctx);
                    AppNavigator.pushNamed(context, '/admin/requests');
                  },
                ),
                _menuTile(
                  icon: Icons.confirmation_number,
                  title: 'إدارة الأكواد',
                  onTap: () {
                    Navigator.pop(ctx);
                    AppNavigator.pushNamed(context, '/admin/codes');
                  },
                ),
                _menuTile(
                  icon: Icons.local_offer,
                  title: 'عروض الأسعار',
                  onTap: () {
                    Navigator.pop(ctx);
                    AppNavigator.pushNamed(context, '/admin/offers');
                  },
                ),
                _menuTile(
                  icon: Icons.calculate,
                  title: 'حاسبة التكلفة اليدوية',
                  onTap: () {
                    Navigator.pop(ctx);
                    AppNavigator.pushNamed(context, '/admin/cost-calculator');
                  },
                ),
                _menuTile(
                  icon: Icons.games,
                  title: 'شحن الألعاب',
                  onTap: () {
                    Navigator.pop(ctx);
                    AppNavigator.pushNamed(context, '/admin/games');
                  },
                ),
                _menuTile(
                  icon: Icons.people_alt,
                  title: 'بيانات المستخدمين',
                  onTap: () => Navigator.pop(ctx),
                ),
                _menuTile(
                  icon: Icons.schedule,
                  title: 'تشغيل/إيقاف الويب و Android Release',
                  onTap: () {
                    Navigator.pop(ctx);
                    AppNavigator.pushNamed(context, '/admin/availability');
                  },
                ),
                _menuTile(
                  icon: Icons.devices,
                  title: 'التحكم في الأجهزة',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _openDevicesScreen();
                  },
                ),
                _menuTile(
                  icon: Icons.support_agent,
                  title: 'شات الاستفسارات',
                  onTap: () {
                    Navigator.pop(ctx);
                    AppNavigator.pushNamed(context, '/admin/support_inquiries');
                  },
                ),
                _menuTile(
                  icon: Theme.of(context).brightness == Brightness.dark
                      ? Icons.nightlight_round
                      : Icons.wb_sunny_rounded,
                  title: 'وضع التطبيق',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await showThemeModeSheet(context);
                  },
                ),
                _menuTile(
                  icon: Icons.logout,
                  title: 'تسجيل الخروج',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _logoutAdmin();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _appendMerchantBillingLog({
    required String merchantId,
    required String action,
    required bool merchantActive,
    Timestamp? paidUntil,
    String? oldMode,
    double? oldMonthlyFee,
    double? oldRevenuePercent,
  }) async {
    if (merchantId.trim().isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('merchant_billing_logs').add({
        'merchant_id': merchantId.trim(),
        'action': action,
        'billing_mode': 'monthly_fixed',
        'monthly_fee': _fixedMerchantMonthlyFee,
        'merchant_active': merchantActive,
        if (paidUntil case final value) 'merchant_paid_until': value,
        if (oldMode case final value) 'old_billing_mode': value,
        if (oldMonthlyFee case final value) 'old_monthly_fee': value,
        if (oldRevenuePercent case final value) 'old_revenue_percent': value,
        'source': 'admin_users_screen',
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // تسجيل الفوترة لا يجب أن يعطل شاشة الإدارة.
    }
  }

  Future<int> _migrateMerchantsToFixedBilling({
    required bool showFeedback,
  }) async {
    if (_isMigratingBilling) return 0;
    if (mounted) setState(() => _isMigratingBilling = true);
    int migratedCount = 0;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('is_merchant', isEqualTo: true)
          .get();

      for (final doc in snap.docs) {
        final data = doc.data();
        final oldMode = _normalizeBillingMode(data['merchant_billing_mode']);
        final oldMonthlyFee = _toDouble(data['merchant_monthly_fee']);
        final oldRevenuePercent = _toDouble(data['merchant_revenue_percent']);
        final hasLegacyPercent = data.containsKey('merchant_revenue_percent');
        final requiresMigration =
            oldMode != 'monthly_fixed' ||
            oldMonthlyFee != _fixedMerchantMonthlyFee ||
            hasLegacyPercent;
        if (!requiresMigration) continue;

        migratedCount++;
        await doc.reference.set({
          'merchant_billing_mode': 'monthly_fixed',
          'merchant_monthly_fee': _fixedMerchantMonthlyFee,
          'merchant_revenue_percent': FieldValue.delete(),
          'merchant_billing_updated_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final merchantId = _merchantIdFromUser({
          ...data,
          'uid': (data['uid'] ?? '').toString(),
          'whatsapp': (data['whatsapp'] ?? '').toString(),
          'ref': doc.reference,
        });
        await _appendMerchantBillingLog(
          merchantId: merchantId,
          action: 'migration_to_fixed_750',
          merchantActive: data['merchant_active'] != false,
          paidUntil: data['merchant_paid_until'] is Timestamp
              ? data['merchant_paid_until'] as Timestamp
              : null,
          oldMode: oldMode,
          oldMonthlyFee: oldMonthlyFee,
          oldRevenuePercent: oldRevenuePercent,
        );
      }

      if (!mounted || !showFeedback) return migratedCount;
      if (migratedCount == 0) {
        TopSnackBar.show(
          context,
          'كل حسابات التجار بالفعل على نظام 750ج الشهري.',
          icon: Icons.verified,
        );
      } else {
        TopSnackBar.show(
          context,
          'تم ترحيل $migratedCount حساب تاجر إلى نظام 750ج الشهري.',
          icon: Icons.sync_alt,
        );
      }
      return migratedCount;
    } catch (_) {
      if (mounted && showFeedback) {
        TopSnackBar.show(
          context,
          'تعذر ترحيل نظام الفوترة حالياً',
          icon: Icons.error,
          backgroundColor: Colors.red,
        );
      }
      return migratedCount;
    } finally {
      if (mounted) setState(() => _isMigratingBilling = false);
    }
  }

  Timestamp? _latestTimestamp(Map<String, dynamic> user) {
    final updated = user['updated_at'];
    if (updated is Timestamp) return updated;
    final created = user['created_at'];
    if (created is Timestamp) return created;
    return null;
  }

  Map<String, dynamic> _normalizeUser(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final whatsapp = (data['whatsapp'] ?? doc.id).toString();
    final rawName = (data['name'] ?? '').toString();
    final email = (data['email'] ?? '').toString();
    final tiktokVal = (data['tiktok'] ?? '').toString();
    final username = (data['username'] ?? tiktokVal).toString();
    final displayName = rawName.isNotEmpty
        ? rawName
        : (data['display_name'] ?? tiktokVal).toString().isNotEmpty
        ? (data['display_name'] ?? tiktokVal).toString()
        : whatsapp;
    return {
      'whatsapp': whatsapp,
      'name': displayName,
      'email': email,
      'uid': (data['uid'] ?? '').toString(),
      'username': username,
      'tiktok': tiktokVal,
      'balance_points': _toInt(data['balance_points']),
      'account_status': (data['account_status'] ?? 'active').toString(),
      'account_status_note': (data['account_status_note'] ?? '').toString(),
      'is_merchant': data['is_merchant'] == true,
      'merchant_active': data['merchant_active'] != false,
      'merchant_trial_started_at': data['merchant_trial_started_at'],
      'merchant_trial_ends_at': data['merchant_trial_ends_at'],
      'merchant_paid_until': data['merchant_paid_until'],
      'merchant_billing_mode': _normalizeBillingMode(
        data['merchant_billing_mode'],
      ),
      'merchant_monthly_fee': _toDouble(data['merchant_monthly_fee'] ?? 750),
      'merchant_verification_status': _normalizeMerchantVerificationStatus(
        data['merchant_verification_status'],
      ),
      'merchant_verified':
          data['merchant_verified'] == true ||
          _normalizeMerchantVerificationStatus(
                data['merchant_verification_status'],
              ) ==
              'approved',
      'merchant_id_full_name': (data['merchant_id_full_name'] ?? '').toString(),
      'merchant_id_front_url': (data['merchant_id_front_url'] ?? '').toString(),
      'merchant_id_front_path': (data['merchant_id_front_path'] ?? '')
          .toString(),
      'merchant_id_back_url': (data['merchant_id_back_url'] ?? '').toString(),
      'merchant_id_back_path': (data['merchant_id_back_path'] ?? '').toString(),
      'merchant_has_crypto_card': data['merchant_has_crypto_card'],
      'merchant_card_contact_whatsapp':
          (data['merchant_card_contact_whatsapp'] ?? '').toString(),
      'merchant_card_requirement_note':
          (data['merchant_card_requirement_note'] ?? '').toString(),
      'merchant_data_collection_consent':
          data['merchant_data_collection_consent'] == true,
      'merchant_verification_note': (data['merchant_verification_note'] ?? '')
          .toString(),
      'merchant_verification_submitted_at':
          data['merchant_verification_submitted_at'],
      'merchant_verification_reviewed_at':
          data['merchant_verification_reviewed_at'],
      'merchant_revenue_percent': _toDouble(
        data['merchant_revenue_percent'] ?? 0,
      ),
      'created_at': data['created_at'],
      'updated_at': data['updated_at'],
      'ref': doc.reference,
    };
  }

  Map<String, int> _buildOrdersCount(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final counts = <String, int>{};
    for (final doc in docs) {
      final data = doc.data();
      final whatsapp = (data['user_whatsapp'] ?? data['whatsapp'] ?? '')
          .toString()
          .trim();
      final key = _userKeyFromWhatsapp(whatsapp);
      if (key.isEmpty) continue;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  Future<bool> _updateUser(
    BuildContext context,
    DocumentReference ref,
    Map<String, dynamic> data,
    String success,
  ) async {
    try {
      await ref.set({
        ...data,
        'status_updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!context.mounted) return false;
      TopSnackBar.show(context, success, icon: Icons.check_circle);
      return true;
    } catch (e) {
      if (!context.mounted) return false;
      TopSnackBar.show(
        context,
        'تعذر تحديث الحساب',
        icon: Icons.error,
        backgroundColor: Colors.red,
      );
      return false;
    }
  }

  Future<void> _editUser(
    BuildContext context,
    Map<String, dynamic> user,
  ) async {
    final ref = user['ref'] as DocumentReference?;
    if (ref == null) return;

    final nameCtrl = TextEditingController(
      text: (user['name'] ?? '').toString(),
    );
    final waCtrl = TextEditingController(
      text: (user['whatsapp'] ?? '').toString(),
    );
    final emailCtrl = TextEditingController(
      text: (user['email'] ?? '').toString(),
    );
    final tiktokCtrl = TextEditingController(
      text: (user['tiktok'] ?? user['username'] ?? '').toString(),
    );
    final balanceCtrl = TextEditingController(
      text: (user['balance_points'] ?? 0).toString(),
    );
    final passwordCtrl = TextEditingController();
    bool isMerchant = user['is_merchant'] == true;
    bool merchantActive = user['merchant_active'] != false;
    String accountStatus = (user['account_status'] ?? 'active')
        .toString()
        .trim()
        .toLowerCase();
    if (accountStatus != 'active' &&
        accountStatus != 'suspended' &&
        accountStatus != 'blocked') {
      accountStatus = 'active';
    }
    final accountStatusNoteCtrl = TextEditingController(
      text: (user['account_status_note'] ?? '').toString(),
    );
    final paidUntil = user['merchant_paid_until'];
    final paidUntilCtrl = TextEditingController(
      text: paidUntil is Timestamp
          ? DateFormat('yyyy-MM-dd').format(paidUntil.toDate())
          : '',
    );

    await showLockedDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('تعديل بيانات المستخدم'),
        content: StatefulBuilder(
          builder: (dialogCtx, setStateDialog) {
            final media = MediaQuery.of(dialogCtx);
            final maxHeight = media.size.height * 0.75;
            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: media.viewInsets.bottom + 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'الاسم'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: waCtrl,
                      decoration: const InputDecoration(
                        labelText: 'رقم الواتساب',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'البريد الإلكتروني',
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: tiktokCtrl,
                      decoration: const InputDecoration(
                        labelText: 'يوزر تيك توك',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: balanceCtrl,
                      decoration: const InputDecoration(
                        labelText: 'الرصيد (نقاط)',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: accountStatus,
                      decoration: const InputDecoration(
                        labelText: 'حالة الحساب',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'active', child: Text('نشط')),
                        DropdownMenuItem(
                          value: 'suspended',
                          child: Text('موقوف'),
                        ),
                        DropdownMenuItem(
                          value: 'blocked',
                          child: Text('محظور'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setStateDialog(() => accountStatus = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: accountStatusNoteCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظة الحالة (اختياري)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      value: isMerchant,
                      onChanged: (v) {
                        setStateDialog(() {
                          isMerchant = v;
                          if (!merchantActive && v) merchantActive = true;
                        });
                      },
                      title: const Text('حساب تاجر'),
                    ),
                    SwitchListTile(
                      value: merchantActive,
                      onChanged: isMerchant
                          ? (v) => setStateDialog(() {
                              merchantActive = v;
                            })
                          : null,
                      title: const Text('تفعيل حساب التاجر'),
                      subtitle: const Text(
                        'الخدمة مجانية 7 أيام ثم 750ج/شهر (بدون نسبة).',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    if (isMerchant) ...[
                      const SizedBox(height: 10),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.price_check),
                        title: const Text('نظام المحاسبة'),
                        subtitle: Text(
                          'اشتراك ثابت ${_fixedMerchantMonthlyFee.toInt()}ج شهرياً',
                        ),
                      ),
                    ],
                    TextField(
                      controller: paidUntilCtrl,
                      decoration: const InputDecoration(
                        labelText: 'مدفوع حتى (YYYY-MM-DD)',
                        helperText: 'اتركها فارغة لعدم التمديد اليدوي',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: passwordCtrl,
                      decoration: const InputDecoration(
                        labelText: 'كلمة سر جديدة (اختياري)',
                        helperText: 'اتركها فارغة للإبقاء على الحالية',
                      ),
                      obscureText: true,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final wa = _normalizeWhatsapp(waCtrl.text);
              final bal = int.tryParse(balanceCtrl.text.trim());
              final newPassword = passwordCtrl.text.trim();
              if (!WhatsappUtils.isValidEgyptianWhatsapp(wa) || bal == null) {
                TopSnackBar.show(
                  context,
                  'أدخل رقم واتساب صحيح (11 رقم يبدأ بـ01) ورصيد صحيح',
                  icon: Icons.error,
                  backgroundColor: Colors.red,
                );
                return;
              }
              if (newPassword.isNotEmpty && newPassword.length < 6) {
                TopSnackBar.show(
                  context,
                  'كلمة السر يجب ألا تقل عن 6 أحرف',
                  icon: Icons.error,
                  backgroundColor: Colors.red,
                );
                return;
              }
              final paidUntilText = paidUntilCtrl.text.trim();
              Timestamp? paidUntilTs;
              if (paidUntilText.isNotEmpty) {
                final parsed = DateTime.tryParse(paidUntilText);
                if (parsed == null) {
                  TopSnackBar.show(
                    context,
                    'صيغة التاريخ غير صحيحة (استخدم YYYY-MM-DD)',
                    icon: Icons.error,
                    backgroundColor: Colors.red,
                  );
                  return;
                }
                paidUntilTs = Timestamp.fromDate(parsed);
              }
              Navigator.pop(ctx);
              final update = <String, dynamic>{
                'name': nameCtrl.text.trim(),
                'whatsapp': wa,
                'tiktok': tiktokCtrl.text.trim(),
                'username': tiktokCtrl.text.trim(),
                'email': emailCtrl.text.trim().toLowerCase(),
                'balance_points': bal,
                'updated_at': FieldValue.serverTimestamp(),
                'account_status': accountStatus,
                'account_status_note': accountStatusNoteCtrl.text.trim(),
                'is_merchant': isMerchant,
                'merchant_active': isMerchant ? merchantActive : false,
                'merchant_paid_until': paidUntilTs ?? FieldValue.delete(),
                if (isMerchant)
                  'merchant_billing_mode': 'monthly_fixed'
                else
                  'merchant_billing_mode': FieldValue.delete(),
                if (isMerchant)
                  'merchant_monthly_fee': _fixedMerchantMonthlyFee
                else
                  'merchant_monthly_fee': FieldValue.delete(),
                'merchant_revenue_percent': FieldValue.delete(),
                if (isMerchant)
                  'merchant_billing_updated_at': FieldValue.serverTimestamp(),
              };
              if (!isMerchant) {
                update['merchant_paid_until'] = FieldValue.delete();
              }

              if (newPassword.isNotEmpty) {
                update['password'] = newPassword;
                update['password_hash'] = null;
              }

              final updated = await _updateUser(
                context,
                ref,
                update,
                'تم حفظ التعديلات',
              );
              if (!updated || !isMerchant) return;
              await _appendMerchantBillingLog(
                merchantId: _merchantIdFromUser(user),
                action: 'admin_merchant_update',
                merchantActive: merchantActive,
                paidUntil: paidUntilTs,
                oldMode: _normalizeBillingMode(user['merchant_billing_mode']),
                oldMonthlyFee: _toDouble(user['merchant_monthly_fee']),
                oldRevenuePercent: _toDouble(user['merchant_revenue_percent']),
              );
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(
    BuildContext context,
    Map<String, dynamic> user,
  ) async {
    final ref = user['ref'] as DocumentReference?;
    if (ref == null) return;

    final whatsapp = (user['whatsapp'] ?? '').toString();
    final name = (user['name'] ?? '').toString();

    final confirmed =
        await showLockedDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('حذف الحساب'),
            content: Text(
              'سيتم حذف حساب $name\nرقم واتساب: $whatsapp\nلا يمكن التراجع عن الحذف.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('تأكيد الحذف'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    try {
      await ref.delete();
      if (!context.mounted) return;
      TopSnackBar.show(
        context,
        'تم حذف الحساب',
        icon: Icons.delete_forever,
        backgroundColor: Colors.red.shade700,
      );
    } catch (e) {
      if (!context.mounted) return;
      TopSnackBar.show(
        context,
        'تعذر حذف الحساب',
        icon: Icons.error,
        backgroundColor: Colors.red,
      );
    }
  }

  List<String> _extractMediaCandidates(dynamic raw) {
    if (raw == null) return const <String>[];
    if (raw is String) {
      final value = raw.trim();
      if (value.isEmpty) return const <String>[];

      if (value.startsWith('[') && value.endsWith(']')) {
        try {
          final decoded = jsonDecode(value);
          return _extractMediaCandidates(decoded);
        } catch (_) {
          // نكمل كتقسيم نصي عادي.
        }
      }

      return value
          .split(RegExp(r'[\n,;]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }

    if (raw is Iterable) {
      final out = <String>[];
      for (final item in raw) {
        out.addAll(_extractMediaCandidates(item));
      }
      return out;
    }

    if (raw is Map) {
      final out = <String>[];
      for (final value in raw.values) {
        out.addAll(_extractMediaCandidates(value));
      }
      return out;
    }

    final fallback = raw.toString().trim();
    return fallback.isEmpty ? const <String>[] : <String>[fallback];
  }

  bool _isDirectHttpUrl(String value) {
    final v = value.trim().toLowerCase();
    return v.startsWith('http://') || v.startsWith('https://');
  }

  Future<List<String>> _resolveMerchantImageUrls({
    required dynamic rawUrl,
    required dynamic rawPath,
  }) async {
    final resolved = <String>{};

    final urlCandidates = _extractMediaCandidates(rawUrl);
    final pathCandidates = <String>[..._extractMediaCandidates(rawPath)];

    for (final candidate in urlCandidates) {
      final value = candidate.trim();
      if (value.isEmpty) continue;
      if (_isDirectHttpUrl(value)) {
        resolved.add(value);
        continue;
      }
      pathCandidates.add(value);
    }

    for (final candidate in pathCandidates) {
      final path = candidate.trim();
      if (path.isEmpty || path.startsWith('imgbb:')) continue;
      if (_isDirectHttpUrl(path)) {
        resolved.add(path);
        continue;
      }
      try {
        if (path.startsWith('gs://')) {
          resolved.add(
            await FirebaseStorage.instance.refFromURL(path).getDownloadURL(),
          );
        } else {
          resolved.add(
            await FirebaseStorage.instance.ref(path).getDownloadURL(),
          );
        }
      } catch (_) {
        // نتجاهل المسارات غير الصالحة ونكمل باقي الصور.
      }
    }

    return resolved.toList(growable: false);
  }

  Widget _buildMerchantImagePreview({
    required BuildContext context,
    required String title,
    required List<String> urls,
  }) {
    final hasImages = urls.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        if (!hasImages)
          const SizedBox(
            height: 130,
            child: Center(child: Text('لا توجد صورة')),
          )
        else
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: urls.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (ctx, index) {
                final imageUrl = urls[index];
                return ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    imageUrl,
                    width: 230,
                    height: 190,
                    fit: BoxFit.cover,
                    loadingBuilder: (c, child, progress) {
                      if (progress == null) return child;
                      return SizedBox(
                        width: 230,
                        height: 190,
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: progress.expectedTotalBytes == null
                                ? null
                                : progress.cumulativeBytesLoaded /
                                      progress.expectedTotalBytes!,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(
                          width: 230,
                          height: 190,
                          child: Center(child: Text('تعذر تحميل الصورة')),
                        ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _showMerchantVerificationImages(
    BuildContext context,
    Map<String, dynamic> user,
  ) async {
    final fullName = (user['merchant_id_full_name'] ?? '').toString().trim();
    final note = (user['merchant_verification_note'] ?? '').toString().trim();
    final submittedAt = user['merchant_verification_submitted_at'];

    await showLockedDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مراجعة توثيق التاجر'),
        content: SizedBox(
          width: 520,
          child: FutureBuilder<(List<String>, List<String>)>(
            future: () async {
              final frontUrls = await _resolveMerchantImageUrls(
                rawUrl: user['merchant_id_front_url'],
                rawPath: user['merchant_id_front_path'],
              );
              final backUrls = await _resolveMerchantImageUrls(
                rawUrl: user['merchant_id_back_url'],
                rawPath: user['merchant_id_back_path'],
              );
              return (frontUrls, backUrls);
            }(),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return const SizedBox(
                  height: 200,
                  child: Center(
                    child: Text('تعذر تحميل صور البطاقة. حاول مرة أخرى.'),
                  ),
                );
              }

              final frontUrls = snapshot.data?.$1 ?? const <String>[];
              final backUrls = snapshot.data?.$2 ?? const <String>[];
              final hasAny = frontUrls.isNotEmpty || backUrls.isNotEmpty;

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الاسم كما في البطاقة: ${fullName.isEmpty ? '-' : fullName}',
                    ),
                    const SizedBox(height: 8),
                    if (submittedAt is Timestamp)
                      Text(
                        'تاريخ الإرسال: ${DateFormat('yyyy-MM-dd HH:mm').format(submittedAt.toDate())}',
                      ),
                    if (note.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('ملاحظة سابقة: $note'),
                    ],
                    const SizedBox(height: 10),
                    _buildMerchantImagePreview(
                      context: context,
                      title: 'صورة البطاقة (الوش)',
                      urls: frontUrls,
                    ),
                    const SizedBox(height: 10),
                    _buildMerchantImagePreview(
                      context: context,
                      title: 'صورة البطاقة (الظهر)',
                      urls: backUrls,
                    ),
                    if (!hasAny) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'لا توجد روابط صور صالحة محفوظة لهذا الطلب.',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Future<String?> _promptVerificationRejectReason(BuildContext context) async {
    final ctrl = TextEditingController();
    String? result;
    await showLockedDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('سبب رفض التوثيق'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'اكتب سبب الرفض ليظهر للتاجر (اختياري)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              result = ctrl.text.trim();
              Navigator.pop(ctx);
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    return result;
  }

  Future<void> _reviewMerchantVerification({
    required BuildContext context,
    required Map<String, dynamic> user,
    required bool approve,
  }) async {
    final ref = user['ref'] as DocumentReference?;
    if (ref == null) return;

    if (approve) {
      final fullName = (user['merchant_id_full_name'] ?? '').toString().trim();
      final frontUrl = (user['merchant_id_front_url'] ?? '').toString().trim();
      final backUrl = (user['merchant_id_back_url'] ?? '').toString().trim();
      final frontPath = (user['merchant_id_front_path'] ?? '')
          .toString()
          .trim();
      final backPath = (user['merchant_id_back_path'] ?? '').toString().trim();
      final hasFront = frontUrl.isNotEmpty || frontPath.isNotEmpty;
      final hasBack = backUrl.isNotEmpty || backPath.isNotEmpty;
      if (fullName.isEmpty || !hasFront || !hasBack) {
        TopSnackBar.show(
          context,
          'لا يمكن الموافقة بدون الاسم الكامل وصورتَي البطاقة (وش + ظهر).',
          icon: Icons.error_outline,
          backgroundColor: Colors.red,
        );
        return;
      }
    }

    String reviewNote = '';
    if (!approve) {
      final reason = await _promptVerificationRejectReason(context);
      if (reason == null) return;
      reviewNote = reason.trim();
    }

    try {
      final update = <String, dynamic>{
        'is_merchant': true,
        'merchant_verification_status': approve ? 'approved' : 'rejected',
        'merchant_verified': approve,
        'merchant_verification_note': approve ? '' : reviewNote,
        'merchant_verification_reviewed_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'merchant_billing_mode': 'monthly_fixed',
        'merchant_monthly_fee': _fixedMerchantMonthlyFee,
        'merchant_revenue_percent': FieldValue.delete(),
      };

      if (approve) {
        update['merchant_active'] = true;
        update['merchant_verified_at'] = FieldValue.serverTimestamp();
        final hasTrial =
            user['merchant_trial_started_at'] is Timestamp &&
            user['merchant_trial_ends_at'] is Timestamp;
        if (!hasTrial) {
          update['merchant_status'] = 'trial';
          update['merchant_trial_started_at'] = FieldValue.serverTimestamp();
          update['merchant_trial_ends_at'] = Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 7)),
          );
        }
      } else {
        update['merchant_active'] = false;
        update['merchant_verified_at'] = FieldValue.delete();
        update['merchant_verification_rejected_at'] =
            FieldValue.serverTimestamp();
      }

      await ref.set(update, SetOptions(merge: true));
      await _appendMerchantBillingLog(
        merchantId: _merchantIdFromUser(user),
        action: approve
            ? 'merchant_verification_approved'
            : 'merchant_verification_rejected',
        merchantActive: approve,
      );

      if (!context.mounted) return;
      TopSnackBar.show(
        context,
        approve
            ? 'تمت الموافقة على توثيق التاجر وتفعيل الحساب.'
            : 'تم رفض توثيق التاجر.',
        icon: approve ? Icons.verified : Icons.cancel_outlined,
        backgroundColor: approve ? Colors.green : Colors.orange,
      );
    } catch (_) {
      if (!context.mounted) return;
      TopSnackBar.show(
        context,
        'تعذر تحديث حالة التوثيق',
        icon: Icons.error,
        backgroundColor: Colors.red,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: GlassAppBar(
        title: const Text('بيانات المستخدمين'),
        actions: [
          IconButton(
            tooltip: 'تعديل الأسعار',
            icon: const Icon(Icons.price_change),
            onPressed: () {
              AppNavigator.pushNamed(context, '/admin/prices');
            },
          ),
          IconButton(
            tooltip: 'ترحيل نظام الفوترة',
            onPressed: _isMigratingBilling
                ? null
                : () {
                    unawaited(
                      _migrateMerchantsToFixedBilling(showFeedback: true),
                    );
                  },
            icon: _isMigratingBilling
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_alt_rounded),
          ),
          IconButton(
            tooltip: 'القائمة',
            icon: const Icon(Icons.menu_rounded),
            onPressed: _showAdminMenuSheet,
          ),
        ],
      ),
      body: Stack(
        children: [
          const SnowBackground(),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .limit(500)
                .snapshots(),
            builder: (context, usersSnapshot) {
              if (!usersSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final userDocs = usersSnapshot.data!.docs;
              if (userDocs.isEmpty) {
                return const Center(child: Text('لا توجد بيانات مستخدمين'));
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .orderBy('created_at', descending: true)
                    .limit(2000)
                    .snapshots(),
                builder: (context, ordersSnapshot) {
                  final orderDocs = ordersSnapshot.hasData
                      ? ordersSnapshot.data!.docs
                      : <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                  final orderCounts = _buildOrdersCount(orderDocs);

                  // أزل التكرار بالاعتماد على رقم الواتساب، واحتفظ بالأحدث (updated_at ثم created_at)
                  final Map<String, Map<String, dynamic>> unique = {};
                  for (final doc in userDocs) {
                    final user = _normalizeUser(doc);
                    final whatsapp = (user['whatsapp'] ?? '').toString();
                    final key = _userKeyFromWhatsapp(whatsapp);
                    if (key.isEmpty) continue;

                    final existing = unique[key];
                    if (existing == null) {
                      unique[key] = user;
                      continue;
                    }

                    final existingTs = _latestTimestamp(existing);
                    final incomingTs = _latestTimestamp(user);
                    if (incomingTs != null &&
                        (existingTs == null ||
                            incomingTs.compareTo(existingTs) > 0)) {
                      unique[key] = user;
                    }
                  }

                  final items = unique.values.toList()
                    ..sort((a, b) {
                      final at = _latestTimestamp(a);
                      final bt = _latestTimestamp(b);
                      if (at != null && bt != null) return bt.compareTo(at);
                      if (bt != null) return 1;
                      if (at != null) return -1;
                      return 0;
                    });

                  final content = ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final user = items[index];
                      final name = (user['name'] ?? '').toString();
                      final whatsapp = (user['whatsapp'] ?? '').toString();
                      final email = (user['email'] ?? '').toString();
                      final tiktok = (user['tiktok'] ?? '').toString();
                      final balancePoints = _toInt(user['balance_points']);
                      final accountStatus = (user['account_status'] ?? 'active')
                          .toString()
                          .trim()
                          .toLowerCase();
                      final accountStatusNote =
                          (user['account_status_note'] ?? '').toString().trim();
                      final isMerchant = user['is_merchant'] == true;
                      final merchantActive = user['merchant_active'] != false;
                      final merchantVerificationStatus =
                          _normalizeMerchantVerificationStatus(
                            user['merchant_verification_status'],
                          );
                      final merchantVerified = _isMerchantVerified(user);
                      final merchantVerificationNote =
                          (user['merchant_verification_note'] ?? '')
                              .toString()
                              .trim();
                      final merchantIdFullName =
                          (user['merchant_id_full_name'] ?? '')
                              .toString()
                              .trim();
                      final merchantIdFrontUrl =
                          (user['merchant_id_front_url'] ?? '')
                              .toString()
                              .trim();
                      final merchantIdBackUrl =
                          (user['merchant_id_back_url'] ?? '')
                              .toString()
                              .trim();
                      final merchantIdFrontPath =
                          (user['merchant_id_front_path'] ?? '')
                              .toString()
                              .trim();
                      final merchantIdBackPath =
                          (user['merchant_id_back_path'] ?? '')
                              .toString()
                              .trim();
                      final hasCryptoCard = user['merchant_has_crypto_card'];
                      final merchantCardContact =
                          (user['merchant_card_contact_whatsapp'] ?? '')
                              .toString()
                              .trim();
                      final merchantCardNote =
                          (user['merchant_card_requirement_note'] ?? '')
                              .toString()
                              .trim();
                      final dataConsent =
                          user['merchant_data_collection_consent'] == true;
                      final trialEnds = user['merchant_trial_ends_at'];
                      final paidUntil = user['merchant_paid_until'];
                      final merchantMonthlyFee = _toDouble(
                        user['merchant_monthly_fee'] ??
                            _fixedMerchantMonthlyFee,
                      );
                      final merchantMonthlyDue = _fixedMerchantMonthlyFee;
                      final now = DateTime.now();
                      final trialActive =
                          trialEnds is Timestamp &&
                          now.isBefore(trialEnds.toDate());
                      final paidActive =
                          paidUntil is Timestamp &&
                          now.isBefore(paidUntil.toDate());
                      final subscriptionPaymentStatus = paidActive
                          ? 'مدفوع'
                          : 'مستحق';
                      final merchantAccessActive =
                          merchantActive &&
                          merchantVerified &&
                          (trialActive || paidActive);
                      final totalOrders =
                          orderCounts[_userKeyFromWhatsapp(whatsapp)] ?? 0;
                      final ref = user['ref'] as DocumentReference?;

                      return GlassCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isEmpty ? 'بدون اسم' : name,
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'واتساب: $whatsapp',
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'نسخ',
                                  icon: const Icon(Icons.copy, size: 18),
                                  color: colorScheme.primary,
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(text: whatsapp),
                                    );
                                    TopSnackBar.show(
                                      context,
                                      'تم نسخ رقم الواتساب',
                                      icon: Icons.copy,
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (email.isNotEmpty) ...[
                              Text(
                                'البريد: $email',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                            Text(
                              'تيك توك: ${tiktok.isEmpty ? '-' : tiktok}',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                _statChip(
                                  context: context,
                                  icon: Icons.account_balance_wallet_rounded,
                                  text: 'الرصيد: $balancePoints نقطة',
                                ),
                                _statChip(
                                  context: context,
                                  icon: Icons.receipt_long_rounded,
                                  text: 'إجمالي الطلبات: $totalOrders',
                                ),
                                _statChip(
                                  context: context,
                                  icon: accountStatus == 'active'
                                      ? Icons.verified_user
                                      : Icons.gpp_bad,
                                  text: _accountStatusLabel(accountStatus),
                                ),
                              ],
                            ),
                            if (accountStatusNote.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'ملاحظة الحالة: $accountStatusNote',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            if (isMerchant) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  _statChip(
                                    context: context,
                                    icon: merchantAccessActive
                                        ? Icons.verified
                                        : Icons.lock_clock,
                                    text: merchantAccessActive
                                        ? 'تاجر مفعل'
                                        : 'تاجر غير مفعل',
                                  ),
                                  _statChip(
                                    context: context,
                                    icon: Icons.payments_outlined,
                                    text: 'النظام: ${_billingModeLabel()}',
                                  ),
                                  _statChip(
                                    context: context,
                                    icon: merchantVerified
                                        ? Icons.verified_user
                                        : Icons.badge_outlined,
                                    text:
                                        'التوثيق: ${_merchantVerificationLabel(merchantVerificationStatus)}',
                                  ),
                                  _statChip(
                                    context: context,
                                    icon: Icons.price_check,
                                    text:
                                        'المستحق: ${_formatMoney(merchantMonthlyDue)} ج',
                                  ),
                                  _statChip(
                                    context: context,
                                    icon: paidActive
                                        ? Icons.verified_outlined
                                        : Icons.warning_amber_rounded,
                                    text:
                                        'حالة الاشتراك: $subscriptionPaymentStatus',
                                  ),
                                  _statChip(
                                    context: context,
                                    icon: Icons.attach_money,
                                    text:
                                        'اشتراك شهري: ${_formatMoney(merchantMonthlyFee > 0 ? merchantMonthlyFee : _fixedMerchantMonthlyFee)} ج',
                                  ),
                                  if (hasCryptoCard is bool)
                                    _statChip(
                                      context: context,
                                      icon: hasCryptoCard
                                          ? Icons.credit_card
                                          : Icons.credit_card_off,
                                      text: hasCryptoCard
                                          ? 'يمتلك بطاقة RedotPay/كريبتو'
                                          : 'لا يمتلك بطاقة RedotPay/كريبتو',
                                    ),
                                  _statChip(
                                    context: context,
                                    icon: dataConsent
                                        ? Icons.verified_user
                                        : Icons.report_problem_outlined,
                                    text: dataConsent
                                        ? 'وافق على جمع البيانات'
                                        : 'لم يوافق على جمع البيانات',
                                  ),
                                  if (trialEnds is Timestamp)
                                    _statChip(
                                      context: context,
                                      icon: Icons.timer,
                                      text:
                                          'تجربة حتى ${trialEnds.toDate().day}/${trialEnds.toDate().month}',
                                    ),
                                  if (paidUntil is Timestamp)
                                    _statChip(
                                      context: context,
                                      icon: Icons.date_range,
                                      text:
                                          'مدفوع حتى ${paidUntil.toDate().day}/${paidUntil.toDate().month}',
                                    ),
                                ],
                              ),
                              if (merchantIdFullName.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'الاسم في البطاقة: $merchantIdFullName',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              if (merchantVerificationNote.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'ملاحظة التوثيق: $merchantVerificationNote',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              if (merchantCardContact.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'رقم واتساب للتواصل بخصوص البطاقة: $merchantCardContact',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              if (merchantCardNote.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'شرح التاجر: $merchantCardNote',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              if (merchantIdFrontUrl.isNotEmpty ||
                                  merchantIdBackUrl.isNotEmpty ||
                                  merchantIdFrontPath.isNotEmpty ||
                                  merchantIdBackPath.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          _showMerchantVerificationImages(
                                            context,
                                            user,
                                          ),
                                      icon: const Icon(Icons.image_outlined),
                                      label: const Text('عرض صور البطاقة'),
                                    ),
                                    if (merchantVerificationStatus == 'pending')
                                      ElevatedButton.icon(
                                        onPressed: () =>
                                            _reviewMerchantVerification(
                                              context: context,
                                              user: user,
                                              approve: true,
                                            ),
                                        icon: const Icon(Icons.verified),
                                        label: const Text('قبول التوثيق'),
                                      ),
                                    if (merchantVerificationStatus == 'pending')
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                            _reviewMerchantVerification(
                                              context: context,
                                              user: user,
                                              approve: false,
                                            ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          side: BorderSide(
                                            color: Colors.red.withValues(
                                              alpha: 0.7,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(Icons.cancel_outlined),
                                        label: const Text('رفض التوثيق'),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                            if (ref != null) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton(
                                    onPressed: () => _editUser(context, user),
                                    child: const Text('تعديل البيانات'),
                                  ),
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: BorderSide(
                                        color: Colors.red.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                    ),
                                    onPressed: () => _deleteUser(context, user),
                                    child: const Text('حذف الحساب'),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                    separatorBuilder: (_, index) => const SizedBox(height: 10),
                    itemCount: items.length,
                  );

                  if (!kIsWeb) return content;

                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 920),
                      child: content,
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _statChip({
    required BuildContext context,
    required IconData icon,
    required String text,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primary.withAlpha(24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.primary.withAlpha(72)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 12,
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
