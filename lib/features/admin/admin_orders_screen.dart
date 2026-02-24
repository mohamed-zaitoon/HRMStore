// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;
import 'dart:async';

import '../../core/order_status.dart';
import '../../core/tt_colors.dart';
import '../../services/admin_session_service.dart';
import '../../services/cloudflare_notify_service.dart';
import '../../services/notification_service.dart';
import '../../services/receipt_storage_service.dart';
import '../../models/game_package.dart';
import '../../widgets/theme_mode_sheet.dart';
import '../../widgets/top_snackbar.dart';
import '../../widgets/glass_bottom_sheet.dart';
import '../../widgets/glass_app_bar.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/snow_background.dart';
import '../../utils/url_sanitizer.dart';
import 'admin_devices_screen.dart';

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

  // EN: Initializes widget state.
  // AR: تهيّئ حالة الودجت.
  @override
  void initState() {
    super.initState();
    NotificationService.requestPermission();
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
      await NotificationService.disposeListeners();
      await NotificationService.pushLogout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/admin', (route) => false);
      return;
    }

    NotificationService.listenToAdminOrders();
    NotificationService.listenToAdminRamadanCodes();
    if (session.whatsapp.trim().isNotEmpty) {
      await NotificationService.initAdminNotifications(session.whatsapp);
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
        .orderBy('created_at', descending: true);
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
    await NotificationService.disposeListeners();
    await NotificationService.pushLogout();
    await AdminSessionService.clearLocalSession();

    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/admin', (route) => false);
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

    Navigator.push(
      context,

      MaterialPageRoute(builder: (_) => AdminDevicesScreen(adminId: adminId)),
    );
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
                    Navigator.pushNamed(context, '/admin/requests');
                  },
                ),

                _menuTile(
                  icon: Icons.confirmation_number,
                  title: "إدارة الأكواد",
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, '/admin/codes');
                  },
                ),

                _menuTile(
                  icon: Icons.price_change,
                  title: "تعديل الأسعار",
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, '/admin/prices');
                  },
                ),

                _menuTile(
                  icon: Icons.local_offer,
                  title: "عروض الأسعار",
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, '/admin/offers');
                  },
                ),

                _menuTile(
                  icon: Icons.calculate,
                  title: "حاسبة التكلفة اليدوية",
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, '/admin/cost-calculator');
                  },
                ),

                _menuTile(
                  icon: Icons.games,
                  title: "شحن الألعاب",
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, '/admin/games');
                  },
                ),

                _menuTile(
                  icon: Icons.people_alt,
                  title: "بيانات المستخدمين",
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, '/admin/users');
                  },
                ),

                _menuTile(
                  icon: Icons.schedule,
                  title: "مواعيد العمل / الصيانة",
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, '/admin/availability');
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
                  icon: Icons.account_balance_wallet,
                  title: "المحافظ",
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, '/admin/wallets');
                  },
                ),

                _menuTile(
                  icon: Theme.of(context).brightness == Brightness.dark
                      ? Icons.wb_sunny_rounded
                      : Icons.nightlight_round,
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
            Navigator.pushNamed(context, '/admin/requests');
          },
        ),

        IconButton(
          icon: Icon(Icons.confirmation_number, color: colorScheme.primary),
          tooltip: "إدارة الأكواد",
          onPressed: () {
            Navigator.pushNamed(context, '/admin/codes');
          },
        ),

        IconButton(
          icon: Icon(Icons.price_change, color: colorScheme.secondary),
          tooltip: "تعديل الأسعار",
          onPressed: () {
            Navigator.pushNamed(context, '/admin/prices');
          },
        ),

        IconButton(
          icon: Icon(Icons.local_offer, color: colorScheme.tertiary),
          tooltip: "عروض الأسعار",
          onPressed: () {
            Navigator.pushNamed(context, '/admin/offers');
          },
        ),

        IconButton(
          icon: Icon(Icons.calculate, color: colorScheme.primary),
          tooltip: "حاسبة التكلفة اليدوية",
          onPressed: () {
            Navigator.pushNamed(context, '/admin/cost-calculator');
          },
        ),

        IconButton(
          icon: Icon(Icons.devices, color: colorScheme.onSurface),
          tooltip: "الأجهزة المسجّل منها",
          onPressed: _openDevicesScreen,
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
                final docs = _statusFilter == 'all'
                    ? allDocs
                    : allDocs
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

                return RefreshIndicator(
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
  late TextEditingController _linkCtrl;
  late TextEditingController _walletCtrl;
  bool _isUpdating = false;
  bool _showTiktokPassword = false;

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

  int _parseIntValue(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse((raw ?? '').toString().trim()) ?? 0;
  }

  int _extractPointsUsed(Map<String, dynamic> orderData) {
    final direct = _parseIntValue(orderData['points_used_total']);
    if (direct > 0) return direct;
    final paid = _parseIntValue(orderData['points_paid']);
    final discount = _parseIntValue(orderData['points_discount']);
    final sum = paid + discount;
    return sum > 0 ? sum : 0;
  }

  Future<DocumentReference<Map<String, dynamic>>?> _resolveOrderUserRef(
    Map<String, dynamic> orderData,
  ) async {
    final users = FirebaseFirestore.instance.collection('users');
    final uid = (orderData['user_uid'] ?? orderData['uid'] ?? '')
        .toString()
        .trim();
    final whatsappRaw =
        (orderData['user_whatsapp'] ?? orderData['whatsapp'] ?? '')
            .toString()
            .trim();
    final whatsapp = _normalizeWhatsapp(whatsappRaw);

    if (uid.isNotEmpty) {
      final byId = users.doc(uid);
      final byIdSnap = await byId.get();
      if (byIdSnap.exists) return byId;

      final byUid = await users.where('uid', isEqualTo: uid).limit(1).get();
      if (byUid.docs.isNotEmpty) return byUid.docs.first.reference;
    }

    if (whatsappRaw.isNotEmpty) {
      final byRawField = await users
          .where('whatsapp', isEqualTo: whatsappRaw)
          .limit(1)
          .get();
      if (byRawField.docs.isNotEmpty) return byRawField.docs.first.reference;

      final byRawId = users.doc(whatsappRaw);
      final byRawIdSnap = await byRawId.get();
      if (byRawIdSnap.exists) return byRawId;
    }

    if (whatsapp.isNotEmpty && whatsapp != whatsappRaw) {
      final byField = await users
          .where('whatsapp', isEqualTo: whatsapp)
          .limit(1)
          .get();
      if (byField.docs.isNotEmpty) return byField.docs.first.reference;

      final byId = users.doc(whatsapp);
      final byIdSnap = await byId.get();
      if (byIdSnap.exists) return byId;
    }

    // fallback: أنشئ/استخدم مستنداً متوقعاً حتى لا نفقد إضافة الرصيد
    if (uid.isNotEmpty) return users.doc(uid);
    if (whatsappRaw.isNotEmpty) return users.doc(whatsappRaw);
    if (whatsapp.isNotEmpty) return users.doc(whatsapp);
    return null;
  }

  Future<int> _completeBalanceTopupOrder() async {
    final orderRef = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.id);
    final userRef = await _resolveOrderUserRef(widget.data);
    if (userRef == null) {
      throw StateError('user-not-found');
    }

    int creditedNow = 0;

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final orderSnap = await tx.get(orderRef);
      final orderData = orderSnap.data() ?? <String, dynamic>{};
      final status = (orderData['status'] ?? '').toString();
      final isBalanceTopupOrder =
          (orderData['product_type'] ?? '').toString() == 'balance_topup';
      final uid = (orderData['user_uid'] ?? orderData['uid'] ?? '')
          .toString()
          .trim();
      final whatsappRaw =
          (orderData['user_whatsapp'] ?? orderData['whatsapp'] ?? '')
              .toString()
              .trim();
      final whatsapp = _normalizeWhatsapp(whatsappRaw);
      if (!isBalanceTopupOrder) {
        throw StateError('not-balance-topup');
      }
      if (status == 'rejected' || status == 'cancelled') {
        throw StateError('final-status');
      }

      final int topupPoints = _parseIntValue(
        orderData['balance_points_requested'] ?? orderData['points'],
      );
      if (topupPoints <= 0) {
        throw StateError('invalid-topup-points');
      }

      final bool alreadyApplied = orderData['balance_points_applied'] == true;
      if (!alreadyApplied) {
        final userSnap = await tx.get(userRef);
        final currentBalance = _parseIntValue(
          userSnap.data()?['balance_points'],
        );
        tx.set(userRef, {
          'balance_points': currentBalance + topupPoints,
          if (uid.isNotEmpty) 'uid': uid,
          if (whatsappRaw.isNotEmpty)
            'whatsapp': whatsappRaw
          else if (whatsapp.isNotEmpty)
            'whatsapp': whatsapp,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        creditedNow = topupPoints;
      }

      tx.set(orderRef, {
        'status': 'completed',
        'balance_points_applied': true,
        if (!alreadyApplied)
          'balance_points_applied_at': FieldValue.serverTimestamp(),
        if (!alreadyApplied) 'balance_points_applied_value': topupPoints,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    return creditedNow;
  }

  // EN: Initializes widget state.
  // AR: تهيّئ حالة الودجت.
  @override
  void initState() {
    super.initState();
    _linkCtrl = TextEditingController(text: widget.data['delivery_link'] ?? '');
    _walletCtrl = TextEditingController(
      text: widget.data['wallet_number'] ?? '',
    );
  }

  // EN: Releases resources.
  // AR: تفرّغ الموارد.
  @override
  void dispose() {
    _linkCtrl.dispose();
    _walletCtrl.dispose();
    super.dispose();
  }

  // EN: Shows image dialog.
  // AR: تعرض نافذة الصورة.
  Future<void> _showImageDialog(String url, {required String title}) async {
    final safeUrl = ensureHttps(url);
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) {
        final size = MediaQuery.of(ctx).size;
        final colorScheme = Theme.of(ctx).colorScheme;
        return Dialog(
          backgroundColor: colorScheme.surface,
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 640,
              maxHeight: size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.image, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                        tooltip: "إغلاق",
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          safeUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value:
                                    loadingProgress.expectedTotalBytes == null
                                    ? null
                                    : loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Text(
                                "تعذر تحميل الصورة",
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
      final isBalanceTopupOrder =
          (widget.data['product_type'] ?? '').toString() == 'balance_topup';
      int creditedPoints = 0;

      if (newStatus == 'completed' && isBalanceTopupOrder) {
        creditedPoints = await _completeBalanceTopupOrder();
      } else {
        await FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.id)
            .update({
              'status': newStatus,
              'updated_at': FieldValue.serverTimestamp(),
            });
      }

      if (mounted) {
        setState(() {
          widget.data['status'] = newStatus;
          if (newStatus == 'completed' && isBalanceTopupOrder) {
            widget.data['balance_points_applied'] = true;
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
        if (newStatus == 'completed' && isBalanceTopupOrder) {
          TopSnackBar.show(
            context,
            creditedPoints > 0
                ? "تم إكمال الطلب وإضافة $creditedPoints نقطة للمستخدم ✅"
                : "تم إكمال الطلب ✅ (النقاط كانت مضافة مسبقًا)",
            backgroundColor: Colors.green,
            textColor: Colors.white,
            icon: Icons.check_circle,
          );
        }
      }
    } on StateError catch (e) {
      if (!mounted) return;
      String message = "تعذر تحديث حالة الطلب";
      if (e.message == 'user-not-found') {
        message = "تعذر العثور على حساب المستخدم لإضافة النقاط";
      } else if (e.message == 'invalid-topup-points') {
        message = "قيمة نقاط الشحن غير صالحة في هذا الطلب";
      } else if (e.message == 'final-status') {
        message = "لا يمكن إكمال طلب مرفوض أو ملغي";
      } else if (e.message == 'not-balance-topup') {
        message = "هذا الطلب ليس طلب شحن نقاط";
      }
      TopSnackBar.show(
        context,
        message,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        icon: Icons.error,
      );
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

  // EN: Saves Wallet.
  // AR: تحفظ Wallet.
  Future<void> _saveWallet() async {
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

    if (_walletCtrl.text.isEmpty) return;

    setState(() => _isUpdating = true);
    await FirebaseFirestore.instance.collection('orders').doc(widget.id).update(
      {'wallet_number': _walletCtrl.text.trim()},
    );

    if (mounted) {
      setState(() => _isUpdating = false);
      TopSnackBar.show(
        context,
        "تم تحديث رقم المحفظة ✅",
        backgroundColor: Colors.green,
        textColor: Colors.white,
        icon: Icons.check_circle,
      );
    }
  }

  // EN: Saves Link.
  // AR: تحفظ Link.
  Future<void> _saveLink() async {
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

    if (_linkCtrl.text.isEmpty) return;

    setState(() => _isUpdating = true);
    await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.id)
        .update({
          'delivery_link': _linkCtrl.text.trim(),
          'status': 'processing',
          'updated_at': FieldValue.serverTimestamp(),
        });
    final userWhatsapp = _orderUserWhatsapp(widget.data);
    if (userWhatsapp.isNotEmpty) {
      unawaited(
        CloudflareNotifyService.notifyUserOrderStatus(
          userWhatsapp: userWhatsapp,
          orderId: widget.id,
          status: 'processing',
        ),
      );
    }
    if (mounted) {
      setState(() => _isUpdating = false);
      TopSnackBar.show(
        context,
        "تم الحفظ وتحويل الحالة لجاري التنفيذ ✅",
        backgroundColor: Colors.green,
        textColor: Colors.white,
        icon: Icons.check_circle,
      );
    }
  }

  Future<void> _uploadDeliveryQr() async {
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

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp', 'heic'],
      withData: true,
      dialogTitle: 'اختر صورة QR من الملفات',
    );
    if (result == null || result.files.isEmpty) return;

    final Uint8List? bytes = result.files.first.bytes;
    if (bytes == null) {
      if (mounted) {
        TopSnackBar.show(
          context,
          "تعذر قراءة الصورة، حاول صورة أخرى",
          backgroundColor: Colors.red,
          textColor: Colors.white,
          icon: Icons.error,
        );
      }
      return;
    }

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
            const Text("إرسال صورة QR للمستخدم؟"),
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
      final oldPath = (widget.data['delivery_qr_path'] ?? '').toString().trim();
      final uploadRes = await ReceiptStorageService.uploadWithPath(
        bytes: bytes,
        whatsapp: _orderUserWhatsapp(widget.data),
        orderId: 'delivery_qr_${widget.id}',
      );

      if (uploadRes == null) {
        if (mounted) {
          setState(() => _isUpdating = false);
          TopSnackBar.show(
            context,
            "فشل رفع صورة QR",
            backgroundColor: Colors.red,
            textColor: Colors.white,
            icon: Icons.error,
          );
        }
        return;
      }

      await FirebaseFirestore.instance.collection('orders').doc(widget.id).set({
        'delivery_qr_url': uploadRes.url,
        'delivery_qr_path': uploadRes.path,
        'status': 'processing',
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      final userWhatsapp = _orderUserWhatsapp(widget.data);
      if (userWhatsapp.isNotEmpty) {
        unawaited(
          CloudflareNotifyService.notifyUserOrderStatus(
            userWhatsapp: userWhatsapp,
            orderId: widget.id,
            status: 'processing',
          ),
        );
      }
      if (oldPath.isNotEmpty && oldPath != uploadRes.path) {
        await ReceiptStorageService.deleteByPath(oldPath);
      }

      if (mounted) {
        setState(() => _isUpdating = false);
        TopSnackBar.show(
          context,
          "تم إرسال QR للمستخدم ✅",
          backgroundColor: Colors.green,
          textColor: Colors.white,
          icon: Icons.qr_code_2,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        TopSnackBar.show(
          context,
          "حدث خطأ أثناء إرسال QR",
          backgroundColor: Colors.red,
          textColor: Colors.white,
          icon: Icons.error_outline,
        );
      }
      debugPrint('upload delivery qr failed: $e');
    }
  }

  Future<String?> _promptRejectReason() async {
    String value = '';
    String? errorText;

    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(ctx).colorScheme.surface,
          title: const Text("سبب الرفض"),
          content: TextField(
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            onChanged: (v) => value = v,
            decoration: InputDecoration(
              labelText: "اكتب سبب الرفض للعميل",
              errorText: errorText,
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
              onPressed: () {
                final reason = value.trim();
                if (reason.isEmpty) {
                  setDialogState(() {
                    errorText = "اكتب سبب الرفض أولاً";
                  });
                  return;
                }
                Navigator.pop(ctx, reason);
              },
              child: const Text("رفض الطلب"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rejectOrderWithReason() async {
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

    final reason = await _promptRejectReason();
    if (!mounted || reason == null) return;

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

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final orderSnap = await tx.get(orderRef);
        final orderData = orderSnap.data() ?? latestOrderData;
        final status = (orderData['status'] ?? '').toString();
        if (status == 'completed' || status == 'cancelled') {
          throw StateError('final-status');
        }
        if (status == 'rejected') {
          throw StateError('already-rejected');
        }

        pointsUsed = _extractPointsUsed(orderData);
        alreadyRefunded = orderData['points_refunded'] == true;

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
          'updated_at': FieldValue.serverTimestamp(),
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
        if (pointsUsed > 0) {
          widget.data['points_refunded'] = true;
        }
        if (refundedNow > 0) {
          widget.data['points_refunded_value'] = refundedNow;
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
        message = "تم رفض الطلب وإرسال السبب للعميل";
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
    final status = widget.data['status'] ?? 'unknown';
    final bool isFinalStatus = _isFinalStatus;
    final receiptUrl = widget.data['receipt_url'];
    final String deliveryQrUrl = (widget.data['delivery_qr_url'] ?? '')
        .toString()
        .trim();
    final String method = (widget.data['method'] ?? '').toString();
    final bool isBinanceMethod = method == 'Binance Pay';
    final bool isPointsMethod = method == 'Points';
    final String productType = (widget.data['product_type'] ?? 'tiktok')
        .toString();
    final bool isGameOrder = productType == 'game';
    final bool isPromoOrder = productType == 'tiktok_promo';
    final bool isBalanceTopupOrder = productType == 'balance_topup';
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
    final int topupPoints = parseIntValue(
      widget.data['balance_points_requested'] ?? widget.data['points'],
    );
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
    final bool isQrChargeMode = tiktokChargeMode == 'qr';
    final String rejectionReason = (widget.data['rejection_reason'] ?? '')
        .toString()
        .trim();
    final String tiktokChargeModeLabel = tiktokChargeMode == 'username_password'
        ? 'يوزر + باسورد'
        : tiktokChargeMode == 'qr'
        ? 'QR'
        : tiktokChargeMode == 'link'
        ? 'لينك'
        : '';
    final statusColor = OrderStatusHelper.color(status);
    final statusTextColor =
        ThemeData.estimateBrightnessForColor(statusColor) == Brightness.dark
        ? Colors.white
        : Colors.black;
    final String leftText = isBalanceTopupOrder
        ? "💰 شحن الرصيد ${topupPoints > 0 ? '$topupPoints نقطة' : ''}"
        : isGameOrder
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

          if (isBalanceTopupOrder && topupPoints > 0) ...[
            const SizedBox(height: 6),
            Text(
              "المطلوب إضافته للرصيد بعد المراجعة: $topupPoints نقطة",
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
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

          if (!isGameOrder && !isPromoOrder && !isBalanceTopupOrder) ...[
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
                    "يوزر تيك توك: ${tiktokUser.isEmpty ? '-' : tiktokUser}",
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
                            "تم نسخ يوزر تيك توك",
                            backgroundColor: colorScheme.surface,
                            textColor: colorScheme.onSurface,
                            icon: Icons.check_circle,
                          );
                        },
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: "نسخ يوزر تيك توك",
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
            if (deliveryQrUrl.isNotEmpty) ...[
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text("عرض QR المرسل للمستخدم"),
                  onPressed: () =>
                      _showImageDialog(deliveryQrUrl, title: "QR الشحن"),
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

          if (receiptUrl != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.image),
                label: const Text("عرض صورة التحويل"),
                onPressed: () => _showImageDialog(
                  receiptUrl.toString(),
                  title: "صورة التحويل",
                ),
              ),
            )
          else if (method == "Points")
            Text(
              "تم الدفع من رصيد النقاط - لا يحتاج إيصال",
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            )
          else
            Text(
              "⚠️ العميل لم يرفع الإيصال",
              style: TextStyle(color: colorScheme.error),
            ),

          const SizedBox(height: 12),

          if (method == "Wallet") ...[
            TextField(
              controller: _walletCtrl,
              keyboardType: TextInputType.phone,
              readOnly: isFinalStatus,
              decoration: InputDecoration(
                labelText: "رقم المحفظة",
                prefixIcon: const Icon(Icons.account_balance_wallet),
                suffixIcon: isFinalStatus
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.save),
                        onPressed: _saveWallet,
                      ),
              ),
            ),

            const SizedBox(height: 10),
          ],

          if (!isGameOrder && !isPromoOrder && !isBalanceTopupOrder) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isFinalStatus ? null : _uploadDeliveryQr,
                icon: const Icon(Icons.qr_code_2),
                label: Text(
                  deliveryQrUrl.isEmpty
                      ? "رفع QR وإرساله للمستخدم"
                      : "تحديث صورة QR",
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          if (!isBalanceTopupOrder) ...[
            TextField(
              controller: _linkCtrl,
              readOnly: isFinalStatus,
              decoration: InputDecoration(
                labelText: isPromoOrder
                    ? "رابط فيديو الترويج"
                    : (isQrChargeMode
                          ? "رابط الشحن (اختياري مع QR)"
                          : "رابط الشحن"),
                prefixIcon: const Icon(Icons.link),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.copy),
                      tooltip: "نسخ الرابط",
                      onPressed: _linkCtrl.text.trim().isEmpty
                          ? null
                          : () {
                              Clipboard.setData(
                                ClipboardData(text: _linkCtrl.text.trim()),
                              );
                              TopSnackBar.show(
                                this.context,
                                "تم نسخ الرابط",
                                backgroundColor: colorScheme.surface,
                                textColor: colorScheme.onSurface,
                                icon: Icons.check_circle,
                              );
                            },
                    ),
                    if (!isFinalStatus)
                      IconButton(
                        icon: const Icon(Icons.save),
                        onPressed: _saveLink,
                      ),
                  ],
                ),
              ),
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
