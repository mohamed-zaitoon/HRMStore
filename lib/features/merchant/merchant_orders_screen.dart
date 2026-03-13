// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

import '../../core/app_info.dart';
import '../../core/app_navigator.dart';
import '../../core/order_status.dart';
import '../../core/tt_colors.dart';
import '../../models/game_package.dart';
import '../../services/cloudflare_notify_service.dart';
import '../../services/merchant_presence_service.dart';
import '../../services/order_chat_service.dart';
import '../../widgets/glass_app_bar.dart';
import '../../widgets/glass_bottom_sheet.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/modal_utils.dart';
import '../../widgets/snow_background.dart';
import '../../widgets/theme_mode_sheet.dart';
import '../../widgets/top_snackbar.dart';
import '../../utils/promo_order_utils.dart';
import '../../utils/url_sanitizer.dart';
import '../../utils/whatsapp_utils.dart';

class MerchantOrdersScreen extends StatefulWidget {
  final String merchantId;
  final String merchantName;
  final String merchantWhatsapp;

  const MerchantOrdersScreen({
    super.key,
    required this.merchantId,
    required this.merchantName,
    required this.merchantWhatsapp,
  });

  @override
  State<MerchantOrdersScreen> createState() => _MerchantOrdersScreenState();
}

class _MerchantOrdersScreenState extends State<MerchantOrdersScreen>
    with WidgetsBindingObserver {
  static const double _usdCostPer1000 = 10.41;
  String _statusFilter = 'all';
  late Stream<QuerySnapshot<Map<String, dynamic>>> _ordersStream;
  bool _useIndexedOrdersQuery = true;
  bool _useMerchantWhatsappLookup = false;
  bool _switchingToFallback = false;
  bool _switchingLookupMode = false;
  bool _loggingOut = false;
  bool _updatingPresenceVisibility = false;

  Stream<DocumentSnapshot<Map<String, dynamic>>> get _merchantStream =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(widget.merchantId)
          .snapshots();

  Stream<DocumentSnapshot<Map<String, dynamic>>> get _currencyStream =>
      FirebaseFirestore.instance
          .collection('app_settings')
          .doc('currency')
          .snapshots();

  String _normalizeWhatsapp(String value) {
    return value.replaceAll(RegExp(r'[^0-9+]'), '').trim();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _useMerchantWhatsappLookup =
        widget.merchantId.trim().isEmpty &&
        widget.merchantWhatsapp.trim().isNotEmpty;
    _rebuildOrdersStream();
    unawaited(_startPresence());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    MerchantPresenceService.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_startPresence());
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(MerchantPresenceService.stop());
    }
  }

  Future<void> _startPresence() async {
    await MerchantPresenceService.start(
      merchantId: widget.merchantId,
      merchantWhatsapp: widget.merchantWhatsapp,
    );
  }

  Future<void> _setPresenceVisibility({required bool showOnline}) async {
    if (_updatingPresenceVisibility) return;
    setState(() => _updatingPresenceVisibility = true);
    try {
      await MerchantPresenceService.setManualOffline(
        merchantId: widget.merchantId,
        merchantWhatsapp: widget.merchantWhatsapp,
        manualOffline: !showOnline,
      );
      if (!mounted) return;
      TopSnackBar.show(
        context,
        showOnline
            ? 'تم تفعيل ظهورك كمتصل الآن'
            : 'تم إخفاؤك كأوفلاين حتى تعيد التفعيل',
        backgroundColor: showOnline ? Colors.green : Colors.orange,
        textColor: Colors.white,
        icon: showOnline ? Icons.wifi_tethering : Icons.wifi_off_rounded,
      );
    } catch (_) {
      if (!mounted) return;
      TopSnackBar.show(
        context,
        'تعذر تحديث حالة الظهور الآن',
        backgroundColor: Colors.red,
        textColor: Colors.white,
        icon: Icons.error_outline,
      );
    } finally {
      if (mounted) setState(() => _updatingPresenceVisibility = false);
    }
  }

  void _rebuildOrdersStream() {
    _ordersStream = _buildOrdersStream(useIndexedQuery: _useIndexedOrdersQuery);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _buildOrdersStream({
    required bool useIndexedQuery,
  }) {
    final merchantWhatsapp = _normalizeWhatsapp(widget.merchantWhatsapp);
    final merchantId = widget.merchantId.trim();
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
      'orders',
    );
    if (_useMerchantWhatsappLookup && merchantWhatsapp.isNotEmpty) {
      // دعم حسابات قديمة كان فيها mismatch في merchant_id/docId.
      query = query.where('merchant_whatsapp', isEqualTo: merchantWhatsapp);
    } else {
      query = query.where('merchant_id', isEqualTo: merchantId);
    }
    if (useIndexedQuery) {
      return query
          .orderBy('created_at', descending: true)
          .limit(300)
          .snapshots();
    }
    return query.limit(300).snapshots();
  }

  bool _isMissingIndexError(Object? error) {
    final text = (error ?? '').toString().toLowerCase();
    final hasFailedPrecondition =
        text.contains('failed_precondition') ||
        text.contains('failed-precondition');
    final hasIndexKeyword =
        text.contains('index') ||
        text.contains('requires an index') ||
        text.contains('query requires an index');
    return hasFailedPrecondition && hasIndexKeyword;
  }

  Future<void> _switchToFallbackQuery() async {
    if (_switchingToFallback || !_useIndexedOrdersQuery || !mounted) return;
    setState(() => _switchingToFallback = true);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    setState(() {
      _useIndexedOrdersQuery = false;
      _rebuildOrdersStream();
      _switchingToFallback = false;
    });
  }

  Future<void> _switchToWhatsappLookup() async {
    if (_switchingLookupMode ||
        _useMerchantWhatsappLookup ||
        widget.merchantWhatsapp.trim().isEmpty ||
        !mounted) {
      return;
    }
    setState(() => _switchingLookupMode = true);
    await Future<void>.delayed(const Duration(milliseconds: 160));
    if (!mounted) return;
    setState(() {
      _useMerchantWhatsappLookup = true;
      _rebuildOrdersStream();
      _switchingLookupMode = false;
    });
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'all':
        return 'الكل';
      case 'pending_payment':
        return 'بانتظار الدفع';
      case 'pending_review':
      case 'processing':
      case 'completed':
      case 'rejected':
        return OrderStatusHelper.label(status);
      default:
        return 'غير محدد';
    }
  }

  bool _isSupportedMerchantOrderType(String productType) {
    return productType == 'tiktok' ||
        productType == 'game' ||
        isPromoProductType(productType);
  }

  double? _parseUsdValue(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) {
      return double.tryParse(raw.trim().replaceAll(',', '.'));
    }
    return null;
  }

  double? _merchantAutoBaseCostPer1000(Map<String, dynamic>? data) {
    final usdRate = _parseUsdValue(data?['usd_price'] ?? data?['usd_egp']);
    if (usdRate == null || usdRate <= 0) return null;
    return usdRate * _usdCostPer1000;
  }

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    try {
      await MerchantPresenceService.stop();
      await FirebaseAuth.instance.signOut().catchError((_) {});
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_uid');
      await prefs.remove('user_name');
      await prefs.remove('user_email');
      await prefs.remove('user_whatsapp');
      await prefs.remove('user_tiktok');
      await prefs.setBool('is_merchant', false);
      AppInfo.isMerchantApp = false;
      if (mounted) {
        AppNavigator.pushNamedAndRemoveUntil(
          context,
          '/login',
          (route) => false,
        );
      }
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  Future<void> _switchToUserMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_merchant', false);
    AppInfo.isMerchantApp = false;
    if (!mounted) return;
    AppNavigator.pushNamedAndRemoveUntil(
      context,
      '/home',
      (route) => false,
      arguments: <String, dynamic>{
        'name': widget.merchantName,
        'whatsapp': widget.merchantWhatsapp,
      },
    );
  }

  Future<void> _handleRefresh() async {
    await MerchantPresenceService.start(
      merchantId: widget.merchantId,
      merchantWhatsapp: widget.merchantWhatsapp,
    );
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(_rebuildOrdersStream);
  }

  Widget _buildRefreshableCenteredState({
    required Widget child,
    double topPadding = 12,
  }) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, topPadding, 16, 16),
            child: Center(child: child),
          ),
        ),
      ],
    );
  }

  bool _isTrialActive(Map<String, dynamic> data) {
    final trialEnds = data['merchant_trial_ends_at'];
    if (trialEnds is! Timestamp) return false;
    return DateTime.now().isBefore(trialEnds.toDate());
  }

  String _trialRemainingText(Map<String, dynamic> data) {
    final trialEnds = data['merchant_trial_ends_at'];
    if (trialEnds is! Timestamp) return '';
    final diff = trialEnds.toDate().difference(DateTime.now());
    if (diff.isNegative) return 'انتهت فترة التجربة';
    final days = diff.inDays;
    if (days > 0) return 'متبقي $days يوم من التجربة المجانية';
    final hours = diff.inHours;
    return 'متبقي أقل من ${hours <= 0 ? 1 : hours} ساعة من التجربة المجانية';
  }

  double _toDouble(dynamic raw) {
    if (raw is double) return raw;
    if (raw is int) return raw.toDouble();
    if (raw is num) return raw.toDouble();
    return double.tryParse((raw ?? '').toString().trim()) ?? 0;
  }

  String _formatMoney(double amount) {
    final fixed = amount.toStringAsFixed(6);
    return fixed
        .replaceFirst(RegExp(r'\.?0+$'), '')
        .replaceAll(RegExp(r'(\.\d*?)0+$'), r'$1');
  }

  String _merchantBillingLabel(Map<String, dynamic> data) {
    final monthlyFee = _toDouble(data['merchant_monthly_fee'] ?? 750);
    final resolved = monthlyFee > 0 ? monthlyFee : 750.0;
    return '${_formatMoney(resolved)}ج / شهر';
  }

  String _normalizedVerificationStatus(dynamic raw) {
    final status = (raw ?? '').toString().trim().toLowerCase();
    if (status == 'approved') return 'approved';
    if (status == 'pending') return 'pending';
    if (status == 'rejected') return 'rejected';
    return 'not_submitted';
  }

  bool _isMerchantVerified(Map<String, dynamic> data) {
    final status = _normalizedVerificationStatus(
      data['merchant_verification_status'],
    );
    return data['merchant_verified'] == true || status == 'approved';
  }

  Widget _buildSubscriptionBanner() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _merchantStream,
      builder: (context, snapshot) {
        final colorScheme = Theme.of(context).colorScheme;
        final data = snapshot.data?.data() ?? <String, dynamic>{};
        final bool active = data['merchant_active'] != false;
        final bool verified = _isMerchantVerified(data);
        final bool trialActive = _isTrialActive(data);
        final paidUntil = data['merchant_paid_until'];
        final bool paidActive =
            paidUntil is Timestamp &&
            DateTime.now().isBefore(paidUntil.toDate());
        final billingLabel = _merchantBillingLabel(data);
        String subtitle =
            'الخدمة مجانية 7 أيام ثم $billingLabel. تواصل مع دعم التطبيق لتجديد الاشتراك.';

        if (!verified) {
          subtitle =
              'الحساب غير موثق بالبطاقة (وش + ظهر). ارفع التوثيق وسيتم المراجعة من ساعة إلى 24 ساعة.';
        } else if (trialActive) {
          subtitle = _trialRemainingText(data);
        } else if (paidActive) {
          final dt = paidUntil.toDate();
          subtitle = 'الحساب مفعل حتى ${dt.day}/${dt.month}/${dt.year}';
        } else if (!active) {
          subtitle = 'الحساب موقوف حتى يتم التفعيل من الأدمن بعد الدفع.';
        } else {
          subtitle = 'نظام المحاسبة الحالي: $billingLabel';
        }

        return GlassCard(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                trialActive
                    ? Icons.timer_outlined
                    : (active ? Icons.verified : Icons.lock_clock),
                color: trialActive
                    ? Colors.orange
                    : (active ? Colors.green : Colors.redAccent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      active
                          ? (verified
                                ? 'حساب التاجر موثق ومفعل'
                                : 'حساب التاجر غير موثق')
                          : 'حساب التاجر غير مفعل',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontFamily: 'Cairo',
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMerchantMenuSheet() {
    showLockedModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Theme.of(context).colorScheme.scrim.withAlpha(140),
      builder: (ctx) {
        return SafeArea(
          child: GlassBottomSheet(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _merchantStream,
                  builder: (context, snapshot) {
                    final data = snapshot.data?.data() ?? <String, dynamic>{};
                    final manualOffline =
                        data['merchant_manual_offline'] == true;
                    final visibleOnline = !manualOffline;
                    return ListTile(
                      leading: Icon(
                        visibleOnline
                            ? Icons.wifi_tethering_rounded
                            : Icons.wifi_off_rounded,
                        color: visibleOnline ? Colors.green : Colors.redAccent,
                      ),
                      title: Text(
                        visibleOnline
                            ? 'إخفاء ظهوري (أوفلاين)'
                            : 'إظهار نفسي كأونلاين',
                        style: const TextStyle(fontFamily: 'Cairo'),
                      ),
                      subtitle: Text(
                        visibleOnline
                            ? 'الحالة الحالية: متصل'
                            : 'الحالة الحالية: غير متصل',
                        style: const TextStyle(fontFamily: 'Cairo'),
                      ),
                      onTap: _updatingPresenceVisibility
                          ? null
                          : () {
                              Navigator.pop(ctx);
                              unawaited(
                                _setPresenceVisibility(
                                  showOnline: !visibleOnline,
                                ),
                              );
                            },
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text(
                    'سياسة الخصوصية',
                    style: TextStyle(fontFamily: 'Cairo'),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    AppNavigator.pushNamed(context, '/privacy');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.verified_user_outlined),
                  title: const Text(
                    'توثيق التاجر',
                    style: TextStyle(fontFamily: 'Cairo'),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    AppNavigator.pushNamed(context, '/merchant/verify');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.swap_horiz_rounded),
                  title: const Text(
                    'الذهاب لوضع المستخدم',
                    style: TextStyle(fontFamily: 'Cairo'),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    unawaited(_switchToUserMode());
                  },
                ),
                if (!kIsWeb)
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded),
                    title: const Text(
                      'حول التطبيق',
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      AppNavigator.pushNamed(context, '/about');
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final colorScheme = Theme.of(context).colorScheme;
    return GlassAppBar(
      automaticallyImplyLeading: false,
      title: const SizedBox.shrink(),
      actions: [
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _merchantStream,
          builder: (context, snapshot) {
            final data = snapshot.data?.data() ?? <String, dynamic>{};
            final manualOffline = data['merchant_manual_offline'] == true;
            final visibleOnline = !manualOffline;
            return IconButton(
              tooltip: visibleOnline
                  ? 'إخفاء الظهور كأونلاين'
                  : 'إظهار الظهور كأونلاين',
              icon: _updatingPresenceVisibility
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary,
                      ),
                    )
                  : Icon(
                      visibleOnline
                          ? Icons.wifi_tethering_rounded
                          : Icons.wifi_off_rounded,
                      color: visibleOnline ? Colors.green : Colors.redAccent,
                    ),
              onPressed: _updatingPresenceVisibility
                  ? null
                  : () => _setPresenceVisibility(showOnline: !visibleOnline),
            );
          },
        ),
        IconButton(
          tooltip: 'تعديل الحساب',
          icon: const Icon(Icons.person_outline),
          onPressed: () => AppNavigator.pushNamed(context, '/account'),
        ),
        IconButton(
          tooltip: 'تغيير الثيم',
          icon: Icon(
            Theme.of(context).brightness == Brightness.dark
                ? Icons.nightlight_round
                : Icons.wb_sunny_rounded,
          ),
          onPressed: () => showThemeModeSheet(context),
        ),
        IconButton(
          tooltip: 'القائمة',
          icon: const Icon(Icons.more_vert),
          onPressed: _showMerchantMenuSheet,
        ),
        IconButton(
          tooltip: 'تسجيل الخروج',
          icon: _loggingOut
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.error,
                  ),
                )
              : Icon(Icons.logout, color: colorScheme.error),
          onPressed: _loggingOut ? null : _logout,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final statuses = <String>[
      'all',
      'pending_payment',
      'pending_review',
      'processing',
      'completed',
      'rejected',
    ];

    return Scaffold(
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          const SnowBackground(),
          Column(
            children: [
              _buildSubscriptionBanner(),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: statuses.map((status) {
                    final selected = _statusFilter == status;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(
                          _statusLabel(status),
                          style: const TextStyle(fontFamily: 'Cairo'),
                        ),
                        selected: selected,
                        selectedColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        onSelected: (_) {
                          setState(() {
                            _statusFilter = status;
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _merchantStream,
                  builder: (context, merchantSnap) {
                    final merchantData = merchantSnap.data?.data() ?? {};
                    final active = merchantData['merchant_active'] != false;
                    final verified = _isMerchantVerified(merchantData);
                    final trial = _isTrialActive(merchantData);
                    final paidUntil = merchantData['merchant_paid_until'];
                    final paid =
                        paidUntil is Timestamp &&
                        DateTime.now().isBefore(paidUntil.toDate());
                    if (!verified) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'حساب التاجر غير موثق بعد. ارفع البطاقة (وش + ظهر) وسيتم المراجعة خلال ساعة إلى 24 ساعة.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontFamily: 'Cairo'),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                onPressed: () => AppNavigator.pushNamed(
                                  context,
                                  '/merchant/verify',
                                ),
                                icon: const Icon(Icons.verified_user_outlined),
                                label: const Text(
                                  'فتح شاشة التوثيق',
                                  style: TextStyle(fontFamily: 'Cairo'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    if (!active || (!trial && !paid)) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'حساب التاجر غير مفعل. تواصل مع دعم التطبيق للتفعيل أو تجديد الاشتراك.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontFamily: 'Cairo'),
                          ),
                        ),
                      );
                    }

                    return CustomMaterialIndicator(
                      onRefresh: _handleRefresh,
                      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: _currencyStream,
                        builder: (context, currencySnap) {
                          final autoBaseCostPer1000 =
                              _merchantAutoBaseCostPer1000(
                                currencySnap.data?.data(),
                              );
                          return StreamBuilder<
                            QuerySnapshot<Map<String, dynamic>>
                          >(
                            stream: _ordersStream,
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                if (_isMissingIndexError(snapshot.error) &&
                                    _useIndexedOrdersQuery) {
                                  unawaited(_switchToFallbackQuery());
                                  return _buildRefreshableCenteredState(
                                    child: const Text(
                                      'جاري تجهيز تحميل الطلبات...',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontFamily: 'Cairo'),
                                    ),
                                  );
                                }
                                return _buildRefreshableCenteredState(
                                  child: Text(
                                    _useIndexedOrdersQuery
                                        ? 'تعذر تحميل الطلبات حالياً. اسحب للتحديث.'
                                        : 'تعذر تحميل الطلبات حتى في الوضع الاحتياطي. اسحب للتحديث أو تحقق من الإنترنت.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontFamily: 'Cairo'),
                                  ),
                                );
                              }
                              if (!snapshot.hasData) {
                                return _buildRefreshableCenteredState(
                                  child: const CircularProgressIndicator(),
                                );
                              }
                              final rawDocs = snapshot.data!.docs
                                  .where(
                                    (doc) => _isSupportedMerchantOrderType(
                                      (doc.data()['product_type'] ?? 'tiktok')
                                          .toString()
                                          .trim(),
                                    ),
                                  )
                                  .toList(growable: false);
                              if (rawDocs.isEmpty &&
                                  !_useMerchantWhatsappLookup &&
                                  widget.merchantWhatsapp.trim().isNotEmpty) {
                                unawaited(_switchToWhatsappLookup());
                                return _buildRefreshableCenteredState(
                                  child: const Text(
                                    'لا توجد طلبات حالياً.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontFamily: 'Cairo'),
                                  ),
                                );
                              }
                              if (!_useIndexedOrdersQuery) {
                                rawDocs.sort((a, b) {
                                  final aTs = a.data()['created_at'];
                                  final bTs = b.data()['created_at'];
                                  if (aTs is Timestamp && bTs is Timestamp) {
                                    return bTs.compareTo(aTs);
                                  }
                                  if (bTs is Timestamp) return 1;
                                  if (aTs is Timestamp) return -1;
                                  return b.id.compareTo(a.id);
                                });
                              }
                              final docs = _statusFilter == 'all'
                                  ? rawDocs
                                  : rawDocs
                                        .where(
                                          (doc) =>
                                              (doc.data()['status'] ?? '')
                                                  .toString() ==
                                              _statusFilter,
                                        )
                                        .toList(growable: false);

                              if (docs.isEmpty) {
                                return _buildRefreshableCenteredState(
                                  child: const Text(
                                    'لا توجد طلبات حالياً.',
                                    style: TextStyle(fontFamily: 'Cairo'),
                                  ),
                                );
                              }

                              return ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  8,
                                  12,
                                  18,
                                ),
                                itemCount: docs.length,
                                itemBuilder: (context, index) {
                                  final doc = docs[index];
                                  return MerchantOrderCard(
                                    key: ValueKey(doc.id),
                                    id: doc.id,
                                    data: doc.data(),
                                    merchantId: widget.merchantId,
                                    merchantName: widget.merchantName,
                                    merchantWhatsapp: widget.merchantWhatsapp,
                                    autoBaseCostPer1000: autoBaseCostPer1000,
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MerchantOrderCard extends StatefulWidget {
  final String id;
  final Map<String, dynamic> data;
  final String merchantId;
  final String merchantName;
  final String merchantWhatsapp;
  final double? autoBaseCostPer1000;

  const MerchantOrderCard({
    super.key,
    required this.id,
    required this.data,
    required this.merchantId,
    required this.merchantName,
    required this.merchantWhatsapp,
    this.autoBaseCostPer1000,
  });

  @override
  State<MerchantOrderCard> createState() => _MerchantOrderCardState();
}

class _MerchantOrderCardState extends State<MerchantOrderCard> {
  bool _isUpdating = false;
  bool _showTiktokPassword = false;

  bool get _isFinalStatus {
    final s = (widget.data['status'] ?? '').toString();
    return s == 'completed' || s == 'rejected' || s == 'cancelled';
  }

  String _orderUserWhatsapp(Map<String, dynamic> orderData) {
    final primary = (orderData['user_whatsapp'] ?? '').toString().trim();
    if (primary.isNotEmpty) return primary;
    return (orderData['whatsapp'] ?? '').toString().trim();
  }

  String _normalizedMerchantWhatsapp() {
    return WhatsappUtils.normalizeEgyptianWhatsapp(widget.merchantWhatsapp);
  }

  Future<String?> _promptRequiredRejectReason({
    required String merchantWhatsapp,
  }) async {
    final reasonCtrl = TextEditingController();
    String? errorText;
    final result = await showLockedDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text(
            'سبب رفض الطلب (إلزامي)',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'اكتب سبب الرفض الذي سيظهر للعميل.',
                style: TextStyle(fontFamily: 'Cairo'),
              ),
              const SizedBox(height: 8),
              Text(
                'رقم التواصل معك: $merchantWhatsapp',
                style: TextStyle(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reasonCtrl,
                autofocus: true,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'سبب الرفض',
                  errorText: errorText,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                final reason = reasonCtrl.text.trim();
                if (reason.length < 4) {
                  setStateDialog(() {
                    errorText = 'سبب الرفض مطلوب (4 أحرف على الأقل)';
                  });
                  return;
                }
                Navigator.pop(ctx, reason);
              },
              child: const Text('إرسال الطلب'),
            ),
          ],
        ),
      ),
    );
    reasonCtrl.dispose();
    return result;
  }

  int _parseIntValue(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse((raw ?? '').toString().trim()) ?? 0;
  }

  double _parseDoubleValue(dynamic raw) {
    if (raw is double) return raw;
    if (raw is int) return raw.toDouble();
    if (raw is num) return raw.toDouble();
    return double.tryParse(
          (raw ?? '').toString().trim().replaceAll(',', '.'),
        ) ??
        0;
  }

  String _formatAmount(double value) {
    final fixed = value.toStringAsFixed(6);
    return fixed
        .replaceFirst(RegExp(r'\.?0+$'), '')
        .replaceAll(RegExp(r'(\.\d*?)0+$'), r'$1');
  }

  double? _requestedCoinsValue(Map<String, dynamic> orderData) {
    final productType = (orderData['product_type'] ?? 'tiktok')
        .toString()
        .trim();
    if (productType == 'game') {
      final quantity = _parseDoubleValue(orderData['package_quantity']);
      return quantity > 0 ? quantity : null;
    }
    if (productType == 'tiktok') {
      final points = _parseDoubleValue(orderData['points']);
      return points > 0 ? points : null;
    }
    return null;
  }

  String? _requestedCoinsText(Map<String, dynamic> orderData) {
    final value = _requestedCoinsValue(orderData);
    if (value == null || value <= 0) return null;
    return _formatAmount(value);
  }

  double? _estimatedAutoCost() {
    final basePrice = widget.autoBaseCostPer1000;
    if (basePrice == null || basePrice <= 0) return null;
    final coins = _requestedCoinsValue(widget.data);
    if (coins == null) return null;
    return (coins / 1000) * basePrice;
  }

  bool _isChatSupportedOrderType(String productType) {
    return productType == 'tiktok' ||
        productType == 'game' ||
        isPromoProductType(productType);
  }

  Future<void> _openOrderChatFullscreen() async {
    final status = (widget.data['status'] ?? '').toString().trim();
    if (!_isFinalStatus && status != 'processing') {
      await _updateStatus('processing');
      if (!mounted) return;
    }
    AppNavigator.pushNamed(
      context,
      '/order_chat',
      arguments: <String, dynamic>{
        'order_id': widget.id,
        'viewer_role': 'merchant',
        'viewer_name': widget.merchantName,
      },
    );
  }

  int _extractPointsUsed(Map<String, dynamic> orderData) {
    final direct = _parseIntValue(orderData['points_used_total']);
    if (direct > 0) return direct;
    final paid = _parseIntValue(orderData['points_paid']);
    final discount = _parseIntValue(orderData['points_discount']);
    final sum = paid + discount;
    return sum > 0 ? sum : 0;
  }

  Future<void> _updateStatus(
    String newStatus, {
    String? rejectionReason,
    String? rejectionContactWhatsapp,
  }) async {
    if (_isFinalStatus) {
      if (mounted) {
        TopSnackBar.show(
          context,
          "لا يمكن تعديل حالة طلب مكتمل أو مرفوض",
          backgroundColor: Colors.red,
          textColor: Colors.white,
          icon: Icons.block,
        );
      }
      return;
    }
    final safeRejectionReason = (rejectionReason ?? '').trim();
    final safeRejectionContact = WhatsappUtils.normalizeEgyptianWhatsapp(
      rejectionContactWhatsapp ?? '',
    );
    if (newStatus == 'rejected') {
      if (safeRejectionReason.length < 4) {
        if (mounted) {
          TopSnackBar.show(
            context,
            "سبب الرفض مطلوب (4 أحرف على الأقل)",
            backgroundColor: Colors.orange,
            textColor: Colors.white,
            icon: Icons.error_outline,
          );
        }
        return;
      }
      if (!WhatsappUtils.isValidEgyptianWhatsapp(safeRejectionContact)) {
        if (mounted) {
          TopSnackBar.show(
            context,
            "رقم التواصل للتاجر غير صالح (11 رقم يبدأ بـ01)",
            backgroundColor: Colors.orange,
            textColor: Colors.white,
            icon: Icons.phone_outlined,
          );
        }
        return;
      }
    }

    setState(() => _isUpdating = true);
    try {
      final isPromoOrder = isPromoProductType(
        (widget.data['product_type'] ?? '').toString(),
      );
      final updateData = <String, dynamic>{
        'status': newStatus,
        if (newStatus == 'completed' && isPromoOrder) 'video_link': null,
        if (newStatus == 'completed' && isPromoOrder)
          'video_link_removed_at': FieldValue.serverTimestamp(),
        if (newStatus == 'rejected') 'rejection_reason': safeRejectionReason,
        if (newStatus == 'rejected')
          'rejection_contact_whatsapp': safeRejectionContact,
        if (newStatus == 'rejected') 'tiktok_password': FieldValue.delete(),
        if (newStatus != 'rejected') 'rejection_reason': FieldValue.delete(),
        if (newStatus != 'rejected')
          'rejection_contact_whatsapp': FieldValue.delete(),
        'merchant_status_request': FieldValue.delete(),
        'merchant_status_request_state': FieldValue.delete(),
        'merchant_status_request_at': FieldValue.delete(),
        'merchant_status_request_by_uid': FieldValue.delete(),
        'merchant_status_request_by_name': FieldValue.delete(),
        'merchant_status_request_reason': FieldValue.delete(),
        'merchant_status_request_contact_whatsapp': FieldValue.delete(),
        'merchant_status_request_resolved_at': FieldValue.delete(),
        'merchant_status_request_resolved_by': FieldValue.delete(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.id)
          .update(updateData);

      if (!mounted) return;
      setState(() {
        widget.data['status'] = newStatus;
        if (newStatus == 'completed' && isPromoOrder) {
          widget.data['video_link'] = null;
        }
        if (newStatus == 'rejected') {
          widget.data['rejection_reason'] = safeRejectionReason;
          widget.data['rejection_contact_whatsapp'] = safeRejectionContact;
          widget.data.remove('tiktok_password');
        } else {
          widget.data.remove('rejection_reason');
          widget.data.remove('rejection_contact_whatsapp');
        }
        widget.data.remove('merchant_status_request');
        widget.data.remove('merchant_status_request_state');
        widget.data.remove('merchant_status_request_at');
        widget.data.remove('merchant_status_request_by_uid');
        widget.data.remove('merchant_status_request_by_name');
        widget.data.remove('merchant_status_request_reason');
        widget.data.remove('merchant_status_request_contact_whatsapp');
        widget.data.remove('merchant_status_request_resolved_at');
        widget.data.remove('merchant_status_request_resolved_by');
      });

      final userWhatsapp = _orderUserWhatsapp(widget.data);
      if (userWhatsapp.isNotEmpty) {
        unawaited(
          CloudflareNotifyService.notifyUserOrderStatus(
            userWhatsapp: userWhatsapp,
            orderId: widget.id,
            status: newStatus,
            rejectionReason: newStatus == 'rejected'
                ? safeRejectionReason
                : null,
          ),
        );
      }
      if (newStatus == 'processing') {
        unawaited(
          OrderChatService.addSystemMessage(
            orderId: widget.id,
            text: "بدأ تنفيذ الطلب. الشات مفتوح بين المستخدم والتاجر.",
          ),
        );
      } else if (newStatus == 'rejected') {
        unawaited(
          OrderChatService.addSystemMessage(
            orderId: widget.id,
            text:
                'تم رفض الطلب بواسطة التاجر.\nسبب الرفض: $safeRejectionReason',
          ),
        );
      } else if (newStatus == 'completed') {
        unawaited(
          OrderChatService.addSystemMessage(
            orderId: widget.id,
            text: "تم تنفيذ الطلب بواسطة التاجر ✅",
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        TopSnackBar.show(
          context,
          "حدث خطأ أثناء تحديث حالة الطلب",
          backgroundColor: Colors.red,
          textColor: Colors.white,
          icon: Icons.error_outline,
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _rejectOrderDirect() async {
    if (_isFinalStatus) {
      if (mounted) {
        TopSnackBar.show(
          context,
          "لا يمكن تعديل حالة طلب مكتمل أو مرفوض",
          backgroundColor: Colors.red,
          textColor: Colors.white,
          icon: Icons.block,
        );
      }
      return;
    }

    final normalizedMerchantWhatsapp = _normalizedMerchantWhatsapp();
    if (!WhatsappUtils.isValidEgyptianWhatsapp(normalizedMerchantWhatsapp)) {
      if (mounted) {
        TopSnackBar.show(
          context,
          "رقم واتساب التاجر غير صالح. حدّث رقمك أولاً (11 رقم يبدأ بـ01).",
          backgroundColor: Colors.orange,
          textColor: Colors.white,
          icon: Icons.phone_outlined,
        );
      }
      return;
    }
    final reason = await _promptRequiredRejectReason(
      merchantWhatsapp: normalizedMerchantWhatsapp,
    );
    if (!mounted || reason == null) return;

    await _updateStatus(
      'rejected',
      rejectionReason: reason.trim(),
      rejectionContactWhatsapp: normalizedMerchantWhatsapp,
    );
    if (!mounted) return;
    TopSnackBar.show(
      context,
      "تم رفض الطلب مباشرة ✅",
      backgroundColor: Colors.green,
      textColor: Colors.white,
      icon: Icons.check_circle,
    );
  }

  Future<void> _completeOrderDirect() async {
    await _updateStatus('completed');
    if (!mounted) return;
    if ((widget.data['status'] ?? '').toString() == 'completed') {
      TopSnackBar.show(
        context,
        "تم تعيين الطلب كتم التنفيذ ✅",
        backgroundColor: Colors.green,
        textColor: Colors.white,
        icon: Icons.check_circle,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = (widget.data['status'] ?? '').toString();
    final productType = (widget.data['product_type'] ?? 'tiktok')
        .toString()
        .trim();
    final bool isGameOrder = productType == 'game';
    final bool isPromoOrder = isPromoProductType(productType);
    final bool supportsOrderChat = _isChatSupportedOrderType(productType);

    final name = (widget.data['name'] ?? '').toString().trim();
    final tiktok = (widget.data['user_tiktok'] ?? '').toString().trim();
    final createdAt = widget.data['created_at'];
    final createdAtText = createdAt is Timestamp
        ? createdAt.toDate().toLocal().toString().substring(0, 16)
        : '';
    final requestedCoinsText = _requestedCoinsText(widget.data);
    final pointsUsed = _extractPointsUsed(widget.data);
    final price = (widget.data['price'] ?? '').toString();
    final paymentMethod = (widget.data['method'] ?? '').toString();
    final gameKey = (widget.data['game'] ?? '').toString().trim();
    final packageLabel = (widget.data['package_label'] ?? '').toString().trim();
    final gameId = (widget.data['game_id'] ?? '').toString();
    final promoVideoLink = (widget.data['video_link'] ?? '').toString().trim();
    final promoLinkLabel = promoLinkLabelFromProductType(productType);
    final tiktokPassword = (widget.data['tiktok_password'] ?? '')
        .toString()
        .trim();
    final autoBaseCostPer1000 = widget.autoBaseCostPer1000;
    final estimatedAutoCost = _estimatedAutoCost();
    final tiktokChargeMode = (widget.data['tiktok_charge_mode'] ?? '')
        .toString()
        .trim();
    final tiktokChargeModeLabel = tiktokChargeMode == 'username_password'
        ? 'يوزر + باسورد'
        : tiktokChargeMode == 'qr'
        ? 'QR'
        : tiktokChargeMode == 'link'
        ? 'لينك'
        : '';

    return GlassCard(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '#${widget.id}',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: TTColors.cardBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  OrderStatusHelper.label(status),
                  style: TextStyle(
                    color: OrderStatusHelper.color(status),
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'الاسم: ${name.isEmpty ? 'المستخدم' : name}',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            'المنتج: ${productType == 'tiktok'
                ? 'شحن تيك توك'
                : productType == 'game'
                ? 'شحن ألعاب'
                : isPromoProductType(productType)
                ? promoOrderTitleFromProductType(productType)
                : 'نوع غير مدعوم'}',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          if (isGameOrder && gameKey.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'اللعبة: ${GamePackage.gameLabel(gameKey)}',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
          if (isGameOrder && packageLabel.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'الباقة: $packageLabel',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
          if (requestedCoinsText != null) ...[
            const SizedBox(height: 4),
            Text(
              isGameOrder
                  ? 'الكمية المطلوبة: $requestedCoinsText'
                  : 'عدد العملات المطلوبة: $requestedCoinsText',
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (tiktok.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'يوزر: $tiktok',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
          if (price.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'السعر: $price جنيه',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'طريقة الدفع: $paymentMethod',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          if (pointsUsed > 0) ...[
            const SizedBox(height: 4),
            Text(
              'نقاط مستخدمة: $pointsUsed',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
          if (createdAtText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'توقيت الإنشاء: $createdAtText',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
          if (!isGameOrder && !isPromoOrder) ...[
            if (tiktokChargeModeLabel.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'طريقة شحن تيك توك: $tiktokChargeModeLabel',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ],
            if (!_isFinalStatus &&
                (tiktokChargeMode == 'username_password' ||
                    tiktokPassword.isNotEmpty)) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'كلمة مرور تيك توك: ${tiktokPassword.isEmpty ? 'غير مدخلة' : '•••••'}',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                  if (tiktokPassword.isNotEmpty)
                    IconButton(
                      onPressed: () => setState(() {
                        _showTiktokPassword = !_showTiktokPassword;
                      }),
                      icon: Icon(
                        _showTiktokPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                    ),
                  if (tiktokPassword.isNotEmpty)
                    IconButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: tiktokPassword));
                        TopSnackBar.show(
                          this.context,
                          "تم نسخ باسورد تيك توك",
                          backgroundColor: colorScheme.surface,
                          textColor: colorScheme.onSurface,
                          icon: Icons.check_circle,
                        );
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      tooltip: "نسخ باسورد تيك توك",
                    ),
                ],
              ),
              if (_showTiktokPassword && tiktokPassword.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: SelectableText(
                    tiktokPassword,
                    style: TextStyle(color: colorScheme.primary),
                  ),
                ),
            ],
          ],
          if (isGameOrder && gameId.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    "ID: $gameId",
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (isPromoOrder && promoVideoLink.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    "$promoLinkLabel: $promoVideoLink",
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    final safe = ensureHttps(promoVideoLink.trim());
                    await launcher.launchUrl(
                      Uri.parse(safe),
                      mode: launcher.LaunchMode.externalApplication,
                    );
                  },
                  icon: const Icon(Icons.open_in_new, size: 18),
                  tooltip: "فتح $promoLinkLabel",
                ),
              ],
            ),
          ],
          if (requestedCoinsText != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withAlpha(54),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.primary.withAlpha(70)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'حساب التكلفة التلقائي',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (autoBaseCostPer1000 != null) ...[
                    Text(
                      'سعر ال1000 بدون تكلفة: ${_formatAmount(autoBaseCostPer1000)} ج.م',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ] else
                    Text(
                      'تعذر تحميل سعر التكلفة من إعدادات الأدمن حالياً.',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (estimatedAutoCost != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'سعر التكلفة: ${_formatAmount(estimatedAutoCost)} ج.م',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (supportsOrderChat) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openOrderChatFullscreen,
                icon: const Icon(Icons.forum_outlined),
                label: const Text(
                  'فتح المحادثة كاملة',
                  style: TextStyle(fontFamily: 'Cairo'),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (!isGameOrder && !isPromoOrder && !_isFinalStatus) ...[
            if (tiktokChargeMode == 'qr')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withAlpha(60),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'الطلب بنظام QR. أرسل صورة QR عبر الشات.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (tiktokChargeMode == 'username_password')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withAlpha(60),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'تم استلام اليوزر والباسورد. تابع التنفيذ عبر الشات.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 10),
          ],
          Builder(
            builder: (_) {
              if (_isUpdating) {
                return const CircularProgressIndicator();
              }

              if (_isFinalStatus) {
                final status = (widget.data['status'] ?? '').toString();
                final statusText = status == 'completed'
                    ? 'مكتمل'
                    : status == 'rejected'
                    ? 'مرفوض'
                    : 'ملغي';
                return Column(
                  children: [
                    Text(
                      "تم تعيين الطلب ك$statusText.\nلا يمكن تعديل الحالة أو البيانات بعد ذلك.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _completeOrderDirect,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 48),
                          ),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              "تم التنفيذ",
                              style: TextStyle(fontFamily: 'Cairo'),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _rejectOrderDirect,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            minimumSize: const Size(0, 48),
                          ),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              "رفض الطلب",
                              style: TextStyle(fontFamily: 'Cairo'),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
