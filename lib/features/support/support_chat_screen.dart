// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_navigator.dart';
import '../../core/order_status.dart';
import '../../core/tt_colors.dart';
import '../../services/cancel_limit_service.dart';
import '../../services/notification_service.dart';
import '../../services/order_chat_service.dart';
import '../../widgets/glass_app_bar.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/order_chat_panel.dart';
import '../../widgets/snow_background.dart';
import '../../widgets/top_snackbar.dart';

class SupportChatScreen extends StatefulWidget {
  final String name;
  final String whatsapp;
  final String? initialOrderId;

  // EN: Creates SupportChatScreen.
  // AR: ينشئ شاشة شات الطلبات.
  const SupportChatScreen({
    super.key,
    required this.name,
    required this.whatsapp,
    this.initialOrderId,
  });

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  String? _selectedOrderId;
  bool _finalStatusCloseTriggered = false;
  final Map<String, Timer> _paymentFallbackTimers = <String, Timer>{};
  final Set<String> _paymentFallbackDone = <String>{};
  final Map<String, DateTime> _paymentFallbackAttemptAt = <String, DateTime>{};
  bool get _isPinnedToSingleOrder =>
      (widget.initialOrderId ?? '').trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final seededOrderId = (widget.initialOrderId ?? '').trim();
    if (seededOrderId.isNotEmpty) {
      _selectedOrderId = seededOrderId;
    }
    NotificationService.listenToUserOrders(widget.whatsapp);
  }

  @override
  void dispose() {
    for (final timer in _paymentFallbackTimers.values) {
      timer.cancel();
    }
    _paymentFallbackTimers.clear();
    super.dispose();
  }

  bool _isChatSupportedType(String productType) {
    return productType == 'tiktok' ||
        productType == 'game' ||
        productType == 'tiktok_promo';
  }

  bool _isExecutionChatOpen(String status) {
    return status == 'pending_payment' ||
        status == 'pending_review' ||
        status == 'processing';
  }

  bool _isFinalOrderStatus(String status) {
    return status == 'completed' ||
        status == 'rejected' ||
        status == 'cancelled';
  }

  bool _canCancelOrder(String status) {
    return status == 'pending_payment' || status == 'pending_review';
  }

  String _normalizeDigits(String value) {
    if (value.isEmpty) return '';
    final normalized = StringBuffer();
    for (final rune in value.runes) {
      if (rune >= 0x0660 && rune <= 0x0669) {
        normalized.writeCharCode(0x30 + (rune - 0x0660));
        continue;
      }
      if (rune >= 0x06F0 && rune <= 0x06F9) {
        normalized.writeCharCode(0x30 + (rune - 0x06F0));
        continue;
      }
      normalized.writeCharCode(rune);
    }
    return normalized.toString();
  }

  String _digitsOnly(String value) {
    final normalized = _normalizeDigits(value);
    return normalized.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String _normalizedToken(String value) {
    return _normalizeDigits(
      value,
    ).toLowerCase().replaceAll(RegExp(r'[\u200E\u200F\s\-]+'), '');
  }

  Future<String> _fallbackWalletNumber() async {
    try {
      final walletsSnap = await FirebaseFirestore.instance
          .collection('wallets')
          .limit(3)
          .get();
      for (final doc in walletsSnap.docs) {
        final data = doc.data();
        final direct = (data['number'] ?? '').toString().trim();
        if (direct.isNotEmpty) return direct;
        final numbers = data['numbers'];
        if (numbers is List) {
          for (final item in numbers) {
            final text = item.toString().trim();
            if (text.isNotEmpty) return text;
          }
        }
      }
    } catch (_) {}
    return '';
  }

  Future<({String wallet, String binance})>
  _fetchPaymentTargetsFromFirebase() async {
    var wallet = '';
    var binance = '';
    try {
      final rc = FirebaseRemoteConfig.instance;
      try {
        await rc.fetchAndActivate();
      } catch (_) {}
      wallet = rc.getString('wallet_number').trim();
      binance = rc.getString('binance_id').trim();
    } catch (_) {}

    if (wallet.isEmpty) {
      wallet = await _fallbackWalletNumber();
    }
    return (wallet: wallet, binance: binance);
  }

  Future<bool> _hasPaymentInstructionMessage({
    required String orderId,
    required String method,
    required String target,
  }) async {
    final targetDigits = _digitsOnly(target);
    final targetToken = _normalizedToken(target);

    try {
      final snap = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .collection('chat_messages')
          .orderBy('created_at_client', descending: true)
          .limit(80)
          .get();

      for (final doc in snap.docs) {
        final data = doc.data();
        final text = (data['text'] ?? '').toString();
        final attachmentUrl = (data['attachment_url'] ?? '').toString();
        final senderRole = (data['sender_role'] ?? '').toString().trim();
        if (senderRole != 'admin' &&
            senderRole != 'system' &&
            senderRole != 'merchant') {
          continue;
        }

        final body = '$text\n$attachmentUrl';
        if (method == 'Wallet') {
          final bodyDigits = _digitsOnly(body);
          if (targetDigits.isNotEmpty &&
              bodyDigits.isNotEmpty &&
              bodyDigits.contains(targetDigits)) {
            return true;
          }
          if (text.contains('رقم المحفظة') && bodyDigits.length >= 6) {
            return true;
          }
          continue;
        }

        final bodyToken = _normalizedToken(body);
        if (targetToken.isNotEmpty &&
            bodyToken.isNotEmpty &&
            bodyToken.contains(targetToken)) {
          return true;
        }
        if (bodyToken.contains('binancepayid') ||
            bodyToken.contains('binanceid')) {
          return true;
        }
      }
    } catch (_) {}

    return false;
  }

  Future<void> _maybeInjectPaymentTargetAfterDelay({
    required String orderId,
  }) async {
    final trimmedOrderId = orderId.trim();
    if (trimmedOrderId.isEmpty) return;
    if (_paymentFallbackDone.contains(trimmedOrderId)) return;

    final now = DateTime.now();
    final previousAttempt = _paymentFallbackAttemptAt[trimmedOrderId];
    if (previousAttempt != null &&
        now.difference(previousAttempt) < const Duration(seconds: 15)) {
      return;
    }
    _paymentFallbackAttemptAt[trimmedOrderId] = now;

    try {
      final orderRef = FirebaseFirestore.instance
          .collection('orders')
          .doc(trimmedOrderId);
      final orderSnap = await orderRef.get();
      final data = orderSnap.data() ?? <String, dynamic>{};
      final status = (data['status'] ?? '').toString().trim();
      final actualMethod = (data['method'] ?? '').toString().trim();

      if (status != 'pending_payment') return;
      // Wallet number is now sent manually by support only.
      if (actualMethod == 'Wallet') return;
      if (actualMethod != 'Binance Pay') return;

      var target = (data['payment_target'] ?? '').toString().trim();
      if (actualMethod == 'Binance Pay' && target.isEmpty) {
        target = (data['binance_id'] ?? '').toString().trim();
      }

      if (target.isEmpty) {
        final fetched = await _fetchPaymentTargetsFromFirebase();
        target = actualMethod == 'Wallet' ? fetched.wallet : fetched.binance;
      }

      if (target.trim().isEmpty) return;
      final alreadySent = await _hasPaymentInstructionMessage(
        orderId: trimmedOrderId,
        method: actualMethod,
        target: target,
      );
      if (alreadySent) {
        _paymentFallbackDone.add(trimmedOrderId);
        return;
      }

      final messageText = actualMethod == 'Wallet'
          ? 'رقم المحفظة للدفع: $target'
          : 'Binance Pay ID: $target';

      await OrderChatService.addMessage(
        orderId: trimmedOrderId,
        senderRole: 'system',
        text: messageText,
        sendPushNotification: false,
      );
      await orderRef.set({
        'payment_target': target,
        if (actualMethod == 'Binance Pay') 'binance_id': target,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _paymentFallbackDone.add(trimmedOrderId);
    } catch (_) {}
  }

  void _schedulePaymentFallbackForOrder(
    Map<String, dynamic> orderData,
    String orderId,
  ) {
    final trimmedOrderId = orderId.trim();
    if (trimmedOrderId.isEmpty) return;

    final method = (orderData['method'] ?? '').toString().trim();
    final status = (orderData['status'] ?? '').toString().trim();
    final shouldRun = status == 'pending_payment' && method == 'Binance Pay';

    if (!shouldRun) {
      _paymentFallbackTimers.remove(trimmedOrderId)?.cancel();
      return;
    }
    if (_paymentFallbackDone.contains(trimmedOrderId)) return;
    if (_paymentFallbackTimers.containsKey(trimmedOrderId)) return;

    _paymentFallbackTimers[trimmedOrderId] = Timer(
      const Duration(seconds: 5),
      () {
        _paymentFallbackTimers.remove(trimmedOrderId);
        unawaited(_maybeInjectPaymentTargetAfterDelay(orderId: trimmedOrderId));
      },
    );
  }

  void _showFinalStatusToastOnce({
    required String orderId,
    required String status,
  }) {
    if (!mounted) return;
    final trimmedOrderId = orderId.trim();
    final trimmedStatus = status.trim();
    final orderIdSuffix = trimmedOrderId.isEmpty
        ? ''
        : ' (ID: $trimmedOrderId)';
    String message;
    IconData icon;
    Color color;
    if (trimmedStatus == 'completed') {
      message = 'تم تنفيذ طلبك بنجاح ✅$orderIdSuffix';
      icon = Icons.check_circle;
      color = Colors.green;
    } else if (trimmedStatus == 'rejected') {
      message = 'تم رفض طلبك ❌$orderIdSuffix';
      icon = Icons.cancel;
      color = Colors.red;
    } else {
      return;
    }

    TopSnackBar.show(
      context,
      message,
      backgroundColor: color,
      textColor: Colors.white,
      icon: icon,
      dedupeKey: 'user_order_status:$trimmedOrderId:$trimmedStatus',
      dedupeDuration: const Duration(hours: 24),
    );
  }

  void _closeChatForFinalStatus({
    required String orderId,
    required String status,
  }) {
    if (!mounted || _finalStatusCloseTriggered) return;
    _finalStatusCloseTriggered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _showFinalStatusToastOnce(orderId: orderId, status: status);
      final trimmedOrderId = orderId.trim();
      final args = <String, dynamic>{'whatsapp': widget.whatsapp};
      if (trimmedOrderId.isNotEmpty) {
        args['order_id'] = trimmedOrderId;
      }
      AppNavigator.pushNamedAndRemoveUntil(
        context,
        '/orders',
        (_) => false,
        arguments: args,
      );
    });
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
    final trimmedOrderId = orderId.trim();
    if (trimmedOrderId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(trimmedOrderId)
          .set({
            'status': 'cancelled',
            'cancelled_at': FieldValue.serverTimestamp(),
            'cancelled_by': 'user',
            'video_link': null,
            'video_link_removed_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      await _registerCancellationForCurrentUser();
      if (!mounted) return;
      TopSnackBar.show(
        context,
        'تم إلغاء الطلب',
        backgroundColor: Colors.redAccent,
        textColor: Colors.white,
        icon: Icons.cancel,
        dedupeKey: 'user_order_status:$trimmedOrderId:cancelled',
        dedupeDuration: const Duration(hours: 24),
      );
    } catch (_) {
      if (!mounted) return;
      TopSnackBar.show(
        context,
        'تعذر إلغاء الطلب، حاول لاحقاً',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
        icon: Icons.error_outline,
      );
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
    } catch (_) {}
  }

  String _chatDisabledHint({
    required String status,
    required bool supportedType,
  }) {
    if (!supportedType) {
      return 'هذا النوع من الطلبات لا يدعم الشات.';
    }
    if (status == 'completed') {
      return 'تم إغلاق الشات لأن الطلب مكتمل ✅';
    }
    if (status == 'rejected') {
      return 'تم إغلاق الشات لأن الطلب مرفوض ❌';
    }
    if (status == 'cancelled') {
      return 'تم إغلاق الشات لأن الطلب ملغي.';
    }
    if (status == 'pending_payment') {
      return 'يمكنك إرسال إثبات الدفع أو أي تفاصيل عبر الشات.';
    }
    return 'الشات غير متاح حالياً لهذا الطلب.';
  }

  String _buildOrderLabel(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    bool includeDate = true,
  }) {
    final data = doc.data();
    final status = (data['status'] ?? '').toString().trim();
    final productType = (data['product_type'] ?? 'tiktok').toString().trim();
    final createdAt = data['created_at'];

    String productLabel;
    if (productType == 'game') {
      productLabel = 'شحن ألعاب';
    } else if (productType == 'tiktok_promo') {
      productLabel = 'ترويج فيديو';
    } else {
      productLabel = 'شحن تيك توك';
    }

    String createdLabel = '';
    if (includeDate && createdAt is Timestamp) {
      final dt = createdAt.toDate().toLocal();
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      createdLabel = ' - $y/$m/$d $hh:$mm';
    }

    final shortId = doc.id.length >= 6 ? doc.id.substring(0, 6) : doc.id;
    final statusLabel = OrderStatusHelper.label(status);
    return '#$shortId - $productLabel - $statusLabel$createdLabel';
  }

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('orders')
        .where('user_whatsapp', isEqualTo: widget.whatsapp)
        .orderBy('created_at', descending: true)
        .limit(40)
        .snapshots();

    return Scaffold(
      appBar: const GlassAppBar(title: Text('شات الطلبات'), centerTitle: true),
      body: Stack(
        children: [
          const SnowBackground(),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'حدث خطأ أثناء تحميل الشات',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontFamily: 'Cairo',
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final allDocs = snapshot.data!.docs;
              final trackedOrderId =
                  (_selectedOrderId ?? widget.initialOrderId ?? '').trim();
              if (trackedOrderId.isNotEmpty) {
                for (final doc in allDocs) {
                  if (doc.id != trackedOrderId) continue;
                  final status = (doc.data()['status'] ?? '').toString().trim();
                  if (_isFinalOrderStatus(status)) {
                    _closeChatForFinalStatus(
                      orderId: trackedOrderId,
                      status: status,
                    );
                  }
                  break;
                }
              }

              final docs = allDocs
                  .where((doc) {
                    final data = doc.data();
                    final productType = (data['product_type'] ?? 'tiktok')
                        .toString()
                        .trim();
                    final status = (data['status'] ?? '').toString().trim();
                    final isFinalStatus = _isFinalOrderStatus(status);
                    return _isChatSupportedType(productType) && !isFinalStatus;
                  })
                  .toList(growable: false);
              if (docs.isEmpty) {
                return Center(
                  child: GlassCard(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    child: const Text(
                      'لا يوجد طلبات شحن تدعم الشات حالياً.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                  ),
                );
              }

              if (_isPinnedToSingleOrder) {
                final pinnedOrderId = trackedOrderId;
                final pinnedDoc = docs
                    .where((d) => d.id == pinnedOrderId)
                    .fold<QueryDocumentSnapshot<Map<String, dynamic>>?>(
                      null,
                      (prev, doc) => prev ?? doc,
                    );
                if (pinnedDoc == null) {
                  return Center(
                    child: GlassCard(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      child: const Text(
                        'المحادثة غير متاحة لهذا الطلب حالياً.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'Cairo'),
                      ),
                    ),
                  );
                }

                final data = pinnedDoc.data();
                final status = (data['status'] ?? '').toString().trim();
                final productType = (data['product_type'] ?? 'tiktok')
                    .toString()
                    .trim();
                final bool supportedType = _isChatSupportedType(productType);
                final bool chatEnabled =
                    supportedType && _isExecutionChatOpen(status);
                _schedulePaymentFallbackForOrder(data, pinnedDoc.id);

                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GlassCard(
                        margin: EdgeInsets.zero,
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _buildOrderLabel(pinnedDoc),
                          style: TextStyle(
                            color: TTColors.textWhite,
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: OrderChatPanel(
                          orderId: pinnedDoc.id,
                          isAdmin: false,
                          userDisplayName: widget.name,
                          userWhatsapp: widget.whatsapp,
                          fullScreen: true,
                          chatEnabled: chatEnabled,
                          disabledHint: _chatDisabledHint(
                            status: status,
                            supportedType: supportedType,
                          ),
                        ),
                      ),
                      if (_canCancelOrder(status)) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                          ),
                          onPressed: () =>
                              _confirmCancel(context, pinnedDoc.id),
                          icon: const Icon(Icons.cancel),
                          label: const Text(
                            'إلغاء الطلب',
                            style: TextStyle(fontFamily: 'Cairo'),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }

              final bool hasSelection = docs.any(
                (d) => d.id == _selectedOrderId,
              );
              final activeOrderId = hasSelection
                  ? _selectedOrderId!
                  : docs.first.id;
              final activeOrderData = docs
                  .firstWhere((d) => d.id == activeOrderId)
                  .data();
              _schedulePaymentFallbackForOrder(activeOrderData, activeOrderId);
              final activeStatus = (activeOrderData['status'] ?? '')
                  .toString()
                  .trim();
              final activeProductType =
                  (activeOrderData['product_type'] ?? 'tiktok')
                      .toString()
                      .trim();
              final bool isSupportedType = _isChatSupportedType(
                activeProductType,
              );
              final bool chatEnabled =
                  isSupportedType && _isExecutionChatOpen(activeStatus);
              if (!hasSelection && _selectedOrderId != activeOrderId) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(() => _selectedOrderId = activeOrderId);
                });
              }

              final width = MediaQuery.of(context).size.width;
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: width > 900 ? 760 : double.infinity,
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(14),
                    children: [
                      GlassCard(
                        margin: EdgeInsets.zero,
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'اختر الطلب للمحادثة',
                              style: TextStyle(
                                color: TTColors.textWhite,
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: activeOrderId,
                              selectedItemBuilder: (context) {
                                return docs
                                    .map((doc) {
                                      return Align(
                                        alignment:
                                            AlignmentDirectional.centerStart,
                                        child: Text(
                                          _buildOrderLabel(
                                            doc,
                                            includeDate: false,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          softWrap: false,
                                          style: const TextStyle(
                                            fontFamily: 'Cairo',
                                          ),
                                        ),
                                      );
                                    })
                                    .toList(growable: false);
                              },
                              items: docs
                                  .map((doc) {
                                    return DropdownMenuItem<String>(
                                      value: doc.id,
                                      child: SizedBox(
                                        width: double.infinity,
                                        child: Text(
                                          _buildOrderLabel(doc),
                                          maxLines: 1,
                                          softWrap: false,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontFamily: 'Cairo',
                                          ),
                                        ),
                                      ),
                                    );
                                  })
                                  .toList(growable: false),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _selectedOrderId = value);
                              },
                              decoration: const InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      OrderChatPanel(
                        orderId: activeOrderId,
                        isAdmin: false,
                        userDisplayName: widget.name,
                        userWhatsapp: widget.whatsapp,
                        maxHeight: 420,
                        chatEnabled: chatEnabled,
                        disabledHint: _chatDisabledHint(
                          status: activeStatus,
                          supportedType: isSupportedType,
                        ),
                      ),
                      if (_canCancelOrder(activeStatus)) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                          ),
                          onPressed: () =>
                              _confirmCancel(context, activeOrderId),
                          icon: const Icon(Icons.cancel),
                          label: const Text(
                            'إلغاء الطلب',
                            style: TextStyle(fontFamily: 'Cairo'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
