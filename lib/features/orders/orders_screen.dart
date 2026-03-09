// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'dart:async';

import '../../core/app_navigator.dart';
import '../../core/order_status.dart';
import '../../core/tt_colors.dart';
import '../../models/game_package.dart';
import '../../services/cancel_limit_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/top_snackbar.dart';
import '../../widgets/glass_app_bar.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/snow_background.dart';
import '../../utils/url_sanitizer.dart';

class OrdersScreen extends StatefulWidget {
  final String whatsapp;
  final String? initialOrderId;

  // EN: Creates OrdersScreen.
  // AR: ينشئ OrdersScreen.
  const OrdersScreen({super.key, required this.whatsapp, this.initialOrderId});

  // EN: Creates state object.
  // AR: تنشئ كائن الحالة.
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _processingStatusSub;
  final Map<String, String> _orderStatusById = <String, String>{};
  final Set<String> _autoOpenedProcessingChatIds = <String>{};
  bool _processingStatusPrimed = false;
  String? _activeChatOrderId;
  bool _navigatingHome = false;

  @override
  void initState() {
    super.initState();
    final seededOrderId = (widget.initialOrderId ?? '').trim();
    if (seededOrderId.isNotEmpty) {
      _activeChatOrderId = seededOrderId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_openOrderChatFullscreen(orderId: seededOrderId));
      });
    }
    NotificationService.listenToUserOrders(widget.whatsapp);
    _startProcessingStatusWatcher();
  }

  @override
  void dispose() {
    _processingStatusSub?.cancel();
    super.dispose();
  }

  Future<void> _handlePageSwipeRefresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;
    setState(() {});
  }

  void _startProcessingStatusWatcher() {
    _processingStatusSub?.cancel();
    _orderStatusById.clear();
    _processingStatusPrimed = false;

    _processingStatusSub = FirebaseFirestore.instance
        .collection('orders')
        .where('user_whatsapp', isEqualTo: widget.whatsapp)
        .orderBy('created_at', descending: true)
        .limit(120)
        .snapshots()
        .listen((snapshot) {
          if (!_processingStatusPrimed) {
            for (final doc in snapshot.docs) {
              final data = doc.data();
              _orderStatusById[doc.id] = (data['status'] ?? '')
                  .toString()
                  .trim();
            }
            _processingStatusPrimed = true;
            return;
          }

          for (final change in snapshot.docChanges) {
            final docId = change.doc.id;
            if (change.type == DocumentChangeType.removed) {
              _orderStatusById.remove(docId);
              _autoOpenedProcessingChatIds.remove(docId);
              if (_activeChatOrderId == docId && mounted) {
                setState(() => _activeChatOrderId = null);
              }
              continue;
            }

            final data = change.doc.data() ?? <String, dynamic>{};
            final status = (data['status'] ?? '').toString().trim();
            final previousStatus = _orderStatusById[docId] ?? '';
            _orderStatusById[docId] = status;

            if (status == 'processing' && previousStatus != 'processing') {
              _focusOrderChat(docId, autoOpenedByStatus: true);
            }
          }
        }, onError: (error, stackTrace) {});
  }

  bool _isChatSupportedType(String productType) {
    return productType == 'tiktok' ||
        productType == 'game' ||
        productType == 'tiktok_promo';
  }

  String _sanitizeMerchantContactText(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return '';
    text = text.replaceAll(
      RegExp(r'\n?\s*للتواصل مع التاجر:\s*[^\n]+', caseSensitive: false),
      '',
    );
    text = text.replaceAll(
      RegExp(r'\n?\s*رقم التواصل:\s*[^\n]+', caseSensitive: false),
      '',
    );
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    return text;
  }

  void _focusOrderChat(String orderId, {bool autoOpenedByStatus = false}) {
    final trimmedOrderId = orderId.trim();
    if (!mounted || trimmedOrderId.isEmpty) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;

    if (_activeChatOrderId != trimmedOrderId) {
      setState(() => _activeChatOrderId = trimmedOrderId);
    }
    unawaited(_openOrderChatFullscreen(orderId: trimmedOrderId));

    if (!autoOpenedByStatus) return;
    if (_autoOpenedProcessingChatIds.contains(trimmedOrderId)) return;

    _autoOpenedProcessingChatIds.add(trimmedOrderId);
    TopSnackBar.show(
      context,
      'طلبك قيد التنفيذ.',
      backgroundColor: Colors.green,
      textColor: Colors.white,
      icon: Icons.chat_rounded,
    );
  }

  Future<void> _openOrderChatFullscreen({required String orderId}) async {
    final trimmedOrderId = orderId.trim();
    if (!mounted || trimmedOrderId.isEmpty) return;
    final args = <String, dynamic>{
      'order_id': trimmedOrderId,
      'viewer_role': 'user',
      'whatsapp': widget.whatsapp,
    };
    AppNavigator.pushNamed(context, '/order_chat', arguments: args);
  }

  Future<void> _returnToHome() async {
    if (!mounted || _navigatingHome) return;
    _navigatingHome = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final resolvedWhatsapp = widget.whatsapp.trim().isNotEmpty
          ? widget.whatsapp.trim()
          : (prefs.getString('user_whatsapp') ?? '').trim();
      final resolvedName = (prefs.getString('user_name') ?? '').trim();
      final resolvedTiktok = (prefs.getString('user_tiktok') ?? '').trim();

      if (!mounted) return;
      final args = <String, dynamic>{
        if (resolvedName.isNotEmpty) 'name': resolvedName,
        if (resolvedWhatsapp.isNotEmpty) 'whatsapp': resolvedWhatsapp,
        if (resolvedTiktok.isNotEmpty) 'tiktok': resolvedTiktok,
      };
      AppNavigator.pushNamedAndRemoveUntil(
        context,
        '/home',
        (_) => false,
        arguments: args.isEmpty ? null : args,
      );
    } finally {
      _navigatingHome = false;
    }
  }

  // EN: Builds widget UI.
  // AR: تبني واجهة الودجت.
  @override
  Widget build(BuildContext context) {
    const double webMaxWidth = 520;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_returnToHome());
      },
      child: Scaffold(
        appBar: GlassAppBar(
          title: const Text('طلباتي'),
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'رجوع',
            onPressed: () => unawaited(_returnToHome()),
          ),
        ),
        body: CustomMaterialIndicator(
          onRefresh: _handlePageSwipeRefresh,
          child: Stack(
            children: [
              const SnowBackground(),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .where('user_whatsapp', isEqualTo: widget.whatsapp)
                    .orderBy('created_at', descending: true)
                    .snapshots(),
                builder: (c, s) {
                  if (s.hasError) return Center(child: Text("خطأ: ${s.error}"));
                  if (s.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!s.hasData || s.data!.docs.isEmpty) {
                    return const Center(child: Text("لا توجد طلبات"));
                  }

                  _cleanupOldOrders(s.data!.docs);
                  final visibleDocs = s.data!.docs
                      .where(
                        (doc) => _isChatSupportedType(
                          (doc.data()['product_type'] ?? 'tiktok')
                              .toString()
                              .trim(),
                        ),
                      )
                      .toList(growable: false);
                  if (visibleDocs.isEmpty) {
                    return const Center(child: Text("لا توجد طلبات"));
                  }

                  final chatOrderIds = visibleDocs
                      .where((doc) {
                        final data = doc.data();
                        final productType = (data['product_type'] ?? 'tiktok')
                            .toString();
                        final status = (data['status'] ?? '').toString().trim();
                        final isFinalStatus =
                            status == 'completed' ||
                            status == 'rejected' ||
                            status == 'cancelled';
                        return _isChatSupportedType(productType) &&
                            !isFinalStatus;
                      })
                      .map((doc) => doc.id)
                      .toList(growable: false);

                  if (chatOrderIds.isNotEmpty &&
                      (_activeChatOrderId == null ||
                          !chatOrderIds.contains(_activeChatOrderId))) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      setState(() => _activeChatOrderId = chatOrderIds.first);
                    });
                  }

                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: kIsWeb ? webMaxWidth : double.infinity,
                      ),
                      child: ListView(
                        padding: const EdgeInsets.all(12),
                        children: visibleDocs.map((d) {
                          final data = d.data();
                          final status = (data['status'] ?? 'unknown')
                              .toString();
                          final String rejectionReason =
                              _sanitizeMerchantContactText(
                                (data['rejection_reason'] ?? '')
                                    .toString()
                                    .trim(),
                              );
                          final String productType =
                              (data['product_type'] ?? 'tiktok').toString();
                          final bool isSupportedChatType = _isChatSupportedType(
                            productType,
                          );
                          final bool isFinalChatClosed =
                              status == 'completed' ||
                              status == 'rejected' ||
                              status == 'cancelled';
                          final bool shouldShowChatSection =
                              isSupportedChatType && !isFinalChatClosed;
                          final bool isGameOrder = productType == 'game';
                          final bool isPromoOrder =
                              productType == 'tiktok_promo';
                          final String tiktokChargeMode =
                              (data['tiktok_charge_mode'] ?? '')
                                  .toString()
                                  .trim();
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
                          final String gameKey = (data['game'] ?? '')
                              .toString();
                          final String packageLabel =
                              (data['package_label'] ?? '').toString();
                          final String gameId = (data['game_id'] ?? '')
                              .toString();
                          final String titleText = isGameOrder
                              ? "${GamePackage.gameLabel(gameKey)} - $packageLabel"
                              : (isPromoOrder
                                    ? "ترويج فيديو تيك توك"
                                    : "${data['points']} نقطة");

                          final String paymentMethod = (data['method'] ?? '')
                              .toString();
                          final bool isBinanceMethod =
                              paymentMethod == 'Binance Pay';
                          final bool isPointsMethod = paymentMethod == 'Points';
                          double? parseLooseNumber(dynamic raw) {
                            if (raw == null) return null;
                            if (raw is num) return raw.toDouble();
                            final text = raw.toString().trim().replaceAll(
                              ',',
                              '.',
                            );
                            if (text.isEmpty) return null;
                            final m = RegExp(
                              r'-?\d+(?:\.\d+)?',
                            ).firstMatch(text);
                            if (m == null) return null;
                            return double.tryParse(m.group(0)!);
                          }

                          String compactAmount(num value) {
                            final v = value.toDouble();
                            if (v == v.roundToDouble()) {
                              return v.toStringAsFixed(0);
                            }
                            if ((v * 10) == (v * 10).roundToDouble()) {
                              return v.toStringAsFixed(1);
                            }
                            return v.toStringAsFixed(2);
                          }

                          String roundUpMoney(num value) {
                            return value.toDouble().ceil().toString();
                          }

                          final double? egpAmount = parseLooseNumber(
                            data['price'],
                          );
                          final double? originalEgpAmount =
                              parseLooseNumber(data['original_price']) ??
                              egpAmount;
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
                              parseLooseNumber(
                                data['points_discount'],
                              )?.round() ??
                              0;
                          final int pointsPaid =
                              parseLooseNumber(data['points_paid'])?.round() ??
                              0;

                          final String orderAmountText = isPointsMethod
                              ? (originalEgpAmount != null
                                    ? "${roundUpMoney(originalEgpAmount)} جنيه (مدفوع بالنقاط)"
                                    : "مدفوع بالنقاط")
                              : isBinanceMethod
                              ? (usdtAmount != null
                                    ? "${compactAmount(usdtAmount)} USDT"
                                    : "USDT غير متاح")
                              : (egpAmount != null
                                    ? "${roundUpMoney(egpAmount)} جنيه"
                                    : "${data['price']} جنيه");
                          final bool canCancel =
                              status == 'pending_payment' ||
                              status == 'pending_review';

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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
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
                                          color: OrderStatusHelper.color(
                                            status,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        OrderStatusHelper.label(status),
                                        style: TextStyle(
                                          color: OrderStatusHelper.color(
                                            status,
                                          ),
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
                                    style: TextStyle(
                                      color: TTColors.goldAccent,
                                    ),
                                  ),
                                ],

                                if (paymentMethod == 'Points' ||
                                    pointsPaid > 0) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'تم الدفع من الرصيد: ${pointsPaid > 0 ? pointsPaid : '-'} نقطة',
                                    style: TextStyle(
                                      color: TTColors.goldAccent,
                                    ),
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

                                if (isPromoOrder &&
                                    promoLink.isNotEmpty &&
                                    !isFinalChatClosed)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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

                                if (shouldShowChatSection) ...[
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _focusOrderChat(d.id),
                                      icon: const Icon(Icons.chat_rounded),
                                      label: const Text(
                                        'المحادثة',
                                        style: TextStyle(fontFamily: 'Cairo'),
                                      ),
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
        ),
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
        'tiktok_password': FieldValue.delete(),
        'video_link': null,
        'video_link_removed_at': FieldValue.serverTimestamp(),
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
          dedupeKey: 'user_order_status:${orderId.trim()}:cancelled',
          dedupeDuration: const Duration(hours: 24),
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

  Future<void> _cleanupOldOrders(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
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
}
