// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/app_navigator.dart';
import '../../core/order_status.dart';
import '../../core/tt_colors.dart';
import '../../models/game_package.dart';
import '../../services/cloudflare_notify_service.dart';
import '../../services/order_chat_service.dart';
import '../../utils/url_sanitizer.dart';
import '../../widgets/glass_app_bar.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/order_chat_panel.dart';
import '../../widgets/snow_background.dart';
import '../../widgets/top_snackbar.dart';

class OrderChatScreen extends StatefulWidget {
  final String orderId;
  final String viewerRole;
  final String viewerName;
  final String fallbackUserWhatsapp;

  const OrderChatScreen({
    super.key,
    required this.orderId,
    required this.viewerRole,
    this.viewerName = '',
    this.fallbackUserWhatsapp = '',
  });

  @override
  State<OrderChatScreen> createState() => _OrderChatScreenState();
}

class _OrderChatScreenState extends State<OrderChatScreen> {
  bool _finalStatusExitTriggered = false;
  bool _isSendingDeliveryLink = false;

  bool get _isAdmin => widget.viewerRole.trim().toLowerCase() == 'admin';
  bool get _isMerchant => widget.viewerRole.trim().toLowerCase() == 'merchant';
  bool get _isUser => !_isAdmin && !_isMerchant;

  bool _isSupportedChatType(String productType) {
    return productType == 'tiktok' ||
        productType == 'game' ||
        productType == 'tiktok_promo';
  }

  bool _isExecutionChatOpen(String status) {
    return status == 'pending_payment' ||
        status == 'pending_review' ||
        status == 'processing';
  }

  String _productTitle(Map<String, dynamic> data) {
    final productType = (data['product_type'] ?? 'tiktok').toString().trim();
    if (productType == 'game') {
      final gameKey = (data['game'] ?? '').toString().trim();
      final packageLabel = (data['package_label'] ?? '').toString().trim();
      final gameLabel = GamePackage.gameLabel(gameKey);
      if (packageLabel.isEmpty) return gameLabel;
      return '$gameLabel - $packageLabel';
    }
    if (productType == 'tiktok_promo') return 'ترويج فيديو تيك توك';
    final points = (data['points'] ?? '').toString().trim();
    return points.isEmpty ? 'شحن تيك توك' : '$points نقطة';
  }

  String _counterpartyLabel(Map<String, dynamic> data) {
    if (_isAdmin) {
      final userName = (data['name'] ?? '').toString().trim();
      return userName.isEmpty ? 'العميل' : userName;
    }
    if (_isMerchant) {
      final userName = (data['name'] ?? '').toString().trim();
      return userName.isEmpty ? 'العميل' : userName;
    }
    final merchantName = (data['merchant_name'] ?? '').toString().trim();
    if (merchantName.isNotEmpty) return merchantName;
    return 'التاجر';
  }

  String _viewerBadgeLabel() {
    if (_isAdmin) return 'الدعم';
    if (_isMerchant) return 'التاجر';
    return 'المستخدم';
  }

  String _disabledHint({required String status, required bool supportedType}) {
    if (!supportedType) return 'هذا النوع من الطلبات لا يدعم المحادثة.';
    if (status == 'completed') {
      return 'الطلب مكتمل. يمكنك مراجعة الرسائل السابقة فقط.';
    }
    if (status == 'rejected') {
      return 'الطلب مرفوض. المحادثة متاحة للقراءة فقط.';
    }
    if (status == 'cancelled') {
      return 'الطلب ملغي. المحادثة متاحة للقراءة فقط.';
    }
    if (status == 'pending_payment') {
      return _isAdmin || _isMerchant
          ? 'بانتظار الدفع. يمكن متابعة الرسائل الحالية فقط.'
          : 'يمكنك إرسال إثبات الدفع أو الاستفسار هنا.';
    }
    return 'المحادثة غير متاحة حالياً لهذا الطلب.';
  }

  String _resolvedViewerName() {
    final trimmed = widget.viewerName.trim();
    if (trimmed.isNotEmpty) return trimmed;
    if (_isAdmin) return 'الدعم';
    if (_isMerchant) return 'التاجر';
    return 'المستخدم';
  }

  bool _isFinalStatus(String status) {
    return status == 'completed' ||
        status == 'rejected' ||
        status == 'cancelled';
  }

  bool _canSendDeliveryLoginLink(Map<String, dynamic> data) {
    if (!_isAdmin && !_isMerchant) return false;
    final productType = (data['product_type'] ?? 'tiktok').toString().trim();
    if (productType != 'tiktok') return false;
    final status = (data['status'] ?? '').toString().trim();
    if (_isFinalStatus(status)) return false;

    if (_isAdmin) return true;

    final tiktokChargeMode = (data['tiktok_charge_mode'] ?? '')
        .toString()
        .trim();
    return tiktokChargeMode == 'link' || tiktokChargeMode.isEmpty;
  }

  Timestamp _newDeliveryExpiryTimestamp() {
    return Timestamp.fromDate(DateTime.now().add(const Duration(seconds: 20)));
  }

  Future<void> _markOrderAsProcessingAndClearLegacyDelivery() async {
    await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .set({
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

  Future<void> _notifyUserProcessingStatus(String userWhatsapp) async {
    if (userWhatsapp.trim().isEmpty) return;
    unawaited(
      CloudflareNotifyService.notifyUserOrderStatus(
        userWhatsapp: userWhatsapp.trim(),
        orderId: widget.orderId,
        status: 'processing',
      ),
    );
  }

  Future<void> _sendDeliveryLoginLinkViaChat(Map<String, dynamic> data) async {
    final status = (data['status'] ?? '').toString().trim();
    if (_isFinalStatus(status)) {
      if (!mounted) return;
      TopSnackBar.show(
        context,
        "لا يمكن تعديل بيانات طلب مكتمل أو مرفوض",
        backgroundColor: Colors.red,
        textColor: Colors.white,
        icon: Icons.block,
      );
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

    linkCtrl.dispose();
    noteCtrl.dispose();

    if (!mounted || result == null) return;

    final safeLink = ensureHttps(result.$1);
    final note = result.$2;
    final userWhatsapp = (data['user_whatsapp'] ?? data['whatsapp'] ?? '')
        .toString()
        .trim();

    setState(() => _isSendingDeliveryLink = true);
    try {
      await OrderChatService.addMessage(
        orderId: widget.orderId,
        senderRole: _isAdmin ? 'admin' : 'merchant',
        senderName: _isMerchant ? _resolvedViewerName() : '',
        text: note,
        attachmentType: 'link',
        attachmentUrl: safeLink,
        attachmentLabel: 'لينك تسجيل الدخول',
        attachmentExpiresAt: _newDeliveryExpiryTimestamp(),
        recipientUserWhatsapp: userWhatsapp,
      );
      await _markOrderAsProcessingAndClearLegacyDelivery();
      await _notifyUserProcessingStatus(userWhatsapp);
      if (!mounted) return;
      TopSnackBar.show(
        context,
        "تم إرسال لينك تسجيل الدخول داخل المحادثة ✅",
        backgroundColor: Colors.green,
        textColor: Colors.white,
        icon: Icons.check_circle,
      );
    } catch (e) {
      if (!mounted) return;
      TopSnackBar.show(
        context,
        "حدث خطأ أثناء إرسال الرابط",
        backgroundColor: Colors.red,
        textColor: Colors.white,
        icon: Icons.error_outline,
      );
    } finally {
      if (mounted) {
        setState(() => _isSendingDeliveryLink = false);
      }
    }
  }

  Widget _buildExecutionActions(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    if (!_canSendDeliveryLoginLink(data)) return const SizedBox.shrink();
    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'إجراءات التنفيذ',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSendingDeliveryLink
                  ? null
                  : () => _sendDeliveryLoginLinkViaChat(data),
              icon: _isSendingDeliveryLink
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.link),
              label: const Text(
                'إرسال لينك تسجيل الدخول',
                style: TextStyle(fontFamily: 'Cairo'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateUserBackToOrders(String userWhatsapp) {
    if (!mounted || _finalStatusExitTriggered) return;
    _finalStatusExitTriggered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final args = <String, dynamic>{
        'whatsapp': userWhatsapp.trim().isEmpty
            ? widget.fallbackUserWhatsapp.trim()
            : userWhatsapp.trim(),
      };
      AppNavigator.pushNamedAndRemoveUntil(
        context,
        '/orders',
        (_) => false,
        arguments: args,
      );
    });
  }

  Widget _buildHeader(
    BuildContext context,
    Map<String, dynamic> data, {
    required bool chatEnabled,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = (data['status'] ?? '').toString().trim();
    final productTitle = _productTitle(data);
    final counterparty = _counterpartyLabel(data);
    final price = (data['price'] ?? '').toString().trim();
    final statusColor = OrderStatusHelper.color(status);
    final chatPillColor = chatEnabled ? Colors.green : colorScheme.outline;

    Widget pill({
      required IconData icon,
      required String label,
      required Color color,
      required Color textColor,
    }) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withAlpha(26),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withAlpha(100)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productTitle,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'محادثة مباشرة خاصة بالطلب #${widget.orderId}',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontFamily: 'Cairo',
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(28),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: statusColor.withAlpha(90)),
                ),
                child: Text(
                  OrderStatusHelper.label(status),
                  style: TextStyle(
                    color: statusColor,
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              pill(
                icon: Icons.person_outline,
                label: 'الطرف المقابل: $counterparty',
                color: colorScheme.primary,
                textColor: colorScheme.onSurface,
              ),
              pill(
                icon: Icons.shield_outlined,
                label: 'أنت: ${_viewerBadgeLabel()}',
                color: TTColors.goldAccent,
                textColor: colorScheme.onSurface,
              ),
              pill(
                icon: chatEnabled ? Icons.forum_rounded : Icons.lock_outline,
                label: chatEnabled ? 'المحادثة مفتوحة' : 'قراءة فقط',
                color: chatPillColor,
                textColor: colorScheme.onSurface,
              ),
            ],
          ),
          if (price.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(color: colorScheme.outline.withAlpha(60), height: 1),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                if (price.isNotEmpty)
                  Text(
                    'قيمة الطلب: $price جنيه',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontFamily: 'Cairo',
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: const GlassAppBar(title: Text('محادثة الطلب')),
      body: Stack(
        children: [
          const SnowBackground(),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .doc(widget.orderId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: GlassCard(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'تعذر تحميل المحادثة',
                      style: TextStyle(
                        color: colorScheme.error,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final data = snapshot.data?.data();
              if (data == null || data.isEmpty) {
                return Center(
                  child: GlassCard(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    child: const Text(
                      'الطلب غير متاح حالياً.',
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                  ),
                );
              }

              final resolvedUserWhatsapp =
                  (data['user_whatsapp'] ?? data['whatsapp'] ?? '')
                      .toString()
                      .trim();
              final status = (data['status'] ?? '').toString().trim();
              if (_isUser && (status == 'cancelled' || status == 'rejected')) {
                _navigateUserBackToOrders(resolvedUserWhatsapp);
              }
              final productType = (data['product_type'] ?? 'tiktok')
                  .toString()
                  .trim();
              final supportedType = _isSupportedChatType(productType);
              final chatEnabled = supportedType && _isExecutionChatOpen(status);
              final userDisplayName = (data['name'] ?? '').toString().trim();

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                    child: _buildHeader(
                      context,
                      data,
                      chatEnabled: chatEnabled,
                    ),
                  ),
                  if (_canSendDeliveryLoginLink(data))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                      child: _buildExecutionActions(context, data),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: OrderChatPanel(
                        orderId: widget.orderId,
                        isAdmin: _isAdmin,
                        isMerchant: _isMerchant,
                        userDisplayName: userDisplayName.isEmpty
                            ? 'المستخدم'
                            : userDisplayName,
                        adminDisplayName: _resolvedViewerName(),
                        userWhatsapp: resolvedUserWhatsapp.isEmpty
                            ? widget.fallbackUserWhatsapp
                            : resolvedUserWhatsapp,
                        fullScreen: true,
                        chatEnabled: chatEnabled,
                        disabledHint: _disabledHint(
                          status: status,
                          supportedType: supportedType,
                        ),
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
