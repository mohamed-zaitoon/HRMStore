// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/order_status.dart';
import 'remote_config_service.dart';

class CloudflareNotifyService {
  CloudflareNotifyService._();

  static const String _workerUrlDefine = String.fromEnvironment(
    'CF_NOTIFY_URL',
    defaultValue: '',
  );
  static const String _workerTokenDefine = String.fromEnvironment(
    'CF_NOTIFY_TOKEN',
    defaultValue: '',
  );

  // EN: Sends new-order notification to admin endpoint.
  // AR: ترسل إشعار الطلب الجديد لنقطة نهاية الأدمن.
  static Future<bool> notifyAdminsNewOrder({
    required String orderId,
    required Map<String, dynamic> order,
  }) async {
    final title = 'هناك طلب شحن جديد';
    final methodLabel = _paymentMethodLabel((order['method'] ?? '').toString());
    final label = _orderLabel(order);
    final who = (order['name'] ?? '').toString().trim();
    final body = [
      'طلب جديد من ${who.isEmpty ? 'عميل' : who}',
      if (label.isNotEmpty) label,
      if (methodLabel.isNotEmpty) 'وسيلة الدفع: $methodLabel',
    ].join(' - ');

    return _send(
      title: title,
      message: body,
      data: <String, dynamic>{'type': 'new_order', 'order_id': orderId},
      targetExternalIds: _adminExternalIds(),
      fallbackRole: 'admin',
    );
  }

  // EN: Sends receipt-uploaded notification to admin endpoint.
  // AR: ترسل إشعار رفع الإيصال لنقطة نهاية الأدمن.
  static Future<bool> notifyAdminsReceiptUploaded({
    required String orderId,
    required String userWhatsapp,
    String? userName,
  }) async {
    final who = (userName ?? '').trim();
    final message = who.isNotEmpty
        ? 'تم رفع إيصال جديد من $who'
        : 'تم رفع إيصال جديد من مستخدم';
    return _send(
      title: 'إيصال جديد',
      message: message,
      data: <String, dynamic>{
        'type': 'receipt_uploaded',
        'order_id': orderId,
        'user_whatsapp': _normalizeWhatsapp(userWhatsapp),
      },
      targetExternalIds: _adminExternalIds(),
      fallbackRole: 'admin',
    );
  }

  // EN: Sends order-status notification to the user endpoint.
  // AR: ترسل إشعار حالة الطلب لنقطة نهاية المستخدم.
  static Future<bool> notifyUserOrderStatus({
    required String userWhatsapp,
    required String orderId,
    required String status,
    String? rejectionReason,
  }) async {
    final normalized = _normalizeWhatsapp(userWhatsapp);
    if (normalized.isEmpty) return false;

    final title = _userOrderStatusTitle(status);
    final message = _userOrderStatusBody(
      status: status,
      rejectionReason: rejectionReason,
    );
    return _send(
      title: title,
      message: message,
      data: <String, dynamic>{
        'type': 'order_status',
        'order_id': orderId,
        'status': status,
      },
      targetExternalIds: _externalIdsForWhatsapp(normalized, isAdmin: false),
      fallbackRole: 'user',
      fallbackWhatsapp: normalized,
    );
  }

  // EN: Sends new code-request notification to admin endpoint.
  // AR: ترسل إشعار طلب كود جديد لنقطة نهاية الأدمن.
  static Future<bool> notifyAdminsCodeRequest({
    required String requestId,
    required String name,
    required String whatsapp,
    required String tiktok,
  }) async {
    final body = [
      'طلب من ${name.trim().isEmpty ? 'عميل' : name.trim()}',
      if (whatsapp.trim().isNotEmpty) 'واتساب: ${whatsapp.trim()}',
      if (tiktok.trim().isNotEmpty) 'تيك توك: ${tiktok.trim()}',
    ].join(' - ');
    return _send(
      title: _newPromoCodeRequestTitle(),
      message: body,
      data: <String, dynamic>{
        'type': 'ramadan_code_request',
        'request_id': requestId,
      },
      targetExternalIds: _adminExternalIds(),
      fallbackRole: 'admin',
    );
  }

  // EN: Sends sent-code notification to user endpoint.
  // AR: ترسل إشعار الكود المُرسل لنقطة نهاية المستخدم.
  static Future<bool> notifyUserPromoCodeSent({
    required String requestId,
    required String userWhatsapp,
    required String promoCode,
  }) async {
    final normalized = _normalizeWhatsapp(userWhatsapp);
    if (normalized.isEmpty || promoCode.trim().isEmpty) return false;
    final safeCode = promoCode.trim();

    return _send(
      title: _promoCodeSentTitle(),
      message: 'كودك: $safeCode',
      data: <String, dynamic>{
        'type': 'promo_code_sent',
        'request_id': requestId,
        'code': safeCode,
      },
      targetExternalIds: _externalIdsForWhatsapp(normalized, isAdmin: false),
      fallbackRole: 'user',
      fallbackWhatsapp: normalized,
    );
  }

  static Future<bool> _send({
    required String title,
    required String message,
    required Map<String, dynamic> data,
    required List<String> targetExternalIds,
    String fallbackRole = '',
    String fallbackWhatsapp = '',
  }) async {
    final enabled = _cloudflareEnabled;
    if (!enabled) return false;

    final endpoint = _workerUrl;
    if (endpoint.isEmpty) {
      if (kDebugMode) {
        log('Cloudflare notify skipped: worker url not configured');
      }
      return false;
    }

    final token = _workerToken;
    final ids = targetExternalIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList(growable: false);

    final role = fallbackRole.trim().toLowerCase();
    final normalizedWhatsapp = _normalizeWhatsapp(fallbackWhatsapp);
    final hasFallback = role == 'admin' || role == 'user';

    if (ids.isEmpty && !hasFallback) {
      if (kDebugMode) {
        log('Cloudflare notify skipped: empty targets');
      }
      return false;
    }

    final payload = <String, dynamic>{
      'title': title.trim(),
      'message': message.trim(),
      'data': data,
      if (ids.isNotEmpty) 'external_ids': ids,
      if (hasFallback) 'target_role': role,
      if (role == 'user' && normalizedWhatsapp.isNotEmpty)
        'target_whatsapp': normalizedWhatsapp,
    };

    try {
      final uri = Uri.parse(endpoint);
      final response = await http
          .post(
            uri,
            headers: <String, String>{
              'content-type': 'application/json',
              if (token.isNotEmpty) 'x-worker-token': token,
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (kDebugMode) {
          log('Cloudflare notify success (${response.statusCode})');
        }
        return true;
      }

      if (kDebugMode) {
        log(
          'Cloudflare notify failed (${response.statusCode}): ${response.body}',
        );
      }
      return false;
    } catch (error, stack) {
      if (kDebugMode) {
        log('Cloudflare notify error: $error', error: error, stackTrace: stack);
      }
      return false;
    }
  }

  static String _newPromoCodeRequestTitle() {
    return 'طلب كود خصم جديد';
  }

  static String _promoCodeSentTitle() {
    return 'تم ارسال كود الخصم لك 🎁';
  }

  static String get _workerUrl {
    final remote = RemoteConfigService.instance.cloudflareNotifyUrl;
    if (remote.isNotEmpty) return remote;
    return _workerUrlDefine.trim();
  }

  static String get _workerToken {
    final remote = RemoteConfigService.instance.cloudflareNotifyToken;
    if (remote.isNotEmpty) return remote;
    return _workerTokenDefine.trim();
  }

  static bool get _cloudflareEnabled {
    if (!RemoteConfigService.instance.cloudflareClientSenderEnabled) {
      return false;
    }
    final url = _workerUrl;
    if (url.isEmpty) return false;
    return RemoteConfigService.instance.cloudflareNotifyEnabled;
  }

  static List<String> _adminExternalIds() {
    final candidates = <String>{
      RemoteConfigService.instance.adminWhatsapp,
      RemoteConfigService.instance.cloudflareAdminWhatsapp,
    };

    return candidates
        .expand((raw) => _externalIdsForWhatsapp(raw, isAdmin: true))
        .toSet()
        .toList(growable: false);
  }

  static List<String> _externalIdsForWhatsapp(
    String rawWhatsapp, {
    required bool isAdmin,
  }) {
    final role = isAdmin ? 'admin' : 'user';
    final variants = _whatsappVariants(rawWhatsapp);
    return variants.map((v) => '$role:$v').toList(growable: false);
  }

  static List<String> _whatsappVariants(String value) {
    final digits = _normalizeWhatsapp(value);
    if (digits.isEmpty) return const <String>[];
    final set = <String>{digits};

    if (digits.length == 11 && digits.startsWith('0')) {
      set.add('2$digits');
    } else if (digits.length == 12 && digits.startsWith('20')) {
      set.add('0${digits.substring(2)}');
    }

    return set.toList(growable: false);
  }

  static String _paymentMethodLabel(String rawMethod) {
    final method = rawMethod.trim();
    if (method == 'Wallet') return 'محفظة';
    if (method == 'InstaPay') return 'InstaPay';
    if (method == 'Binance Pay') return 'Binance Pay';
    if (method == 'Points') return 'رصيد نقاط';
    return method;
  }

  static String _orderLabel(Map<String, dynamic> order) {
    final productType = (order['product_type'] ?? '').toString().trim();
    if (productType == 'game') {
      final packageLabel = (order['package_label'] ?? '').toString().trim();
      if (packageLabel.isNotEmpty) return packageLabel;
      return 'شحن لعبة';
    }
    if (productType == 'balance_topup') {
      final points = (order['balance_points_requested'] ?? '')
          .toString()
          .trim();
      if (points.isNotEmpty) return 'شحن رصيد $points نقطة';
      return 'شحن رصيد';
    }
    if (productType == 'tiktok_promo') {
      return 'ترويج فيديو تيك توك';
    }
    final points = (order['points'] ?? '').toString().trim();
    if (points.isNotEmpty) return '$points نقطة';
    return '';
  }

  static String _userOrderStatusTitle(String status) {
    switch (status) {
      case 'completed':
        return 'تم تنفيذ طلبك بنجاح ✅';
      case 'rejected':
        return 'تم رفض طلبك ❌';
      case 'cancelled':
        return 'تم إلغاء طلبك 🚫';
      case 'pending_review':
        return 'تم استلام إيصالك ⏳';
      case 'processing':
        return 'طلبك دخل مرحلة التنفيذ ⚙️';
      default:
        return 'تحديث على طلبك';
    }
  }

  static String _userOrderStatusBody({
    required String status,
    String? rejectionReason,
  }) {
    if (status == 'completed') {
      return 'تم تنفيذ طلبك بنجاح. شكراً لك.';
    }
    if (status == 'rejected') {
      final reason = (rejectionReason ?? '').trim();
      if (reason.isNotEmpty) {
        return 'تم رفض الطلب. السبب: $reason';
      }
      return 'تم رفض طلبك. سيتم التواصل معك عبر الواتساب.';
    }
    if (status == 'pending_review') {
      return 'تم استلام الإيصال وجارٍ المراجعة.';
    }
    if (status == 'processing') {
      return 'طلبك قيد التنفيذ الآن.';
    }
    if (status == 'cancelled') {
      return 'تم إلغاء الطلب.';
    }
    return 'حالة طلبك تغيّرت إلى: ${OrderStatusHelper.label(status)}';
  }

  static String _normalizeWhatsapp(String value) {
    if (value.trim().isEmpty) return '';
    final sb = StringBuffer();
    for (final rune in value.runes) {
      if (rune >= 0x0660 && rune <= 0x0669) {
        sb.writeCharCode(0x30 + (rune - 0x0660));
        continue;
      }
      if (rune >= 0x06F0 && rune <= 0x06F9) {
        sb.writeCharCode(0x30 + (rune - 0x06F0));
        continue;
      }
      sb.writeCharCode(rune);
    }
    return sb.toString().replaceAll(RegExp(r'[^0-9]'), '').trim();
  }
}
