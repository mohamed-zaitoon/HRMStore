// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:developer';
import 'package:universal_html/js.dart' as js;

class OneSignalWebBridge {
  // EN: Initializes init.
  // AR: تهيّئ init.
  static Future<void> init(String appId) async {
    await _callPromise('hrmstoreOneSignalInit', [appId]);
  }

  // EN: Handles login.
  // AR: تتعامل مع login.
  static Future<void> login(String externalId) async {
    await _callPromise('hrmstoreOneSignalLogin', [externalId]);
  }

  // EN: Handles logout.
  // AR: تتعامل مع logout.
  static Future<void> logout() async {
    await _callPromise('hrmstoreOneSignalLogout');
  }

  // EN: Requests Permission.
  // AR: تطلب Permission.
  static Future<void> requestPermission() async {
    await _callPromise('hrmstoreOneSignalRequestPermission');
  }

  // EN: Gets Subscription Id.
  // AR: تجلب Subscription Id.
  static Future<String?> getSubscriptionId() async {
    final result = await _callPromise('hrmstoreOneSignalGetSubscriptionId');
    if (result == null) return null;
    final value = result.toString().trim();
    return value.isEmpty ? null : value;
  }

  // EN: Handles call.
  // AR: تتعامل مع call.
  static Future<dynamic> _callPromise(
    String method, [
    List<dynamic> args = const [],
  ]) async {
    final fn = js.context[method];
    if (fn == null) {
      log('OneSignal web bridge missing: $method');
      return null;
    }

    try {
      final result = js.context.callMethod(method, args);
      if (result != null) {
        final jsObject = result is js.JsObject
            ? result
            : js.JsObject.fromBrowserObject(result);
        if (jsObject.hasProperty('then')) {
          // Promise detected: fire-and-forget to avoid JS interop errors
          return null;
        }
      }
      return result;
    } catch (e, s) {
      log(
        'OneSignal web bridge call failed: $method -> $e',
        error: e,
        stackTrace: s,
      );
      return null;
    }
  }
}
