// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;
import 'dart:async';

import '../../core/order_status.dart';
import '../../core/tt_colors.dart';
import '../../services/admin_session_service.dart';
import '../../services/onesignal_service.dart';
import '../../models/game_package.dart';
import '../../widgets/theme_mode_sheet.dart';
import '../../widgets/top_snackbar.dart';
import '../../widgets/glass_bottom_sheet.dart';
import '../../widgets/glass_app_bar.dart';
import '../../widgets/glass_card.dart';
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
  int _refreshToken = 0;
  Timer? _autoRefreshTimer;

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
    OneSignalService.requestPermission();
    _menuIconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _autoRefreshTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => setState(() {
              _refreshToken++;
            }));
  }

  // EN: Releases resources.
  // AR: تفرّغ الموارد.
  @override
  void dispose() {
    _menuIconController.dispose();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  // EN: Handles logout Admin.
  // AR: تتعامل مع logout Admin.
  Future<void> _logoutAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    final adminId = prefs.getString('admin_id');

    if (adminId != null && adminId.isNotEmpty) {
      await AdminSessionService.logoutCurrentDevice(adminId);
    }

    await OneSignalService.logout();
    await prefs.clear();

    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/admin', (route) => false);
    }
  }

  // EN: Opens Devices Screen.
  // AR: تفتح Devices Screen.
  Future<void> _openDevicesScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final adminId = prefs.getString('admin_id');

    if (adminId == null || adminId.isEmpty) {
      if (!mounted) return;
      TopSnackBar.show(
        context,
        "لم يتم العثور على هوية الأدمن (admin_id)",
        backgroundColor: Colors.red,
        textColor: Colors.white,
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
      barrierColor: Colors.black54,
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
                  icon: Icons.brightness_6,
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
      leading: Icon(icon, color: TTColors.primaryCyan),
      title: Text(title, style: const TextStyle(fontFamily: 'Cairo')),
      onTap: onTap,
    );
  }

  // EN: Builds Mobile App Bar.
  // AR: تبني Mobile App Bar.
  PreferredSizeWidget _buildMobileAppBar() {
    return GlassAppBar(
      automaticallyImplyLeading: false,
      leading: IconButton(
        icon: const Icon(Icons.logout, color: Colors.redAccent),
        tooltip: "خروج نهائي",
        onPressed: _logoutAdmin,
      ),
      title: const Text('طلبات الشحن 📦'),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.devices, color: Colors.cyanAccent),
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
    return GlassAppBar(
      title: const Text('طلبات الشحن 📦'),
      automaticallyImplyLeading: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.card_giftcard, color: TTColors.goldAccent),
          tooltip: "طلبات أكواد المستخدمين",
          onPressed: () {
            Navigator.pushNamed(context, '/admin/requests');
          },
        ),

        IconButton(
          icon: const Icon(Icons.confirmation_number, color: Colors.cyanAccent),
          tooltip: "إدارة الأكواد",
          onPressed: () {
            Navigator.pushNamed(context, '/admin/codes');
          },
        ),

        IconButton(
          icon: const Icon(Icons.price_change, color: Colors.orangeAccent),
          tooltip: "تعديل الأسعار",
          onPressed: () {
            Navigator.pushNamed(context, '/admin/prices');
          },
        ),

        IconButton(
          icon: Icon(Icons.devices, color: TTColors.textWhite),
          tooltip: "الأجهزة المسجّل منها",
          onPressed: _openDevicesScreen,
        ),

        IconButton(
          icon: const Icon(Icons.logout, color: Colors.redAccent),
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
    final bool isSmallMobile = MediaQuery.of(context).size.width < 800;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (!kIsWeb) SystemNavigator.pop();
      },
      child: Scaffold(
        appBar: isSmallMobile ? _buildMobileAppBar() : _buildWebAppBar(),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .orderBy('created_at', descending: true)
              .snapshots(),
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

            final filteredDocs = s.data!.docs.where((doc) {
              if (_statusFilter == 'all') return true;
              final data = doc.data() as Map<String, dynamic>;
              return data['status'] == _statusFilter;
            }).toList();

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
                        selectedColor: TTColors.primaryCyan.withAlpha(120),
                        onSelected: (_) {
                          setState(() => _statusFilter = status);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              if (filteredDocs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text("لا توجد طلبات شحن")),
                )
              else
                ...filteredDocs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return _AdminOrderCard(
                    id: doc.id,
                    data: data,
                    refreshToken: _refreshToken,
                  );
                }),
            ];

            return RefreshIndicator(
              onRefresh: () async {
                setState(() => _refreshToken++);
                await Future.delayed(const Duration(milliseconds: 250));
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                children: widgets,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AdminOrderCard extends StatefulWidget {
  final String id;
  final Map<String, dynamic> data;
  final int refreshToken;

  // EN: Creates AdminOrderCard.
  // AR: ينشئ AdminOrderCard.
  const _AdminOrderCard({
    required this.id,
    required this.data,
    required this.refreshToken,
  });

  // EN: Creates state object.
  // AR: تنشئ كائن الحالة.
  @override
  State<_AdminOrderCard> createState() => _AdminOrderCardState();
}

class _AdminOrderCardState extends State<_AdminOrderCard> {
  late TextEditingController _linkCtrl;
  late TextEditingController _walletCtrl;
  bool _isUpdating = false;

  // EN: Handles is Final Status.
  // AR: تتعامل مع is Final Status.
  bool get _isFinalStatus {
    final s = (widget.data['status'] ?? '').toString();
    return s == 'completed' || s == 'rejected' || s == 'cancelled';
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

  // EN: Shows receipt image dialog.
  // AR: تعرض نافذة صورة الإيصال.
  Future<void> _showReceiptDialog(String url) async {
    final safeUrl = ensureHttps(url);
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) {
        final size = MediaQuery.of(ctx).size;
        return Dialog(
          backgroundColor: TTColors.cardBg,
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
                      const Icon(Icons.image, color: TTColors.primaryCyan),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          "صورة التحويل",
                          style: TextStyle(
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
                                  color: TTColors.textGray,
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
    await FirebaseFirestore.instance.collection('orders').doc(widget.id).update(
      {'status': newStatus},
    );
    if (mounted) setState(() => _isUpdating = false);
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
    await FirebaseFirestore.instance.collection('orders').doc(widget.id).update(
      {'delivery_link': _linkCtrl.text.trim(), 'status': 'processing'},
    );

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

  // EN: Builds widget UI.
  // AR: تبني واجهة الودجت.
  @override
  Widget build(BuildContext context) {
    final status = widget.data['status'] ?? 'unknown';
    final bool isFinalStatus = _isFinalStatus;
    final receiptUrl = widget.data['receipt_url'];
    final method = widget.data['method'];
    final String productType =
        (widget.data['product_type'] ?? 'tiktok').toString();
    final bool isGameOrder = productType == 'game';
    final bool isPromoOrder = productType == 'tiktok_promo';
    final String gameKey = (widget.data['game'] ?? '').toString();
    final String packageLabel =
        (widget.data['package_label'] ?? '').toString();
    final String gameId = (widget.data['game_id'] ?? '').toString();
    final String promoVideoLink = (widget.data['video_link'] ?? '').toString();
    final String leftText = isGameOrder
        ? "🎮 ${GamePackage.gameLabel(gameKey)} - $packageLabel"
        : (isPromoOrder
            ? "📣 ترويج فيديو"
            : "💎 ${widget.data['points']}");

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      borderColor: OrderStatusHelper.color(status).withAlpha(128),
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
                    color: TTColors.textWhite,
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: OrderStatusHelper.color(status),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  OrderStatusHelper.label(status),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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
                  color: TTColors.textWhite,
                  fontWeight: FontWeight.bold,
                ),
              ),

              Text(
                "💰 ${widget.data['price']} ج.م",
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
            style: TextStyle(color: TTColors.textGray, fontSize: 12),
          ),

          if (isGameOrder && gameId.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    "ID: $gameId",
                    style: TextStyle(color: TTColors.textGray, fontSize: 12),
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: gameId),
                    );
                    if (!mounted) return;
                    TopSnackBar.show(
                      context,
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
                    style: TextStyle(color: TTColors.textGray, fontSize: 12),
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: promoVideoLink),
                    );
                    if (!mounted) return;
                    TopSnackBar.show(
                      context,
                      "تم نسخ رابط الفيديو",
                      backgroundColor: TTColors.cardBg,
                      textColor: TTColors.textWhite,
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
                onPressed: () => _showReceiptDialog(receiptUrl),
              ),
            )
          else
            const Text(
              "⚠️ العميل لم يرفع الإيصال",
              style: TextStyle(color: Colors.redAccent),
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

          TextField(
            controller: _linkCtrl,
            readOnly: isFinalStatus,
            decoration: InputDecoration(
              labelText: isPromoOrder ? "رابط فيديو الترويج" : "رابط الشحن",
              prefixIcon: const Icon(Icons.link),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: "نسخ الرابط",
                    onPressed: _linkCtrl.text.trim().isEmpty
                        ? null
                        : () async {
                            await Clipboard.setData(
                              ClipboardData(text: _linkCtrl.text.trim()),
                            );
                            if (!mounted) return;
                            TopSnackBar.show(
                              context,
                              "تم نسخ الرابط",
                              backgroundColor: TTColors.cardBg,
                              textColor: TTColors.textWhite,
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
                return Text(
                  "تم تعيين الطلب ك$statusText.\nلا يمكن تعديل الحالة أو البيانات بعد ذلك.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: TTColors.textGray,
                    fontSize: 12,
                    fontFamily: 'Cairo',
                  ),
                );
              }

              return Wrap(
                spacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: () => _updateStatus("processing"),
                    child: const Text("جاري التنفيذ"),
                  ),

                  ElevatedButton(
                    onPressed: () => _updateStatus("completed"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text("مكتمل"),
                  ),

                  ElevatedButton(
                    onPressed: () => _updateStatus("rejected"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text("مرفوض"),
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
