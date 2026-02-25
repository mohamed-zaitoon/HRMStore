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

  static const String _oneSignalApiUrl =
      'https://onesignal.com/api/v1/notifications';
  static const String _workerUrlDefine = String.fromEnvironment(
    'CF_NOTIFY_URL',
    defaultValue: '',
  );
  static const String _workerTokenDefine = String.fromEnvironment(
    'CF_NOTIFY_TOKEN',
    defaultValue: '',
  );
  static const String _oneSignalAppIdDefine = String.fromEnvironment(
    'ONESIGNAL_APP_ID',
    defaultValue: '',
  );
  static const String _oneSignalRestKeyDefine = String.fromEnvironment(
    'ONESIGNAL_REST_KEY',
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

  // EN: Sends chat-message notification to admin endpoint.
  // AR: ترسل إشعار رسالة الشات لنقطة نهاية الأدمن.
  static Future<bool> notifyAdminsChatMessage({
    required String orderId,
    String? userName,
    String? messagePreview,
  }) async {
    final who = (userName ?? '').trim();
    final preview = (messagePreview ?? '').trim();
    final body = preview.isNotEmpty
        ? preview
        : (who.isNotEmpty ? 'رسالة جديدة من $who' : 'رسالة جديدة من مستخدم');
    return _send(
      title: 'رسالة شات جديدة',
      message: body,
      data: <String, dynamic>{
        'type': 'chat_message',
        'order_id': orderId,
        'sender_role': 'user',
      },
      targetExternalIds: _adminExternalIds(),
      fallbackRole: 'admin',
    );
  }

  // EN: Sends chat-message notification to user endpoint.
  // AR: ترسل إشعار رسالة الشات لنقطة نهاية المستخدم.
  static Future<bool> notifyUserChatMessage({
    required String orderId,
    required String userWhatsapp,
    String? messagePreview,
  }) async {
    final normalized = _normalizeWhatsapp(userWhatsapp);
    if (normalized.isEmpty) return false;
    final preview = (messagePreview ?? '').trim();
    return _send(
      title: 'رسالة جديدة من الدعم',
      message: preview.isNotEmpty ? preview : 'هناك رد جديد على طلبك.',
      data: <String, dynamic>{
        'type': 'chat_message',
        'order_id': orderId,
        'sender_role': 'admin',
      },
      targetExternalIds: _externalIdsForWhatsapp(normalized, isAdmin: false),
      fallbackRole: 'user',
      fallbackWhatsapp: normalized,
    );
  }

  // EN: Sends inquiry-chat message notification to admin endpoint.
  // AR: ترسل إشعار رسالة شات الاستفسارات لنقطة نهاية الأدمن.
  static Future<bool> notifyAdminsSupportInquiryMessage({
    required String conversationId,
    String? userName,
  }) async {
    final who = (userName ?? '').trim();
    final body = who.isNotEmpty
        ? 'رسالة جديدة من $who'
        : 'رسالة جديدة من مستخدم';
    return _send(
      title: 'رسالة استفسار جديدة',
      message: body,
      data: <String, dynamic>{
        'type': 'support_inquiry_message',
        'conversation_id': conversationId,
        'sender_role': 'user',
      },
      targetExternalIds: _adminExternalIds(),
      fallbackRole: 'admin',
    );
  }

  // EN: Sends inquiry-chat message notification to user endpoint.
  // AR: ترسل إشعار رسالة شات الاستفسارات لنقطة نهاية المستخدم.
  static Future<bool> notifyUserSupportInquiryMessage({
    required String conversationId,
    required String userWhatsapp,
  }) async {
    final normalized = _normalizeWhatsapp(userWhatsapp);
    if (normalized.isEmpty) return false;
    return _send(
      title: 'رسالة جديدة من الدعم',
      message: 'هناك رد جديد في شات الاستفسارات.',
      data: <String, dynamic>{
        'type': 'support_inquiry_message',
        'conversation_id': conversationId,
        'sender_role': 'admin',
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

    var sent = false;
    if (_cloudflareEnabled) {
      sent = await _sendViaCloudflare(payload);
    }
    if (sent) return true;

    sent = await _sendViaOneSignalDirect(
      title: title,
      message: message,
      data: data,
      ids: ids,
      role: role,
      normalizedWhatsapp: normalizedWhatsapp,
    );
    if (sent) {
      if (kDebugMode) {
        log('Cloudflare notify fallback -> direct OneSignal success');
      }
      return true;
    }
    if (kDebugMode) {
      log('Cloudflare notify failed: all channels exhausted');
    }
    return false;
  }

  static Future<bool> _sendViaCloudflare(Map<String, dynamic> payload) async {
    final endpoint = _workerUrl;
    if (endpoint.isEmpty) {
      if (kDebugMode) {
        log('Cloudflare notify skipped: worker url not configured');
      }
      return false;
    }
    final token = _workerToken;
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
    } catch (error, stack) {
      if (kDebugMode) {
        log('Cloudflare notify error: $error', error: error, stackTrace: stack);
      }
    }
    return false;
  }

  static Future<bool> _sendViaOneSignalDirect({
    required String title,
    required String message,
    required Map<String, dynamic> data,
    required List<String> ids,
    required String role,
    required String normalizedWhatsapp,
  }) async {
    if (!_directOneSignalEnabled) return false;

    final basePayload = <String, dynamic>{
      'app_id': _oneSignalAppId,
      'headings': <String, String>{'en': title.trim(), 'ar': title.trim()},
      'contents': <String, String>{'en': message.trim(), 'ar': message.trim()},
      'data': data,
      'priority': 10,
    };

    final attempts = <Map<String, dynamic>>[];
    if (ids.isNotEmpty) {
      attempts.add(<String, dynamic>{
        ...basePayload,
        'include_aliases': <String, dynamic>{'external_id': ids},
        'target_channel': 'push',
      });
      attempts.add(<String, dynamic>{
        ...basePayload,
        'include_external_user_ids': ids,
        'channel_for_external_user_ids': 'push',
      });
    }
    final filters = _buildOneSignalFallbackFilters(role, normalizedWhatsapp);
    if (filters != null && filters.isNotEmpty) {
      attempts.add(<String, dynamic>{...basePayload, 'filters': filters});
    }
    if (attempts.isEmpty) return false;

    for (final payload in attempts) {
      final ok = await _postToOneSignal(payload);
      if (ok) return true;
    }
    return false;
  }

  static Future<bool> _postToOneSignal(Map<String, dynamic> payload) async {
    try {
      final response = await http
          .post(
            Uri.parse(_oneSignalApiUrl),
            headers: <String, String>{
              'content-type': 'application/json; charset=utf-8',
              'authorization': 'Basic $_oneSignalRestKey',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 12));
      final parsed = _tryDecodeJson(response.body);
      final isSuccess = _isLogicalOneSignalSuccess(response, parsed);
      if (kDebugMode && !isSuccess) {
        log(
          'Direct OneSignal failed (${response.statusCode}): ${response.body}',
        );
      }
      return isSuccess;
    } catch (error, stack) {
      if (kDebugMode) {
        log('Direct OneSignal error: $error', error: error, stackTrace: stack);
      }
      return false;
    }
  }

  static dynamic _tryDecodeJson(String body) {
    try {
      return body.isEmpty ? null : jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  static bool _isLogicalOneSignalSuccess(
    http.Response response,
    dynamic parsed,
  ) {
    if (response.statusCode < 200 || response.statusCode >= 300) return false;
    if (parsed is! Map<String, dynamic>) return true;

    final errors = parsed['errors'];
    if (errors is String && errors.trim().isNotEmpty) return false;
    if (errors is List && errors.isNotEmpty) return false;
    if (errors is Map && errors.isNotEmpty) return false;

    final recipients = _parseRecipientCount(parsed);
    if (recipients != null && recipients <= 0) return false;
    return true;
  }

  static int? _parseRecipientCount(Map<String, dynamic> parsed) {
    final candidates = <dynamic>[
      parsed['recipients'],
      parsed['total_count'],
      parsed['successful'],
    ];
    for (final candidate in candidates) {
      if (candidate is int) return candidate;
      if (candidate is String) {
        final parsedCount = int.tryParse(candidate.trim());
        if (parsedCount != null) return parsedCount;
      }
    }
    return null;
  }

  static List<Map<String, dynamic>>? _buildOneSignalFallbackFilters(
    String role,
    String normalizedWhatsapp,
  ) {
    if (role == 'admin') {
      return <Map<String, dynamic>>[
        <String, dynamic>{
          'field': 'tag',
          'key': 'role',
          'relation': '=',
          'value': 'admin',
        },
      ];
    }

    if (role == 'user') {
      final variants = _whatsappVariants(normalizedWhatsapp);
      if (variants.isEmpty) {
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'field': 'tag',
            'key': 'role',
            'relation': '=',
            'value': 'user',
          },
        ];
      }

      final filters = <Map<String, dynamic>>[
        <String, dynamic>{
          'field': 'tag',
          'key': 'role',
          'relation': '=',
          'value': 'user',
        },
        <String, dynamic>{'operator': 'AND'},
      ];
      for (var i = 0; i < variants.length; i++) {
        if (i > 0) {
          filters.add(<String, dynamic>{'operator': 'OR'});
        }
        filters.add(<String, dynamic>{
          'field': 'tag',
          'key': 'whatsapp',
          'relation': '=',
          'value': variants[i],
        });
      }
      return filters;
    }
    return null;
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

  static String get _oneSignalAppId {
    final remote = RemoteConfigService.instance.oneSignalAppId.trim();
    if (remote.isNotEmpty) return remote;
    return _oneSignalAppIdDefine.trim();
  }

  static String get _oneSignalRestKey {
    final remote = RemoteConfigService.instance.oneSignalRestApiKey.trim();
    if (remote.isNotEmpty) return remote;
    return _oneSignalRestKeyDefine.trim();
  }

  static bool get _directOneSignalEnabled {
    return _oneSignalAppId.isNotEmpty && _oneSignalRestKey.isNotEmpty;
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
    final out = <String>{};
    for (final v in variants) {
      if (v.trim().isEmpty) continue;
      // Primary format (current)
      out.add('$role:$v');
      // Legacy compatibility format (older players were saved as plain digits)
      out.add(v);
    }
    return out.toList(growable: false);
  }

  static List<String> _whatsappVariants(String value) {
    final digits = _normalizeWhatsapp(value);
    if (digits.isEmpty) return const <String>[];
    final set = <String>{digits};

    if (digits.length == 11 && digits.startsWith('0')) {
      set.add('2$digits');
      set.add(digits.substring(1));
    } else if (digits.length == 12 && digits.startsWith('20')) {
      set.add('0${digits.substring(2)}');
      set.add(digits.substring(2));
    } else if (digits.length == 10 && digits.startsWith('1')) {
      set.add('0$digits');
      set.add('20$digits');
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
      return 'تم رفض طلبك. راجع تفاصيل الرفض داخل شات الطلب.';
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
