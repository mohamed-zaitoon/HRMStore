// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:math';
import 'dart:async';

import '../../core/order_status.dart';
import '../../core/tt_colors.dart';
import '../../models/game_package.dart';
import '../../services/cancel_limit_service.dart';
import '../../services/cloudflare_notify_service.dart';
import '../../services/notification_service.dart';
import '../../services/receipt_storage_service.dart';
import '../../widgets/top_snackbar.dart';
import '../../widgets/glass_app_bar.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/snow_background.dart';
import '../../utils/url_sanitizer.dart';

class OrdersScreen extends StatefulWidget {
  final String whatsapp;

  // EN: Creates OrdersScreen.
  // AR: ينشئ OrdersScreen.
  const OrdersScreen({super.key, required this.whatsapp});

  // EN: Creates state object.
  // AR: تنشئ كائن الحالة.
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final Map<String, String> _walletCache = {};
  final _rand = Random();
  int _refreshToken = 0;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    NotificationService.listenToUserOrders(widget.whatsapp);
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => setState(() {
        _refreshToken++;
      }),
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<String> _resolveWallet(
    String orderId,
    String current,
    String method,
    Timestamp? createdAt,
    int refreshToken,
  ) async {
    final normalized = current.trim();
    // إذا كان هناك رقم حقيقي موجود بالفعل، نعرضه كما هو
    if (normalized.isNotEmpty &&
        normalized != "تواصل مع الدعم" &&
        !normalized.toLowerCase().contains("support")) {
      return normalized;
    }

    // لا ننشئ رقماً عشوائياً إلا لطلبات المحفظة فقط
    if (method != 'Wallet') {
      return normalized;
    }

    // اترك الحقل فارغاً لأول دقيقة ليتمكن الدعم من إضافة الرقم يدوياً
    if (createdAt != null) {
      final age = DateTime.now().difference(createdAt.toDate());
      // منح الدعم 15 ثانية قبل التوليد التلقائي
      if (age < const Duration(seconds: 15)) {
        return "";
      }
    }

    // لا تعيد استعلام إذا كنا قد عيّنا رقماً عشوائياً سابقاً لنفس الطلب
    if (_walletCache.containsKey(orderId)) return _walletCache[orderId]!;

    final snap = await FirebaseFirestore.instance
        .collection('wallets')
        .limit(50)
        .get();
    if (snap.docs.isEmpty) return "";

    String _extractWallet(Map<String, dynamic> data) {
      if (data.containsKey('number')) {
        final v = data['number'];
        if (v is String && v.trim().isNotEmpty) return v.trim();
        if (v is num) return v.toString();
      }
      for (final entry in data.entries) {
        final v = entry.value;
        if (v is String && v.trim().isNotEmpty) return v.trim();
        if (v is num) return v.toString();
      }
      return "";
    }

    // اجمع فقط المحافظ الصالحة ثم اختر عشوائياً لضمان توزيع عادل وتجنّب القيم الفارغة
    final validWallets = snap.docs
        .map((d) => _extractWallet(d.data()))
        .where((w) => w.isNotEmpty)
        .toList();

    if (validWallets.isEmpty) return "";

    final wallet = validWallets[_rand.nextInt(validWallets.length)];

    _walletCache[orderId] = wallet;

    // احفظ الرقم في الطلب بعد الدقيقة ليظهر للجميع
    await FirebaseFirestore.instance.collection('orders').doc(orderId).set({
      'wallet_number': wallet,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return wallet;
  }

  Future<bool> _verifyReceiptAvailableForAdmin({
    required String orderId,
    required String receiptPath,
  }) async {
    for (var i = 0; i < 7; i++) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('orders')
            .doc(orderId)
            .get(const GetOptions(source: Source.server));

        final data = snap.data();
        final savedPath = (data?['receipt_path'] ?? '').toString().trim();
        final savedUrl = (data?['receipt_url'] ?? '').toString().trim();
        final savedStatus = (data?['status'] ?? '').toString().trim();

        if (savedPath == receiptPath &&
            savedUrl.isNotEmpty &&
            savedStatus == 'pending_review') {
          return true;
        }
      } catch (_) {}

      await Future<void>.delayed(const Duration(milliseconds: 450));
    }

    return false;
  }

  // EN: Uploads Receipt For Order.
  // AR: ترفع Receipt For Order.
  Future<void> _uploadReceiptForOrder(
    String orderId,
    String amountText,
    String walletNum,
    String paymentLabel,
    Color paymentColor,
  ) async {
    bool proceed = false;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: TTColors.cardBg,
        title: const Text(
          "إكمال الطلب",
          style: TextStyle(fontFamily: 'Cairo', color: Colors.greenAccent),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "المبلغ: $amountText",
              style: TextStyle(color: TTColors.textWhite, fontFamily: 'Cairo'),
            ),

            const SizedBox(height: 10),

            Text(
              "حول المبلغ إلى:",
              style: TextStyle(color: TTColors.textGray, fontFamily: 'Cairo'),
            ),

            const SizedBox(height: 4),

            Text(
              paymentLabel,
              style: TextStyle(color: TTColors.textGray, fontFamily: 'Cairo'),
            ),

            SelectableText(
              walletNum,
              style: TextStyle(
                color: paymentColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              "هل حولت المبلغ وتريد رفع الإيصال؟",
              style: TextStyle(
                color: TTColors.textWhite,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              proceed = false;
            },
            child: const Text("إلغاء", style: TextStyle(color: Colors.red)),
          ),

          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              Navigator.pop(ctx);
              proceed = true;
            },
            child: const Text(
              "نعم، رفع الصورة",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (!proceed) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp', 'heic'],
        withData: true,
        dialogTitle: 'اختر صورة من الملفات',
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      Uint8List? fileBytes = result.files.first.bytes;

      if (fileBytes == null) return;

      if (!mounted) return;
      bool confirmUpload = false;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: TTColors.cardBg,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.memory(fileBytes!, height: 200, fit: BoxFit.cover),

              const SizedBox(height: 10),

              Text(
                "هل الصورة واضحة؟",
                style: TextStyle(
                  color: TTColors.textWhite,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
              },
              child: const Text("تغيير"),
            ),

            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                confirmUpload = true;
              },
              child: const Text("إرسال"),
            ),
          ],
        ),
      );

      if (!mounted) return;
      if (!confirmUpload) return;

      TopSnackBar.show(
        context,
        "جاري الرفع...",
        backgroundColor: TTColors.cardBg,
        textColor: TTColors.textWhite,
        icon: Icons.cloud_upload,
        duration: null,
      );

      final uploadRes = await ReceiptStorageService.uploadWithPath(
        bytes: fileBytes,
        whatsapp: widget.whatsapp,
        orderId: orderId,
      );
      if (!mounted) {
        TopSnackBar.dismiss();
        return;
      }

      if (uploadRes != null) {
        await FirebaseFirestore.instance
            .collection('orders')
            .doc(orderId)
            .update({
              'receipt_url': uploadRes.url,
              'receipt_path': uploadRes.path,
              'receipt_expires_at': Timestamp.fromDate(
                DateTime.now().add(const Duration(minutes: 30)),
              ),
              'status': 'pending_review',
              'updated_at': FieldValue.serverTimestamp(),
              'receipt_uploaded_at': FieldValue.serverTimestamp(),
            });
        unawaited(
          CloudflareNotifyService.notifyAdminsReceiptUploaded(
            orderId: orderId,
            userWhatsapp: widget.whatsapp,
          ),
        );
        if (!mounted) return;
        final deliveredToAdmin = await _verifyReceiptAvailableForAdmin(
          orderId: orderId,
          receiptPath: uploadRes.path,
        );
        if (!mounted) {
          TopSnackBar.dismiss();
          return;
        }
        TopSnackBar.show(
          context,
          deliveredToAdmin
              ? "تم الرفع بنجاح ✅"
              : "تم الرفع بنجاح ✅ وجارٍ المزامنة لدى الأدمن",
          backgroundColor: deliveredToAdmin ? Colors.green : Colors.orange,
          textColor: Colors.white,
          icon: deliveredToAdmin ? Icons.check_circle : Icons.sync,
        );
      } else {
        TopSnackBar.show(
          context,
          "فشل رفع الصورة، حاول مجدداً",
          backgroundColor: Colors.red,
          textColor: Colors.white,
          icon: Icons.error,
        );
      }
    } catch (e) {
      TopSnackBar.dismiss();
      if (mounted) {
        TopSnackBar.show(
          context,
          "حدث خطأ أثناء رفع الصورة",
          backgroundColor: Colors.red,
          textColor: Colors.white,
          icon: Icons.error_outline,
        );
      }
      debugPrint("Error: $e");
    }
  }

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

  // EN: Builds widget UI.
  // AR: تبني واجهة الودجت.
  @override
  Widget build(BuildContext context) {
    const double webMaxWidth = 520;

    return Scaffold(
      appBar: const GlassAppBar(title: Text('طلباتي')),
      body: Stack(
        children: [
          const SnowBackground(),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where('user_whatsapp', isEqualTo: widget.whatsapp)
                .orderBy('created_at', descending: true)
                .snapshots(),
            builder: (c, s) {
              if (s.hasError) return Center(child: Text("خطأ: ${s.error}"));
              if (s.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              if (!s.hasData || s.data!.docs.isEmpty)
                return const Center(child: Text("لا توجد طلبات"));

              _cleanupOldOrders(s.data!.docs);

              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: kIsWeb ? webMaxWidth : double.infinity,
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: s.data!.docs.map((d) {
                      final data = d.data() as Map<String, dynamic>;
                      final status = (data['status'] ?? 'unknown').toString();
                      final String rejectionReason =
                          (data['rejection_reason'] ?? '').toString().trim();
                      final String deliveryLink = (data['delivery_link'] ?? '')
                          .toString()
                          .trim();
                      final String deliveryQrUrl =
                          (data['delivery_qr_url'] ?? '').toString().trim();
                      final String productType =
                          (data['product_type'] ?? 'tiktok').toString();
                      final bool isGameOrder = productType == 'game';
                      final bool isPromoOrder = productType == 'tiktok_promo';
                      final bool isBalanceTopupOrder =
                          productType == 'balance_topup';
                      final String tiktokChargeMode =
                          (data['tiktok_charge_mode'] ?? '').toString().trim();
                      final String tiktokChargeModeLabel =
                          tiktokChargeMode == 'username_password'
                          ? 'يوزر + باسورد'
                          : tiktokChargeMode == 'qr'
                          ? 'QR'
                          : tiktokChargeMode == 'link'
                          ? 'لينك'
                          : '';
                      final String promoLink = (data['video_link'] ?? '')
                          .toString();
                      final String gameKey = (data['game'] ?? '').toString();
                      final String packageLabel = (data['package_label'] ?? '')
                          .toString();
                      final String gameId = (data['game_id'] ?? '').toString();
                      String titleText = isGameOrder
                          ? "${GamePackage.gameLabel(gameKey)} - $packageLabel"
                          : (isPromoOrder
                                ? "ترويج فيديو تيك توك"
                                : "${data['points']} نقطة");

                      final String walletNum =
                          data['wallet_number']?.toString() ?? "";
                      final String paymentMethod = (data['method'] ?? '')
                          .toString();
                      final bool isWalletMethod = paymentMethod == 'Wallet';
                      final bool isBinanceMethod =
                          paymentMethod == 'Binance Pay';
                      final bool isPointsMethod = paymentMethod == 'Points';
                      double? parseLooseNumber(dynamic raw) {
                        if (raw == null) return null;
                        if (raw is num) return raw.toDouble();
                        final text = raw.toString().trim().replaceAll(',', '.');
                        if (text.isEmpty) return null;
                        final m = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(text);
                        if (m == null) return null;
                        return double.tryParse(m.group(0)!);
                      }

                      String compactAmount(num value) {
                        final v = value.toDouble();
                        if (v == v.roundToDouble()) return v.toStringAsFixed(0);
                        if ((v * 10) == (v * 10).roundToDouble()) {
                          return v.toStringAsFixed(1);
                        }
                        return v.toStringAsFixed(2);
                      }

                      final double? egpAmount = parseLooseNumber(data['price']);
                      final double? originalEgpAmount =
                          parseLooseNumber(data['original_price']) ?? egpAmount;
                      final double? usdtFromDoc = parseLooseNumber(
                        data['usdt_amount'],
                      );
                      final double? usdtRate = parseLooseNumber(
                        data['usdt_price'],
                      );
                      final double? usdtAmount =
                          usdtFromDoc ??
                          ((egpAmount != null &&
                                  usdtRate != null &&
                                  usdtRate > 0)
                              ? (egpAmount / usdtRate)
                              : null);
                      final int pointsDiscount =
                          parseLooseNumber(data['points_discount'])?.round() ??
                          0;
                      final int pointsPaid =
                          parseLooseNumber(data['points_paid'])?.round() ?? 0;
                      final int topupPoints =
                          parseLooseNumber(
                            data['balance_points_requested'],
                          )?.round() ??
                          (parseLooseNumber(data['points'])?.round() ?? 0);

                      if (isBalanceTopupOrder) {
                        titleText = topupPoints > 0
                            ? "شحن الرصيد - $topupPoints نقطة"
                            : "شحن الرصيد";
                      }

                      final String orderAmountText = isPointsMethod
                          ? (originalEgpAmount != null
                                ? "${compactAmount(originalEgpAmount)} جنيه (مدفوع بالنقاط)"
                                : "مدفوع بالنقاط")
                          : isBinanceMethod
                          ? (usdtAmount != null
                                ? "${compactAmount(usdtAmount)} USDT"
                                : "USDT غير متاح")
                          : (egpAmount != null
                                ? "${compactAmount(egpAmount)} جنيه"
                                : "${data['price']} جنيه");
                      final bool showWalletSection =
                          (isWalletMethod || isBinanceMethod) &&
                          (status == 'pending_payment' ||
                              status == 'pending_review' ||
                              status == 'processing');
                      final bool canCancel =
                          status == 'pending_payment' ||
                          status == 'pending_review';
                      _maybeCleanupReceipt(d.id, data);

                      return GlassCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        borderColor: OrderStatusHelper.color(
                          status,
                        ).withAlpha(77),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  titleText,
                                  style: TextStyle(
                                    color: TTColors.textWhite,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: OrderStatusHelper.color(
                                      status,
                                    ).withAlpha(51),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: OrderStatusHelper.color(status),
                                    ),
                                  ),
                                  child: Text(
                                    OrderStatusHelper.label(status),
                                    style: TextStyle(
                                      color: OrderStatusHelper.color(status),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            Text(
                              'السعر: $orderAmountText',
                              style: TextStyle(color: TTColors.textGray),
                            ),

                            if (!isGameOrder &&
                                !isPromoOrder &&
                                !isBalanceTopupOrder &&
                                tiktokChargeModeLabel.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'طريقة الشحن: $tiktokChargeModeLabel',
                                style: TextStyle(color: TTColors.textGray),
                              ),
                            ],

                            if (pointsDiscount > 0) ...[
                              const SizedBox(height: 4),
                              Text(
                                'خصم من رصيد النقاط: $pointsDiscount نقطة',
                                style: TextStyle(color: TTColors.goldAccent),
                              ),
                            ],

                            if (paymentMethod == 'Points' ||
                                pointsPaid > 0) ...[
                              const SizedBox(height: 4),
                              Text(
                                'تم الدفع من الرصيد: ${pointsPaid > 0 ? pointsPaid : '-'} نقطة',
                                style: TextStyle(color: TTColors.goldAccent),
                              ),
                            ],

                            if (isBalanceTopupOrder) ...[
                              const SizedBox(height: 4),
                              Text(
                                'شحن النقاط اختياري وليس إجباريًا',
                                style: TextStyle(color: TTColors.textGray),
                              ),
                            ],

                            if (status == 'rejected') ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.red.withAlpha(20),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.red.withAlpha(90),
                                  ),
                                ),
                                child: Text(
                                  rejectionReason.isEmpty
                                      ? "تم رفض الطلب. للتفاصيل تواصل مع الدعم."
                                      : "سبب الرفض: $rejectionReason",
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontFamily: 'Cairo',
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],

                            if (isGameOrder && gameId.isNotEmpty)
                              Text(
                                'ID: $gameId',
                                style: TextStyle(color: TTColors.textGray),
                              ),

                            if (isPromoOrder && promoLink.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "رابط الترويج:",
                                      style: TextStyle(
                                        color: TTColors.textGray,
                                        fontSize: 12,
                                        fontFamily: 'Cairo',
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: SelectableText(
                                            promoLink,
                                            style: TextStyle(
                                              color: TTColors.textWhite,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.open_in_new,
                                            color: Colors.blueAccent,
                                            size: 20,
                                          ),
                                          onPressed: () async {
                                            final url = ensureHttps(
                                              promoLink.trim(),
                                            );
                                            try {
                                              await launchUrl(
                                                Uri.parse(url),
                                                mode: LaunchMode
                                                    .externalApplication,
                                              );
                                            } catch (_) {}
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                            if (showWalletSection) ...[
                              Divider(
                                color: Theme.of(context).dividerColor,
                                height: 15,
                              ),

                              FutureBuilder<String>(
                                future: _resolveWallet(
                                  d.id,
                                  walletNum,
                                  paymentMethod,
                                  data['created_at'] as Timestamp?,
                                  _refreshToken,
                                ),
                                builder: (ctx, snapWallet) {
                                  final resolved = snapWallet.data ?? "";
                                  final paymentLabel = isBinanceMethod
                                      ? "Binance Pay ID:"
                                      : "رقم المحفظة:";
                                  final paymentColor = isBinanceMethod
                                      ? const Color(0xFFF3BA2F)
                                      : Colors.orangeAccent;
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: paymentColor.withAlpha(26),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              paymentLabel,
                                              style: TextStyle(
                                                color: paymentColor,
                                                fontSize: 12,
                                                fontFamily: 'Cairo',
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: SelectableText(
                                                    resolved,
                                                    style: TextStyle(
                                                      color: TTColors.textWhite,
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.copy,
                                                    color: Colors.grey,
                                                    size: 20,
                                                  ),
                                                  onPressed:
                                                      resolved.trim().isEmpty
                                                      ? null
                                                      : () {
                                                          Clipboard.setData(
                                                            ClipboardData(
                                                              text: resolved,
                                                            ),
                                                          );
                                                          TopSnackBar.show(
                                                            context,
                                                            "تم النسخ",
                                                            backgroundColor:
                                                                TTColors.cardBg,
                                                            textColor: TTColors
                                                                .textWhite,
                                                            icon: Icons.copy,
                                                          );
                                                        },
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                          ),
                                          icon: const Icon(Icons.upload_file),
                                          label: Text(
                                            isBalanceTopupOrder
                                                ? "إرفاق إثبات شحن الرصيد"
                                                : "إرفاق الإيصال وإكمال الطلب",
                                            style: const TextStyle(
                                              fontFamily: 'Cairo',
                                            ),
                                          ),
                                          onPressed:
                                              (snapWallet.connectionState ==
                                                      ConnectionState.waiting ||
                                                  resolved.trim().isEmpty)
                                              ? null
                                              : () => _uploadReceiptForOrder(
                                                  d.id,
                                                  orderAmountText,
                                                  resolved,
                                                  paymentLabel,
                                                  paymentColor,
                                                ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],

                            if (status == 'processing' &&
                                !isGameOrder &&
                                !isPromoOrder &&
                                !isBalanceTopupOrder &&
                                tiktokChargeMode == 'qr' &&
                                deliveryQrUrl.isEmpty) ...[
                              Divider(
                                color: Theme.of(context).dividerColor,
                                height: 15,
                              ),
                              Text(
                                "بانتظار إرسال صورة QR من الدعم",
                                style: TextStyle(color: TTColors.textGray),
                              ),
                            ],

                            if (status == 'processing' &&
                                !isBalanceTopupOrder &&
                                deliveryQrUrl.isNotEmpty) ...[
                              Divider(
                                color: Theme.of(context).dividerColor,
                                height: 15,
                              ),

                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF5B21B6),
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.qr_code_2),
                                  label: const Text(
                                    "عرض صورة QR",
                                    style: TextStyle(fontFamily: 'Cairo'),
                                  ),
                                  onPressed: () => _showImageDialog(
                                    deliveryQrUrl,
                                    title: "QR الشحن",
                                  ),
                                ),
                              ),
                            ],

                            if ((status == 'processing' ||
                                    status == 'completed') &&
                                !isBalanceTopupOrder &&
                                deliveryLink.isNotEmpty) ...[
                              Divider(
                                color: Theme.of(context).dividerColor,
                                height: 15,
                              ),

                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueAccent,
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.link),
                                  label: const Text(
                                    "فتح رابط الشحن",
                                    style: TextStyle(fontFamily: 'Cairo'),
                                  ),
                                  onPressed: () async {
                                    final Uri url = Uri.parse(
                                      ensureHttps(deliveryLink.trim()),
                                    );
                                    try {
                                      await launchUrl(
                                        url,
                                        mode: LaunchMode.externalApplication,
                                      );
                                    } catch (e) {}
                                  },
                                ),
                              ),
                            ],

                            if (canCancel) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                    side: const BorderSide(
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                  icon: const Icon(Icons.cancel),
                                  label: const Text(
                                    'إلغاء الطلب',
                                    style: TextStyle(fontFamily: 'Cairo'),
                                  ),
                                  onPressed: () =>
                                      _confirmCancel(context, d.id),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, String orderId) async {
    bool confirm = false;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TTColors.cardBg,
        title: const Text('تأكيد الإلغاء'),
        content: const Text(
          'هل أنت متأكد أنك تريد إلغاء الطلب؟ بعد 5 إلغاءات خلال 24 ساعة سيتم حظر إنشاء طلبات جديدة لمدة 24 ساعة.',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('لا'),
          ),
          ElevatedButton(
            onPressed: () {
              confirm = true;
              Navigator.pop(ctx);
            },
            child: const Text('نعم، إلغاء'),
          ),
        ],
      ),
    );
    if (!confirm) return;
    await _cancelOrder(orderId);
  }

  Future<void> _cancelOrder(String orderId) async {
    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).set({
        'status': 'cancelled',
        'cancelled_at': FieldValue.serverTimestamp(),
        'cancelled_by': 'user',
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _registerCancellationForCurrentUser();
      if (mounted) {
        TopSnackBar.show(
          context,
          "تم إلغاء الطلب",
          backgroundColor: Colors.redAccent,
          textColor: Colors.white,
          icon: Icons.cancel,
        );
      }
    } catch (e) {
      if (mounted) {
        TopSnackBar.show(
          context,
          "تعذر إلغاء الطلب، حاول لاحقاً",
          backgroundColor: Colors.orange,
          textColor: Colors.white,
          icon: Icons.error_outline,
        );
      }
    }
  }

  Future<void> _registerCancellationForCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = (prefs.getString('user_uid') ?? '').trim();
      await CancelLimitService.registerCancellation(
        whatsapp: widget.whatsapp,
        uid: uid.isEmpty ? null : uid,
      );
    } catch (e) {
      debugPrint('cancel counter update failed: $e');
    }
  }

  Future<void> _cleanupOldOrders(List<QueryDocumentSnapshot> docs) async {
    // يحتفظ بآخر 50 طلباً، ويحذف الأقدم
    if (docs.length <= 50) return;
    final toDelete = docs.sublist(50);
    for (final doc in toDelete) {
      try {
        await FirebaseFirestore.instance
            .collection('orders')
            .doc(doc.id)
            .delete();
      } catch (_) {
        // تجاهل الأخطاء
      }
    }
  }

  Future<void> _maybeCleanupReceipt(
    String orderId,
    Map<String, dynamic> data,
  ) async {
    final String url = data['receipt_url']?.toString() ?? '';
    if (url.isEmpty) return;
    final Timestamp? expiresTs = data['receipt_expires_at'] as Timestamp?;
    final String path = data['receipt_path']?.toString() ?? '';
    final Timestamp? deletedAt = data['receipt_deleted_at'] as Timestamp?;

    if (deletedAt != null) return;

    final now = DateTime.now();
    final expiresAt = expiresTs?.toDate();
    if (expiresAt == null || now.isBefore(expiresAt)) return;

    try {
      if (path.isNotEmpty) {
        await ReceiptStorageService.deleteByPath(path);
      } else {
        await ReceiptStorageService.deleteByUrl(url);
      }
      await FirebaseFirestore.instance.collection('orders').doc(orderId).set({
        'receipt_url': null,
        'receipt_path': null,
        'receipt_deleted_at': Timestamp.fromDate(now),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // تجاهل أي خطأ
    }
  }
}
