// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

import 'cloudflare_notify_service.dart';

class OrderChatService {
  OrderChatService._();

  static CollectionReference<Map<String, dynamic>> _messagesRef(
    String orderId,
  ) {
    return FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .collection('chat_messages');
  }

  static Future<void> addSystemMessage({
    required String orderId,
    required String text,
  }) async {
    await addMessage(
      orderId: orderId,
      senderRole: 'system',
      text: text,
      sendPushNotification: false,
    );
  }

  static Future<void> addMessage({
    required String orderId,
    required String senderRole,
    String senderName = '',
    String text = '',
    String attachmentType = '',
    String attachmentUrl = '',
    String attachmentPath = '',
    String attachmentLabel = '',
    Timestamp? attachmentExpiresAt,
    String recipientUserWhatsapp = '',
    bool sendPushNotification = true,
  }) async {
    final normalizedOrderId = orderId.trim();
    if (normalizedOrderId.isEmpty) return;

    final normalizedText = text.trim();
    final normalizedAttachmentType = attachmentType.trim().toLowerCase();
    final normalizedAttachmentUrl = attachmentUrl.trim();
    final normalizedAttachmentPath = attachmentPath.trim();
    final normalizedAttachmentLabel = attachmentLabel.trim();

    if (normalizedText.isEmpty && normalizedAttachmentUrl.isEmpty) return;

    final role = senderRole.trim().toLowerCase();
    final safeRole = (role == 'admin' ||
            role == 'user' ||
            role == 'system' ||
            role == 'merchant')
        ? role
        : 'system';
    final safeSenderName = senderName.trim();

    final nowClient = Timestamp.fromDate(DateTime.now());
    final payload = <String, dynamic>{
      'text': normalizedText,
      'sender_role': safeRole,
      'sender_name': safeSenderName,
      'send_push_notification': sendPushNotification,
      'created_at': FieldValue.serverTimestamp(),
      'created_at_client': nowClient,
      if (normalizedAttachmentType.isNotEmpty)
        'attachment_type': normalizedAttachmentType,
      if (normalizedAttachmentUrl.isNotEmpty)
        'attachment_url': normalizedAttachmentUrl,
      if (normalizedAttachmentPath.isNotEmpty)
        'attachment_path': normalizedAttachmentPath,
      if (normalizedAttachmentLabel.isNotEmpty)
        'attachment_label': normalizedAttachmentLabel,
      ...?attachmentExpiresAt == null
          ? null
          : {'attachment_expires_at': attachmentExpiresAt},
    };

    await _messagesRef(normalizedOrderId).add(payload);

    final preview = normalizedText.isNotEmpty
        ? normalizedText
        : _attachmentPreview(normalizedAttachmentType);
    final orderRef = FirebaseFirestore.instance
        .collection('orders')
        .doc(normalizedOrderId);
    await orderRef.set({
      'last_chat_message': preview,
      'last_chat_sender_role': safeRole,
      'last_chat_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!sendPushNotification || safeRole == 'system') {
      return;
    }

    await _notifyChatRecipientsWithRetry(
      orderRef: orderRef,
      normalizedOrderId: normalizedOrderId,
      safeRole: safeRole,
      safeSenderName: safeSenderName,
      messagePreview: preview,
      recipientUserWhatsapp: recipientUserWhatsapp,
    );
  }

  static Future<void> _notifyChatRecipientsWithRetry({
    required DocumentReference<Map<String, dynamic>> orderRef,
    required String normalizedOrderId,
    required String safeRole,
    required String safeSenderName,
    required String messagePreview,
    required String recipientUserWhatsapp,
  }) async {
    try {
      final knownRecipientWhatsapp = recipientUserWhatsapp.trim();
      var userWhatsapp = knownRecipientWhatsapp;
      var merchantWhatsapp = '';
      var orderName = '';
      var merchantName = '';

      // Use order snapshot as fallback only when recipient whatsapp is missing,
      // or when we need a better display name for admin notification.
      if (userWhatsapp.isEmpty || safeSenderName.isEmpty || safeRole == 'user') {
        try {
          final orderSnap = await orderRef.get();
          final orderData = orderSnap.data() ?? <String, dynamic>{};
          if (userWhatsapp.isEmpty) {
            userWhatsapp =
                (orderData['user_whatsapp'] ?? orderData['whatsapp'] ?? '')
                    .toString()
                    .trim();
          }
          merchantWhatsapp = (orderData['merchant_whatsapp'] ?? '')
              .toString()
              .trim();
          merchantName = (orderData['merchant_name'] ?? '').toString().trim();
          orderName = (orderData['name'] ?? '').toString().trim();

          if (merchantWhatsapp.isEmpty && safeRole == 'user') {
            final merchantId = (orderData['merchant_id'] ?? '')
                .toString()
                .trim();
            if (merchantId.isNotEmpty) {
              try {
                final merchantSnap = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(merchantId)
                    .get();
                final merchantData = merchantSnap.data() ?? <String, dynamic>{};
                merchantWhatsapp =
                    (merchantData['merchant_whatsapp'] ??
                            merchantData['whatsapp'] ??
                            '')
                        .toString()
                        .trim();
                if (merchantName.isEmpty) {
                  merchantName = (merchantData['name'] ?? '')
                      .toString()
                      .trim();
                }
              } catch (_) {
                // Keep notify path alive when merchant profile lookup fails.
              }
            }
          }
        } catch (_) {
          // Keep notify path alive using available local data.
        }
      }
      final displayName = safeSenderName.isNotEmpty
          ? safeSenderName
          : (orderName.isNotEmpty ? orderName : null);
      final merchantDisplayName = safeSenderName.isNotEmpty
          ? safeSenderName
          : (merchantName.isNotEmpty ? merchantName : null);

      Future<bool> sendOnce() async {
        if (safeRole == 'admin' || safeRole == 'merchant') {
          if (userWhatsapp.isEmpty) return false;
          return CloudflareNotifyService.notifyUserChatMessage(
            orderId: normalizedOrderId,
            userWhatsapp: userWhatsapp,
            messagePreview: messagePreview,
            senderRole: safeRole,
          );
        }
        if (safeRole == 'user') {
          if (merchantWhatsapp.isNotEmpty) {
            final merchantNotified =
                await CloudflareNotifyService.notifyMerchantChatMessage(
                  orderId: normalizedOrderId,
                  merchantWhatsapp: merchantWhatsapp,
                  userName: displayName,
                  messagePreview: messagePreview,
                );
            if (merchantNotified) return true;
          }
          return CloudflareNotifyService.notifyAdminsChatMessage(
            orderId: normalizedOrderId,
            userName: merchantDisplayName ?? displayName,
            messagePreview: messagePreview,
          );
        }
        return true;
      }

      const maxAttempts = 3;
      for (var i = 0; i < maxAttempts; i++) {
        final success = await sendOnce().timeout(
          const Duration(seconds: 10),
          onTimeout: () => false,
        );
        if (success) return;
        if (i < maxAttempts - 1) {
          await Future<void>.delayed(Duration(milliseconds: 500 * (i + 1)));
        }
      }

      if (kDebugMode) {
        log(
          'OrderChatService: chat push retries exhausted for order=$normalizedOrderId role=$safeRole',
        );
      }
    } catch (error, stack) {
      if (kDebugMode) {
        log(
          'OrderChatService: chat push notify failed',
          error: error,
          stackTrace: stack,
        );
      }
    }
  }

  static String _attachmentPreview(String type) {
    if (type == 'image') return '📷 صورة مرفقة';
    if (type == 'link') return '🔗 رابط مرفق';
    return '📎 مرفق';
  }
}
