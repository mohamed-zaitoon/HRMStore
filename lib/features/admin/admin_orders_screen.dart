// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;
import 'dart:async';

import '../../core/app_navigator.dart';
import '../../core/order_status.dart';
import '../../core/tt_colors.dart';
import '../../services/admin_session_service.dart';
import '../../services/cloudflare_notify_service.dart';
import '../../services/order_chat_service.dart';
import '../../services/receipt_storage_service.dart';
import '../../models/game_package.dart';
import '../../widgets/theme_mode_sheet.dart';
import '../../widgets/top_snackbar.dart';
import '../../widgets/glass_bottom_sheet.dart';
import '../../widgets/glass_app_bar.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/order_chat_panel.dart';
import '../../widgets/snow_background.dart';
import '../../utils/url_sanitizer.dart';

enum _QrImageSourceOption { camera, files }

class AdminOrdersScreen extends StatefulWidget {
  // EN: Creates AdminOrdersScreen.
  // AR: ينشئ AdminOrdersScreen.
  const AdminOrdersScreen({super.key});

  // EN: Creates state object.
  // AR: تنشئ كائن الحالة.
  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _menuIconController;
  String _statusFilter = 'all';
  late Stream<QuerySnapshot<Map<String, dynamic>>> _ordersStream;
  bool _checkingAuth = true;
  String? _adminId;

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

  bool _isSupportedAdminOrderType(String productType) {
    return productType == 'tiktok' ||
        productType == 'game' ||
        productType == 'tiktok_promo';
  }

  // EN: Initializes widget state.
  // AR: تهيّئ حالة الودجت.
  @override
  void initState() {
    super.initState();
    _menuIconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _ordersStream = const Stream.empty();
    _ensureAdminSession();
  }

  Future<void> _ensureAdminSession() async {
    final bool valid = await AdminSessionService.validateCurrentSession();
    final session = await AdminSessionService.getLocalSession();

    if (!mounted) return;

    if (!valid || session == null) {
      await AdminSessionService.clearLocalSession();
      if (!mounted) return;
      AppNavigator.pushNamedAndRemoveUntil(context, '/admin', (route) => false);
      return;
    }

    setState(() {
      _adminId = session.adminId;
      _ordersStream = _getStream();
      _checkingAuth = false;
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _getStream() {
    final query = FirebaseFirestore.instance
        .collection('orders')
        .orderBy('created_at', descending: true)
        .limit(500);
    // نستخدم استعلاماً واحداً بدون where لتجنب أخطاء الفهرسة المركبة،
    // ثم نطبّق الفلترة حسب الحالة محلياً داخل الواجهة.
    return query.snapshots();
  }

  // EN: Releases resources.
  // AR: تفرّغ الموارد.
  @override
  void dispose() {
    _menuIconController.dispose();
    super.dispose();
  }

  // EN: Handles logout Admin.
  // AR: تتعامل مع logout Admin.
  Future<void> _logoutAdmin() async {
    await AdminSessionService.logoutCurrentDevice(_adminId);
    await AdminSessionService.clearLocalSession();

    if (mounted) {
      AppNavigator.pushNamedAndRemoveUntil(context, '/admin', (route) => false);
    }
  }

  // EN: Opens Devices Screen.
  // AR: تفتح Devices Screen.
  Future<void> _openDevicesScreen() async {
    final adminId = _adminId ?? await AdminSessionService.getLocalAdminId();

    if (adminId == null || adminId.isEmpty) {
      if (!mounted) return;
      final colorScheme = Theme.of(context).colorScheme;
      TopSnackBar.show(
        context,
        "لم يتم العثور على هوية الأدمن (admin_id)",
        backgroundColor: colorScheme.error,
        textColor: colorScheme.onError,
        icon: Icons.error,
      );
      return;
    }

    if (!mounted) return;

    AppNavigator.pushNamed(context, '/admin/devices', arguments: adminId);
  }

  // EN: Shows Admin Menu Sheet.
  // AR: تعرض Admin Menu Sheet.
  void _showAdminMenuSheet() {
    _menuIconController.forward();
    showModalBottomSheet(
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
                  title: "طلبات أكواد المستخدمين",
                  onTap: () {
                    Navigator.pop(ctx);
                    AppNavigator.pushNamed(context, '/admin/requests');
                  },
                ),

                _menuTile(
                  icon: Icons.confirmation_number,
                  title: "إدارة الأكواد",
                  onTap: () {
                    Navigator.pop(ctx);
                    AppNavigator.pushNamed(context, '/admin/codes');
                  },
                ),

                _menuTile(
                  icon: Icons.price_change,
                  title: "تعديل الأسعار",
                  onTap: () {
                    Navigator.pop(ctx);
                    AppNavigator.pushNamed(context, '/admin/prices');
                  },
                ),

                _menuTile(
                  icon: Icons.local_offer,
                  title: "عروض الأسعار",
                  onTap: () {
                    Navigator.pop(ctx);
                    AppNavigator.pushNamed(context, '/admin/offers');
                  },
                ),

                _menuTile(
                  icon: Icons.calculate,
                  title: "حاسبة التكلفة اليدوية",
                  onTap: () {
                    Navigator.pop(ctx);
                    AppNavigator.pushNamed(context, '/admin/cost-calculator');
                  },
                ),

                _menuTile(
                  icon: Icons.games,
                  title: "شحن الألعاب",
                  onTap: () {
                    Navigator.pop(ctx);
                    AppNavigator.pushNamed(context, '/admin/games');
                  },
                ),

                _menuTile(
                  icon: Icons.people_alt,
                  title: "بيانات المستخدمين",
                  onTap: () {
                    Navigator.pop(ctx);
                    AppNavigator.pushNamed(context, '/admin/users');
                  },
                ),

                _menuTile(
                  icon: Icons.schedule,
                  title: "تشغيل/إيقاف الويب و Android Release",
                  onTap: () {
                    Navigator.pop(ctx);
                    AppNavigator.pushNamed(context, '/admin/availability');
                  },
                ),

                _menuTile(
                  icon: Icons.devices,
                  title: "التحكم في الأجهزة",
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _openDevicesScreen();
                  },
                ),

                _menuTile(
                  icon: Icons.support_agent,
                  title: "شات الاستفسارات",
                  onTap: () {
                    Navigator.pop(ctx);
                    AppNavigator.pushNamed(context, '/admin/support_inquiries');
                  },
                ),

                _menuTile(
                  icon: Icons.account_balance_wallet,
                  title: "المحافظ",
                  onTap: () {
                    Navigator.pop(ctx);
                    AppNavigator.pushNamed(context, '/admin/wallets');
                  },
                ),

                _menuTile(
                  icon: Theme.of(context).brightness == Brightness.dark
                      ? Icons.nightlight_round
                      : Icons.wb_sunny_rounded,
                  title: "وضع التطبيق",
                  onTap: () async {
                    Navigator.pop(ctx);
                    await showThemeModeSheet(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      if (mounted) _menuIconController.reverse();
    });
  }

  // EN: Handles menu Tile.
  // AR: تتعامل مع menu Tile.
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

  // EN: Builds Mobile App Bar.
  // AR: تبني Mobile App Bar.
  PreferredSizeWidget _buildMobileAppBar() {
    final colorScheme = Theme.of(context).colorScheme;
    return GlassAppBar(
      automaticallyImplyLeading: false,
      leading: IconButton(
        icon: Icon(Icons.logout, color: colorScheme.error),
        tooltip: "خروج نهائي",
        onPressed: _logoutAdmin,
      ),
      title: const Text('طلبات الشحن 📦'),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(Icons.devices, color: colorScheme.primary),
          tooltip: "الأجهزة المسجّل منها",
          onPressed: _openDevicesScreen,
        ),

        IconButton(
          icon: AnimatedIcon(
            icon: AnimatedIcons.menu_close,
            progress: _menuIconController,
          ),
          tooltip: "القائمة",
          onPressed: _showAdminMenuSheet,
        ),
      ],
    );
  }

  // EN: Builds Web App Bar.
  // AR: تبني Web App Bar.
  PreferredSizeWidget _buildWebAppBar() {
    final colorScheme = Theme.of(context).colorScheme;
    return GlassAppBar(
      title: const Text('طلبات الشحن 📦'),
      automaticallyImplyLeading: false,
      actions: [
        IconButton(
          icon: Icon(Icons.card_giftcard, color: colorScheme.tertiary),
          tooltip: "طلبات أكواد المستخدمين",
          onPressed: () {
            AppNavigator.pushNamed(context, '/admin/requests');
          },
        ),

        IconButton(
          icon: Icon(Icons.confirmation_number, color: colorScheme.primary),
          tooltip: "إدارة الأكواد",
          onPressed: () {
            AppNavigator.pushNamed(context, '/admin/codes');
          },
        ),

        IconButton(
          icon: Icon(Icons.price_change, color: colorScheme.secondary),
          tooltip: "تعديل الأسعار",
          onPressed: () {
            AppNavigator.pushNamed(context, '/admin/prices');
          },
        ),

        IconButton(
          icon: Icon(Icons.local_offer, color: colorScheme.tertiary),
          tooltip: "عروض الأسعار",
          onPressed: () {
            AppNavigator.pushNamed(context, '/admin/offers');
          },
        ),

        IconButton(
          icon: Icon(Icons.calculate, color: colorScheme.primary),
          tooltip: "حاسبة التكلفة اليدوية",
          onPressed: () {
            AppNavigator.pushNamed(context, '/admin/cost-calculator');
          },
        ),

        IconButton(
          icon: Icon(Icons.devices, color: colorScheme.onSurface),
          tooltip: "الأجهزة المسجّل منها",
          onPressed: _openDevicesScreen,
        ),

        IconButton(
          icon: Icon(Icons.support_agent, color: colorScheme.primary),
          tooltip: "شات الاستفسارات",
          onPressed: () {
            AppNavigator.pushNamed(context, '/admin/support_inquiries');
          },
        ),

        IconButton(
          icon: Icon(Icons.logout, color: colorScheme.error),
          tooltip: "خروج نهائي",
          onPressed: _logoutAdmin,
        ),
      ],
    );
  }

  // EN: Builds widget UI.
  // AR: تبني واجهة الودجت.
  @override
  Widget build(BuildContext context) {
    if (_checkingAuth) {
      return const Scaffold(
        body: Stack(
          children: [
            SnowBackground(),
            Center(child: CircularProgressIndicator()),
          ],
        ),
      );
    }

    final bool isSmallMobile = MediaQuery.of(context).size.width < 800;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (!kIsWeb) SystemNavigator.pop();
      },
      child: Scaffold(
        appBar: isSmallMobile ? _buildMobileAppBar() : _buildWebAppBar(),
        body: Stack(
          children: [
            const SnowBackground(),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _ordersStream,
              builder: (c, s) {
                if (s.hasError) {
                  return const Center(child: Text("حدث خطأ في جلب البيانات"));
                }
                if (!s.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (s.data!.docs.isEmpty) {
                  return const Center(child: Text("لا توجد طلبات شحن"));
                }

                final statuses = <String>[
                  'all',
                  'pending_payment',
                  'pending_review',
                  'processing',
                  'completed',
                  'rejected',
                ];

                final allDocs = s.data!.docs;
                final unassignedDocs = allDocs
                    .where(
                      (doc) =>
                          _isSupportedAdminOrderType(
                            (doc.data()['product_type'] ?? 'tiktok')
                                .toString()
                                .trim(),
                          ) &&
                          ((doc.data()['merchant_id'] ?? '').toString().trim())
                              .isEmpty,
                    )
                    .toList(growable: false);
                final docs = _statusFilter == 'all'
                    ? unassignedDocs
                    : unassignedDocs
                          .where(
                            (doc) =>
                                (doc.data()['status'] ?? '').toString() ==
                                _statusFilter,
                          )
                          .toList(growable: false);
                final widgets = <Widget>[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
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
                  if (docs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          _statusFilter == 'all'
                              ? "لا توجد طلبات شحن"
                              : "لا توجد طلبات في هذا التصنيف",
                        ),
                      ),
                    )
                  else
                    ...docs.map((doc) {
                      final data = doc.data();
                      return _AdminOrderCard(id: doc.id, data: data);
                    }),
                ];

                return CustomMaterialIndicator(
                  onRefresh: () async =>
                      Future.delayed(const Duration(milliseconds: 500)),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    children: widgets,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminOrderCard extends StatefulWidget {
  final String id;
  final Map<String, dynamic> data;

  // EN: Creates AdminOrderCard.
  // AR: ينشئ AdminOrderCard.
  const _AdminOrderCard({required this.id, required this.data});

  // EN: Creates state object.
  // AR: تنشئ كائن الحالة.
  @override
  State<_AdminOrderCard> createState() => _AdminOrderCardState();
}

class _AdminOrderCardState extends State<_AdminOrderCard> {
  static const Duration _deliveryAccessLifetime = Duration(seconds: 20);
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUpdating = false;
  bool _showTiktokPassword = false;

  bool get _cameraCaptureSupported {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  // EN: Handles is Final Status.
  // AR: تتعامل مع is Final Status.
  bool get _isFinalStatus {
    final s = (widget.data['status'] ?? '').toString();
    return s == 'completed' || s == 'rejected' || s == 'cancelled';
  }

  String _orderUserWhatsapp(Map<String, dynamic> orderData) {
    final primary = (orderData['user_whatsapp'] ?? '').toString().trim();
    if (primary.isNotEmpty) return primary;
    return (orderData['whatsapp'] ?? '').toString().trim();
  }

  String _normalizeWhatsapp(String value) {
    return value.replaceAll(RegExp(r'[^0-9+]'), '').trim();
  }

  Future<DocumentReference<Map<String, dynamic>>?> _resolveOrderUserRef(
    Map<String, dynamic> orderData,
  ) async {
    final users = FirebaseFirestore.instance.collection('users');
    final uid = (orderData['user_uid'] ?? orderData['uid'] ?? '')
        .toString()
        .trim();
    if (uid.isNotEmpty) {
      final uidRef = users.doc(uid);
      final uidSnap = await uidRef.get();
      if (uidSnap.exists) return uidRef;
      final uidQuery = await users.where('uid', isEqualTo: uid).limit(1).get();
      if (uidQuery.docs.isNotEmpty) return uidQuery.docs.first.reference;
    }

    final rawWhatsapp =
        (orderData['user_whatsapp'] ?? orderData['whatsapp'] ?? '')
            .toString()
            .trim();
    final normalizedWhatsapp = _normalizeWhatsapp(rawWhatsapp);
    if (rawWhatsapp.isNotEmpty) {
      final rawRef = users.doc(rawWhatsapp);
      final rawSnap = await rawRef.get();
      if (rawSnap.exists) return rawRef;
      final rawQuery = await users
          .where('whatsapp', isEqualTo: rawWhatsapp)
          .limit(1)
          .get();
      if (rawQuery.docs.isNotEmpty) return rawQuery.docs.first.reference;
    }

    if (normalizedWhatsapp.isNotEmpty && normalizedWhatsapp != rawWhatsapp) {
      final normalizedRef = users.doc(normalizedWhatsapp);
      final normalizedSnap = await normalizedRef.get();
      if (normalizedSnap.exists) return normalizedRef;
      final normalizedQuery = await users
          .where('whatsapp', isEqualTo: normalizedWhatsapp)
          .limit(1)
          .get();
      if (normalizedQuery.docs.isNotEmpty) {
        return normalizedQuery.docs.first.reference;
      }
    }

    return null;
  }

  int _parseIntValue(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse((raw ?? '').toString().trim()) ?? 0;
  }

  Timestamp _newDeliveryExpiryTimestamp() {
    return Timestamp.fromDate(DateTime.now().add(_deliveryAccessLifetime));
  }

  bool _isChatSupportedOrderType(String productType) {
    return productType == 'tiktok' ||
        productType == 'game' ||
        productType == 'tiktok_promo';
  }

  bool _isExecutionChatOpen(String status) {
    return status == 'pending_payment' ||
        status == 'pending_review' ||
        status == 'processing';
  }

  String _chatDisabledHint({
    required String status,
    required bool supportsChat,
  }) {
    if (!supportsChat) return 'هذا النوع من الطلبات لا يدعم الشات.';
    if (status == 'completed') return 'تم إغلاق الشات لأن الطلب مكتمل ✅';
    if (status == 'rejected') return 'تم إغلاق الشات لأن الطلب مرفوض ❌';
    if (status == 'cancelled') return 'تم إغلاق الشات لأن الطلب ملغي.';
    if (status == 'pending_payment') {
      return 'يمكن للمستخدم إرسال إثبات الدفع عبر الشات.';
    }
    return 'الشات غير متاح حالياً لهذا الطلب.';
  }

  int _extractPointsUsed(Map<String, dynamic> orderData) {
    final direct = _parseIntValue(orderData['points_used_total']);
    if (direct > 0) return direct;
    final paid = _parseIntValue(orderData['points_paid']);
    final discount = _parseIntValue(orderData['points_discount']);
    final sum = paid + discount;
    return sum > 0 ? sum : 0;
  }

  bool _hasPendingMerchantStatusRequest(Map<String, dynamic> orderData) {
    final state = (orderData['merchant_status_request_state'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final requested = (orderData['merchant_status_request'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    return state == 'pending' &&
        (requested == 'completed' || requested == 'rejected');
  }

  String _merchantRequestedStatusLabel(String requested) {
    switch (requested) {
      case 'completed':
        return 'تم التنفيذ';
      case 'rejected':
        return 'رفض الطلب';
      default:
        return 'تغيير الحالة';
    }
  }

  String _composeMerchantRejectionReasonForUser({
    required String reason,
    required String merchantWhatsapp,
  }) {
    final trimmedReason = reason.trim();
    final normalizedWhatsapp = _normalizeWhatsapp(merchantWhatsapp);
    if (trimmedReason.isEmpty) return '';
    if (normalizedWhatsapp.isEmpty) return trimmedReason;
    return '$trimmedReason\nللتواصل مع التاجر: $normalizedWhatsapp';
  }

  Future<void> _declineMerchantStatusRequest() async {
    if (!_hasPendingMerchantStatusRequest(widget.data)) {
      if (mounted) {
        TopSnackBar.show(
          context,
          "لا يوجد طلب من التاجر قيد المراجعة",
          backgroundColor: Colors.orange,
          textColor: Colors.white,
          icon: Icons.info_outline,
        );
      }
      return;
    }

    setState(() => _isUpdating = true);
    try {
      await FirebaseFirestore.instance.collection('orders').doc(widget.id).set({
        'merchant_status_request_state': 'declined',
        'merchant_status_request_resolved_at': FieldValue.serverTimestamp(),
        'merchant_status_request_resolved_by': 'admin',
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final requested = (widget.data['merchant_status_request'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final requestLabel = _merchantRequestedStatusLabel(requested);
      unawaited(
        OrderChatService.addSystemMessage(
          orderId: widget.id,
          text: 'الأدمن رفض طلب التاجر لتغيير الحالة إلى "$requestLabel".',
        ),
      );

      if (!mounted) return;
      setState(() => widget.data['merchant_status_request_state'] = 'declined');
      TopSnackBar.show(
        context,
        "تم رفض طلب التاجر",
        backgroundColor: Colors.orange,
        textColor: Colors.white,
        icon: Icons.gpp_bad_outlined,
      );
    } catch (_) {
      if (!mounted) return;
      TopSnackBar.show(
        context,
        "تعذر رفض طلب التاجر",
        backgroundColor: Colors.red,
        textColor: Colors.white,
        icon: Icons.error_outline,
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _approveMerchantStatusRequest() async {
    final requested = (widget.data['merchant_status_request'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (!_hasPendingMerchantStatusRequest(widget.data)) {
      if (mounted) {
        TopSnackBar.show(
          context,
          "لا يوجد طلب من التاجر قيد المراجعة",
          backgroundColor: Colors.orange,
          textColor: Colors.white,
          icon: Icons.info_outline,
        );
      }
      return;
    }
    if (requested == 'completed') {
      await _updateStatus('completed');
      return;
    }
    if (requested == 'rejected') {
      final merchantReason =
          (widget.data['merchant_status_request_reason'] ?? '')
              .toString()
              .trim();
      final merchantContact =
          (widget.data['merchant_status_request_contact_whatsapp'] ?? '')
              .toString()
              .trim();
      final reasonForUser = _composeMerchantRejectionReasonForUser(
        reason: merchantReason,
        merchantWhatsapp: merchantContact,
      );
      await _rejectOrderWithReason(
        presetReason: reasonForUser,
        requireReason: true,
      );
      return;
    }
    if (mounted) {
      TopSnackBar.show(
        context,
        "نوع الطلب غير مدعوم للمراجعة",
        backgroundColor: Colors.red,
        textColor: Colors.white,
        icon: Icons.error_outline,
      );
    }
  }

  // EN: Updates Status.
  // AR: تحدّث Status.
  Future<void> _updateStatus(String newStatus) async {
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

    setState(() => _isUpdating = true);
    try {
      final isPromoOrder =
          (widget.data['product_type'] ?? '').toString() == 'tiktok_promo';
      final requested = (widget.data['merchant_status_request'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final hasPendingMerchantRequest = _hasPendingMerchantStatusRequest(
        widget.data,
      );
      final merchantRequestDecision = hasPendingMerchantRequest
          ? (requested == newStatus ? 'approved' : 'declined')
          : null;
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.id)
          .update({
            'status': newStatus,
            if (newStatus == 'completed' && isPromoOrder) 'video_link': null,
            if (newStatus == 'completed' && isPromoOrder)
              'video_link_removed_at': FieldValue.serverTimestamp(),
            if (merchantRequestDecision case final decision) ...{
              'merchant_status_request_state': decision,
              'merchant_status_request_resolved_at':
                  FieldValue.serverTimestamp(),
              'merchant_status_request_resolved_by': 'admin',
            },
            'updated_at': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        setState(() {
          widget.data['status'] = newStatus;
          if (newStatus == 'completed' && isPromoOrder) {
            widget.data['video_link'] = null;
          }
          if (merchantRequestDecision != null) {
            widget.data['merchant_status_request_state'] =
                merchantRequestDecision;
          }
        });
        final userWhatsapp = _orderUserWhatsapp(widget.data);
        if (userWhatsapp.isNotEmpty) {
          unawaited(
            CloudflareNotifyService.notifyUserOrderStatus(
              userWhatsapp: userWhatsapp,
              orderId: widget.id,
              status: newStatus,
            ),
          );
        }
        if (newStatus == 'processing') {
          unawaited(
            OrderChatService.addSystemMessage(
              orderId: widget.id,
              text: "بدأ تنفيذ الطلب. الشات مفتوح بين المستخدم والدعم.",
            ),
          );
        }
        if (merchantRequestDecision == 'approved') {
          final requestLabel = _merchantRequestedStatusLabel(requested);
          unawaited(
            OrderChatService.addSystemMessage(
              orderId: widget.id,
              text: 'الأدمن وافق على طلب التاجر: "$requestLabel".',
            ),
          );
        } else if (merchantRequestDecision == 'declined') {
          final requestLabel = _merchantRequestedStatusLabel(requested);
          unawaited(
            OrderChatService.addSystemMessage(
              orderId: widget.id,
              text: 'الأدمن رفض طلب التاجر: "$requestLabel".',
            ),
          );
        }
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

  Future<void> _markOrderAsProcessingAndClearLegacyDelivery() async {
    await FirebaseFirestore.instance.collection('orders').doc(widget.id).set({
      'status': 'processing',
      'updated_at': FieldValue.serverTimestamp(),
      'delivery_link': null,
      'delivery_qr_url': null,
      'delivery_qr_path': null,
      'delivery_expires_at': null,
      'delivery_expired_at': null,
      'delivery_refresh_requested_at': null,
      'delivery_refresh_requested_by': null,
    }, SetOptions(merge: true));
  }

  Future<void> _notifyUserProcessingStatus() async {
    final userWhatsapp = _orderUserWhatsapp(widget.data);
    if (userWhatsapp.isEmpty) return;
    unawaited(
      CloudflareNotifyService.notifyUserOrderStatus(
        userWhatsapp: userWhatsapp,
        orderId: widget.id,
        status: 'processing',
      ),
    );
  }

  Future<void> _sendDeliveryLoginLinkViaChat() async {
    if (_isFinalStatus) {
      if (mounted) {
        TopSnackBar.show(
          context,
          "لا يمكن تعديل بيانات طلب مكتمل أو مرفوض",
          backgroundColor: Colors.red,
          textColor: Colors.white,
          icon: Icons.block,
        );
      }
      return;
    }

    final linkCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        title: const Text(
          'إرسال لينك تسجيل الدخول',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: linkCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'الرابط',
                hintText: 'https://...',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              maxLines: 2,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            onPressed: () {
              final value = linkCtrl.text.trim();
              if (value.isEmpty) return;
              Navigator.pop(ctx, (value, noteCtrl.text.trim()));
            },
            child: const Text("إرسال"),
          ),
        ],
      ),
    );

    if (!mounted || result == null) return;

    final safeLink = ensureHttps(result.$1);
    final note = result.$2;
    setState(() => _isUpdating = true);
    try {
      await OrderChatService.addMessage(
        orderId: widget.id,
        senderRole: 'admin',
        senderName: '',
        text: note,
        attachmentType: 'link',
        attachmentUrl: safeLink,
        attachmentLabel: 'لينك تسجيل الدخول',
        attachmentExpiresAt: _newDeliveryExpiryTimestamp(),
        recipientUserWhatsapp: _orderUserWhatsapp(widget.data),
      );
      await _markOrderAsProcessingAndClearLegacyDelivery();
      await _notifyUserProcessingStatus();
      if (!mounted) return;
      setState(() {
        _isUpdating = false;
        widget.data['status'] = 'processing';
      });
      TopSnackBar.show(
        context,
        "تم إرسال لينك تسجيل الدخول داخل الشات ✅",
        backgroundColor: Colors.green,
        textColor: Colors.white,
        icon: Icons.check_circle,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUpdating = false);
      TopSnackBar.show(
        context,
        "حدث خطأ أثناء إرسال الرابط",
        backgroundColor: Colors.red,
        textColor: Colors.white,
        icon: Icons.error_outline,
      );
      debugPrint('send delivery login link via chat failed: $e');
    }
  }

  Future<void> _sendDeliveryQrViaChat() async {
    if (_isFinalStatus) {
      if (mounted) {
        TopSnackBar.show(
          context,
          "لا يمكن تعديل بيانات طلب مكتمل أو مرفوض",
          backgroundColor: Colors.red,
          textColor: Colors.white,
          icon: Icons.block,
        );
      }
      return;
    }

    final bytes = await _pickQrImageBytes();
    if (bytes == null || !mounted) return;

    bool confirm = false;
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.memory(bytes, height: 200, fit: BoxFit.contain),
            const SizedBox(height: 10),
            const Text("إرسال صورة QR داخل الشات؟"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("تغيير"),
          ),
          ElevatedButton(
            onPressed: () {
              confirm = true;
              Navigator.pop(ctx);
            },
            child: const Text("إرسال"),
          ),
        ],
      ),
    );
    if (!confirm || !mounted) return;

    setState(() => _isUpdating = true);
    try {
      final uploadRes = await ReceiptStorageService.uploadWithPath(
        bytes: bytes,
        whatsapp: _orderUserWhatsapp(widget.data),
        orderId:
            'chat_qr_${widget.id}_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (uploadRes == null) {
        if (!mounted) return;
        setState(() => _isUpdating = false);
        TopSnackBar.show(
          context,
          "فشل رفع صورة QR",
          backgroundColor: Colors.red,
          textColor: Colors.white,
          icon: Icons.error,
        );
        return;
      }

      await OrderChatService.addMessage(
        orderId: widget.id,
        senderRole: 'admin',
        senderName: '',
        text: 'QR تسجيل الدخول',
        attachmentType: 'image',
        attachmentUrl: uploadRes.url,
        attachmentPath: uploadRes.path,
        attachmentLabel: 'QR تسجيل الدخول',
        attachmentExpiresAt: _newDeliveryExpiryTimestamp(),
        recipientUserWhatsapp: _orderUserWhatsapp(widget.data),
      );
      await _markOrderAsProcessingAndClearLegacyDelivery();
      await _notifyUserProcessingStatus();
      if (!mounted) return;
      setState(() {
        _isUpdating = false;
        widget.data['status'] = 'processing';
      });
      TopSnackBar.show(
        context,
        "تم إرسال QR داخل الشات ✅",
        backgroundColor: Colors.green,
        textColor: Colors.white,
        icon: Icons.qr_code_2,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUpdating = false);
      TopSnackBar.show(
        context,
        "حدث خطأ أثناء إرسال QR",
        backgroundColor: Colors.red,
        textColor: Colors.white,
        icon: Icons.error_outline,
      );
      debugPrint('send delivery qr via chat failed: $e');
    }
  }

  Future<_QrImageSourceOption?> _promptQrImageSource() {
    return showDialog<_QrImageSourceOption>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        title: const Text(
          'مصدر صورة QR',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text(
                'التقاط بالكاميرا',
                style: TextStyle(fontFamily: 'Cairo'),
              ),
              onTap: () => Navigator.pop(ctx, _QrImageSourceOption.camera),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_rounded),
              title: const Text(
                'اختيار من الملفات',
                style: TextStyle(fontFamily: 'Cairo'),
              ),
              onTap: () => Navigator.pop(ctx, _QrImageSourceOption.files),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }

  Future<Uint8List?> _pickQrImageBytes() async {
    final source = _cameraCaptureSupported
        ? await _promptQrImageSource()
        : _QrImageSourceOption.files;
    if (source == null) return null;

    if (source == _QrImageSourceOption.camera) {
      try {
        final picked = await _imagePicker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.rear,
          imageQuality: 95,
          maxWidth: 2200,
        );
        if (picked == null) return null;
        final bytes = await picked.readAsBytes();
        if (bytes.isEmpty) {
          if (!mounted) return null;
          TopSnackBar.show(
            context,
            "تعذر قراءة الصورة الملتقطة",
            backgroundColor: Colors.red,
            textColor: Colors.white,
            icon: Icons.error,
          );
          return null;
        }
        return bytes;
      } catch (e) {
        if (!mounted) return null;
        TopSnackBar.show(
          context,
          "تعذر فتح الكاميرا الآن",
          backgroundColor: Colors.red,
          textColor: Colors.white,
          icon: Icons.error_outline,
        );
        debugPrint('pick qr via camera failed: $e');
        return null;
      }
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp', 'heic'],
      withData: true,
      dialogTitle: 'اختر صورة QR من الملفات',
    );
    if (result == null || result.files.isEmpty) return null;

    final bytes = result.files.first.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return null;
      TopSnackBar.show(
        context,
        "تعذر قراءة الصورة، حاول صورة أخرى",
        backgroundColor: Colors.red,
        textColor: Colors.white,
        icon: Icons.error,
      );
      return null;
    }
    return bytes;
  }

  Future<String?> _promptRejectReason() async {
    String value = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        title: const Text("سبب الرفض (اختياري)"),
        content: TextField(
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          onChanged: (v) => value = v,
          decoration: const InputDecoration(
            labelText: "اكتب سبب الرفض للعميل (اختياري)",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, value.trim()),
            child: const Text("رفض الطلب"),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectOrderWithReason({
    String? presetReason,
    bool requireReason = false,
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

    var reason = (presetReason ?? '').trim();
    if (reason.isEmpty) {
      final promptedReason = await _promptRejectReason();
      if (!mounted || promptedReason == null) return;
      reason = promptedReason.trim();
    }
    if (requireReason && reason.isEmpty) {
      if (mounted) {
        TopSnackBar.show(
          context,
          "سبب الرفض مطلوب قبل اعتماد الرفض",
          backgroundColor: Colors.orange,
          textColor: Colors.white,
          icon: Icons.info_outline,
        );
      }
      return;
    }

    setState(() => _isUpdating = true);
    try {
      final orderRef = FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.id);
      final latestOrderSnap = await orderRef.get(
        const GetOptions(source: Source.server),
      );
      final latestOrderData = latestOrderSnap.data() ?? widget.data;
      final userRef = await _resolveOrderUserRef(latestOrderData);

      int refundedNow = 0;
      int pointsUsed = 0;
      bool alreadyRefunded = false;
      String merchantRequestDecision = '';
      String merchantRequestedStatus = '';

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final orderSnap = await tx.get(orderRef);
        final orderData = orderSnap.data() ?? latestOrderData;
        final status = (orderData['status'] ?? '').toString();
        final isPromoOrder =
            (orderData['product_type'] ?? '').toString() == 'tiktok_promo';
        if (status == 'completed' || status == 'cancelled') {
          throw StateError('final-status');
        }
        if (status == 'rejected') {
          throw StateError('already-rejected');
        }

        pointsUsed = _extractPointsUsed(orderData);
        alreadyRefunded = orderData['points_refunded'] == true;
        merchantRequestedStatus = (orderData['merchant_status_request'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final hasPendingMerchantRequest = _hasPendingMerchantStatusRequest(
          orderData,
        );
        if (hasPendingMerchantRequest) {
          merchantRequestDecision = merchantRequestedStatus == 'rejected'
              ? 'approved'
              : 'declined';
        }

        final uid = (orderData['user_uid'] ?? orderData['uid'] ?? '')
            .toString()
            .trim();
        final whatsappRaw =
            (orderData['user_whatsapp'] ?? orderData['whatsapp'] ?? '')
                .toString()
                .trim();
        final whatsapp = _normalizeWhatsapp(whatsappRaw);

        if (pointsUsed > 0 && !alreadyRefunded) {
          if (userRef == null) {
            throw StateError('user-not-found');
          }
          final userSnap = await tx.get(userRef);
          final currentBalance = _parseIntValue(
            userSnap.data()?['balance_points'],
          );

          tx.set(userRef, {
            'balance_points': currentBalance + pointsUsed,
            if (uid.isNotEmpty) 'uid': uid,
            if (whatsappRaw.isNotEmpty)
              'whatsapp': whatsappRaw
            else if (whatsapp.isNotEmpty)
              'whatsapp': whatsapp,
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          refundedNow = pointsUsed;
        }

        tx.set(orderRef, {
          'status': 'rejected',
          'rejection_reason': reason,
          'rejected_at': FieldValue.serverTimestamp(),
          if (isPromoOrder) 'video_link': null,
          if (isPromoOrder)
            'video_link_removed_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
          if (merchantRequestDecision.isNotEmpty)
            'merchant_status_request_state': merchantRequestDecision,
          if (merchantRequestDecision.isNotEmpty)
            'merchant_status_request_resolved_at': FieldValue.serverTimestamp(),
          if (merchantRequestDecision.isNotEmpty)
            'merchant_status_request_resolved_by': 'admin',
          if (pointsUsed > 0) 'points_refunded': true,
          if (pointsUsed > 0 && !alreadyRefunded)
            'points_refunded_at': FieldValue.serverTimestamp(),
          if (pointsUsed > 0 && !alreadyRefunded)
            'points_refunded_value': pointsUsed,
        }, SetOptions(merge: true));
      });

      if (!mounted) return;
      setState(() {
        _isUpdating = false;
        widget.data['status'] = 'rejected';
        widget.data['rejection_reason'] = reason;
        if ((latestOrderData['product_type'] ?? '').toString() ==
            'tiktok_promo') {
          widget.data['video_link'] = null;
        }
        if (pointsUsed > 0) {
          widget.data['points_refunded'] = true;
        }
        if (refundedNow > 0) {
          widget.data['points_refunded_value'] = refundedNow;
        }
        if (merchantRequestDecision.isNotEmpty) {
          widget.data['merchant_status_request_state'] =
              merchantRequestDecision;
        }
      });
      final userWhatsapp = _orderUserWhatsapp(latestOrderData);
      if (userWhatsapp.isNotEmpty) {
        unawaited(
          CloudflareNotifyService.notifyUserOrderStatus(
            userWhatsapp: userWhatsapp,
            orderId: widget.id,
            status: 'rejected',
            rejectionReason: reason,
          ),
        );
      }
      if (merchantRequestDecision == 'approved') {
        final requestLabel = _merchantRequestedStatusLabel(
          merchantRequestedStatus,
        );
        unawaited(
          OrderChatService.addSystemMessage(
            orderId: widget.id,
            text: 'الأدمن وافق على طلب التاجر: "$requestLabel".',
          ),
        );
      } else if (merchantRequestDecision == 'declined') {
        final requestLabel = _merchantRequestedStatusLabel(
          merchantRequestedStatus,
        );
        unawaited(
          OrderChatService.addSystemMessage(
            orderId: widget.id,
            text: 'الأدمن رفض طلب التاجر: "$requestLabel".',
          ),
        );
      }
      final String message;
      final Color bgColor;
      final IconData icon;
      if (refundedNow > 0) {
        message = "تم رفض الطلب وإعادة $refundedNow نقطة للمستخدم";
        bgColor = Colors.green;
        icon = Icons.check_circle;
      } else if (pointsUsed > 0 && alreadyRefunded) {
        message = "تم رفض الطلب. النقاط كانت مستردة مسبقًا";
        bgColor = Colors.orange;
        icon = Icons.info_outline;
      } else {
        message = reason.isEmpty
            ? "تم رفض الطلب"
            : "تم رفض الطلب وإرسال السبب للعميل";
        bgColor = Colors.red;
        icon = Icons.info_outline;
      }

      TopSnackBar.show(
        context,
        message,
        backgroundColor: bgColor,
        textColor: Colors.white,
        icon: icon,
      );
    } on StateError catch (e) {
      if (!mounted) return;
      setState(() => _isUpdating = false);
      String message = "تعذر رفض الطلب";
      if (e.message == 'user-not-found') {
        message = "تعذر العثور على حساب المستخدم لاسترجاع النقاط";
      } else if (e.message == 'final-status') {
        message = "لا يمكن رفض طلب مكتمل أو ملغي";
      } else if (e.message == 'already-rejected') {
        message = "الطلب مرفوض بالفعل";
      }
      TopSnackBar.show(
        context,
        message,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        icon: Icons.error,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isUpdating = false);
      TopSnackBar.show(
        context,
        "حدث خطأ أثناء رفض الطلب",
        backgroundColor: Colors.red,
        textColor: Colors.white,
        icon: Icons.error_outline,
      );
    }
  }

  // EN: Builds widget UI.
  // AR: تبني واجهة الودجت.
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = (widget.data['status'] ?? 'unknown').toString();
    final bool isFinalStatus = _isFinalStatus;
    final String method = (widget.data['method'] ?? '').toString();
    final bool isBinanceMethod = method == 'Binance Pay';
    final bool isPointsMethod = method == 'Points';
    final String productType = (widget.data['product_type'] ?? 'tiktok')
        .toString();
    final bool isGameOrder = productType == 'game';
    final bool isPromoOrder = productType == 'tiktok_promo';
    final bool supportsOrderChat = _isChatSupportedOrderType(productType);
    final bool shouldShowChatSection = supportsOrderChat && !isFinalStatus;
    final bool isExecutionChatOpen = _isExecutionChatOpen(status);
    final String egpPriceText = (widget.data['price'] ?? '').toString().trim();
    final String originalEgpPriceText =
        (widget.data['original_price'] ?? widget.data['price'] ?? '')
            .toString()
            .trim();
    String usdtAmountText = '';
    if (isBinanceMethod) {
      final directUsdt = (widget.data['usdt_amount'] ?? '').toString().trim();
      if (directUsdt.isNotEmpty) {
        usdtAmountText = directUsdt;
      } else {
        final double? egpAmount = double.tryParse(egpPriceText);
        final dynamic usdtRateRaw = widget.data['usdt_price'];
        double? usdtRate;
        if (usdtRateRaw is num) {
          usdtRate = usdtRateRaw.toDouble();
        } else if (usdtRateRaw is String) {
          usdtRate = double.tryParse(usdtRateRaw.trim());
        }
        if (egpAmount != null && usdtRate != null && usdtRate > 0) {
          usdtAmountText = (egpAmount / usdtRate).toStringAsFixed(2);
        }
      }
    }

    String compactAmount(String raw) {
      final value = double.tryParse(raw.trim());
      if (value == null) return raw.trim();
      if (value == value.roundToDouble()) return value.toStringAsFixed(0);
      if ((value * 10) == (value * 10).roundToDouble()) {
        return value.toStringAsFixed(1);
      }
      return value.toStringAsFixed(2);
    }

    int parseIntValue(dynamic raw) {
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return int.tryParse((raw ?? '').toString().trim()) ?? 0;
    }

    final String egpDisplay = "${compactAmount(egpPriceText)} L.E";
    final String usdtDisplay = compactAmount(usdtAmountText);
    final String displayPriceText = isPointsMethod
        ? "💰 ${compactAmount(originalEgpPriceText)} L.E (مدفوع بالنقاط)"
        : isBinanceMethod && usdtAmountText.isNotEmpty
        ? "💰 $usdtDisplay USDT"
        : "💰 $egpDisplay";
    final int pointsDiscount = parseIntValue(widget.data['points_discount']);
    final int pointsPaid = parseIntValue(widget.data['points_paid']);
    final String gameKey = (widget.data['game'] ?? '').toString();
    final String packageLabel = (widget.data['package_label'] ?? '').toString();
    final String gameId = (widget.data['game_id'] ?? '').toString();
    final String promoVideoLink = (widget.data['video_link'] ?? '').toString();
    final String tiktokUser =
        (widget.data['user_tiktok'] ??
                widget.data['tiktok_user'] ??
                widget.data['tiktok'] ??
                '')
            .toString()
            .trim();
    final String tiktokPassword = (widget.data['tiktok_password'] ?? '')
        .toString()
        .trim();
    final String tiktokChargeMode = (widget.data['tiktok_charge_mode'] ?? '')
        .toString()
        .trim();
    final String rejectionReason = (widget.data['rejection_reason'] ?? '')
        .toString()
        .trim();
    final String merchantRequestedStatus =
        (widget.data['merchant_status_request'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
    final bool hasPendingMerchantStatusRequest =
        _hasPendingMerchantStatusRequest(widget.data);
    final String merchantRequestedStatusLabel = _merchantRequestedStatusLabel(
      merchantRequestedStatus,
    );
    final String merchantRequestedReason =
        (widget.data['merchant_status_request_reason'] ?? '').toString().trim();
    final String merchantRequestedContact = _normalizeWhatsapp(
      (widget.data['merchant_status_request_contact_whatsapp'] ?? '')
          .toString()
          .trim(),
    );
    final String tiktokChargeModeLabel = tiktokChargeMode == 'username_password'
        ? 'يوزر + باسورد'
        : tiktokChargeMode == 'qr'
        ? 'QR'
        : tiktokChargeMode == 'link'
        ? 'لينك'
        : '';
    final String userDisplayName = (widget.data['name'] ?? '')
        .toString()
        .trim();
    final statusColor = OrderStatusHelper.color(status);
    final statusTextColor =
        ThemeData.estimateBrightnessForColor(statusColor) == Brightness.dark
        ? Colors.white
        : Colors.black;
    final String leftText = isGameOrder
        ? "🎮 ${GamePackage.gameLabel(gameKey)} - $packageLabel"
        : (isPromoOrder ? "📣 ترويج فيديو" : "💎 ${widget.data['points']}");

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      borderColor: statusColor.withAlpha(128),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.data['name'] ?? 'بدون اسم',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    overflow: TextOverflow.ellipsis,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  OrderStatusHelper.label(status),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: statusTextColor,
                  ),
                ),
              ),
            ],
          ),

          Divider(color: Theme.of(context).dividerColor),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text(
                leftText,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),

              Text(
                displayPriceText,
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            "طريقة الدفع: $method",
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
          ),

          if (pointsDiscount > 0) ...[
            const SizedBox(height: 6),
            Text(
              "خصم من رصيد النقاط: $pointsDiscount نقطة",
              style: TextStyle(
                color: TTColors.goldAccent,
                fontFamily: 'Cairo',
                fontSize: 12,
              ),
            ),
          ],

          if (method == "Points" || pointsPaid > 0) ...[
            const SizedBox(height: 6),
            Text(
              "دفع من رصيد النقاط: ${pointsPaid > 0 ? pointsPaid : '-'} نقطة",
              style: TextStyle(
                color: TTColors.goldAccent,
                fontFamily: 'Cairo',
                fontSize: 12,
              ),
            ),
          ],

          if (status == 'rejected' && rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withAlpha(90)),
              ),
              child: Text(
                "سبب الرفض: $rejectionReason",
                style: TextStyle(
                  color: colorScheme.error,
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],

          if (!isGameOrder && !isPromoOrder) ...[
            if (tiktokChargeModeLabel.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                "طريقة شحن تيك توك: $tiktokChargeModeLabel",
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    "حساب تيك توك: ${tiktokUser.isEmpty ? '-' : tiktokUser}",
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: tiktokUser.isEmpty
                      ? null
                      : () {
                          Clipboard.setData(ClipboardData(text: tiktokUser));
                          TopSnackBar.show(
                            this.context,
                            "تم نسخ حساب تيك توك",
                            backgroundColor: colorScheme.surface,
                            textColor: colorScheme.onSurface,
                            icon: Icons.check_circle,
                          );
                        },
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: "نسخ حساب تيك توك",
                ),
              ],
            ),
            if (tiktokPassword.isNotEmpty)
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      _showTiktokPassword
                          ? "باسورد تيك توك: $tiktokPassword"
                          : "باسورد تيك توك: ••••••••",
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _showTiktokPassword = !_showTiktokPassword;
                      });
                    },
                    icon: Icon(
                      _showTiktokPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      size: 18,
                    ),
                    tooltip: _showTiktokPassword
                        ? "إخفاء الباسورد"
                        : "إظهار الباسورد",
                  ),
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
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: gameId));
                    TopSnackBar.show(
                      this.context,
                      "تم نسخ الـ ID",
                      backgroundColor: Colors.green,
                      textColor: Colors.white,
                      icon: Icons.check_circle,
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: "نسخ ID",
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
                    "رابط الفيديو: $promoVideoLink",
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: promoVideoLink));
                    TopSnackBar.show(
                      this.context,
                      "تم نسخ رابط الفيديو",
                      backgroundColor: colorScheme.surface,
                      textColor: colorScheme.onSurface,
                      icon: Icons.check_circle,
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: "نسخ رابط الفيديو",
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
                  tooltip: "فتح رابط الفيديو",
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),

          if (!isFinalStatus) ...[
            if (!isGameOrder && !isPromoOrder) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _sendDeliveryLoginLinkViaChat,
                  icon: const Icon(Icons.link),
                  label: const Text(
                    "إرسال لينك تسجيل الدخول داخل الشات",
                    style: TextStyle(fontFamily: 'Cairo'),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (!isGameOrder && !isPromoOrder) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _sendDeliveryQrViaChat,
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text(
                    "إرسال QR داخل الشات",
                    style: TextStyle(fontFamily: 'Cairo'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],

          if (shouldShowChatSection) ...[
            OrderChatPanel(
              orderId: widget.id,
              isAdmin: true,
              userDisplayName: userDisplayName,
              userWhatsapp: _orderUserWhatsapp(widget.data),
              adminDisplayName: 'الدعم',
              chatEnabled: isExecutionChatOpen,
              disabledHint: _chatDisabledHint(
                status: status,
                supportsChat: supportsOrderChat,
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (hasPendingMerchantStatusRequest && !isFinalStatus) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(32),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withAlpha(120)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'طلب تاجر قيد المراجعة: "$merchantRequestedStatusLabel".',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (merchantRequestedStatus == 'rejected' &&
                      merchantRequestedReason.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'سبب الرفض المقترح: $merchantRequestedReason',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                  if (merchantRequestedStatus == 'rejected' &&
                      merchantRequestedContact.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'رقم تواصل التاجر: $merchantRequestedContact',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _approveMerchantStatusRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text(
                      "موافقة على طلب التاجر",
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _declineMerchantStatusRequest,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      side: BorderSide(color: colorScheme.error),
                    ),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text(
                      "رفض طلب التاجر",
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          Builder(
            builder: (_) {
              if (_isUpdating) {
                return const CircularProgressIndicator();
              }

              if (isFinalStatus) {
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
                    if (status == 'rejected' && rejectionReason.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        "سبب الرفض: $rejectionReason",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colorScheme.error,
                          fontSize: 12,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _updateStatus("processing"),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 50),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text("جاري التنفيذ", maxLines: 1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _updateStatus("completed"),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 50),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text("مكتمل", maxLines: 1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _rejectOrderWithReason,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 50),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        backgroundColor: colorScheme.error,
                        foregroundColor: colorScheme.onError,
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text("مرفوض", maxLines: 1),
                      ),
                    ),
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
