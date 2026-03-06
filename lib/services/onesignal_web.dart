// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:async';
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

  // EN: Sets user tags for fallback targeting.
  // AR: تضبط وسوم المستخدم للاستهداف الاحتياطي.
  static Future<void> setTags(Map<String, String> tags) async {
    if (tags.isEmpty) return;
    await _callPromise('hrmstoreOneSignalSetTags', [js.JsObject.jsify(tags)]);
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
      if (result == null) return null;

      final jsResult = result is js.JsObject
          ? result
          : js.JsObject.fromBrowserObject(result);

      if (jsResult.hasProperty('then')) {
        final completer = Completer<dynamic>();
        final onResolve = js.JsFunction.withThis((_, dynamic value) {
          if (!completer.isCompleted) {
            completer.complete(value);
          }
        });
        final onReject = js.JsFunction.withThis((_, dynamic error) {
          if (!completer.isCompleted) {
            completer.completeError(error ?? 'JS promise rejected');
          }
        });
        jsResult.callMethod('then', [
          onResolve,
          onReject,
        ]);
        return await completer.future;
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
