// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'remote_config_service.dart';
import 'onesignal_web_stub.dart' if (dart.library.html) 'onesignal_web.dart';

class OneSignalService {
  static bool _initialized = false;
  static const String _fallbackAppId = String.fromEnvironment(
    'ONESIGNAL_APP_ID',
    defaultValue: 'd9dcc8b4-585d-4ccf-a101-7b94b0d504ce',
  );

  // EN: Initializes init.
  // AR: تهيّئ init.
  static Future<void> init() async {
    if (_initialized) return;

    try {
      final remoteAppId = RemoteConfigService.instance.oneSignalAppId.trim();
      final resolvedAppId =
          remoteAppId.isNotEmpty ? remoteAppId : _fallbackAppId;
      if (resolvedAppId.isEmpty) {
        log(
          'OneSignal init skipped: onesignal_app_id not set in Remote Config',
        );
        return;
      }

      if (kIsWeb) {
        await OneSignalWebBridge.init(resolvedAppId);
      } else {
        if (kDebugMode) {
          OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
        }

        OneSignal.initialize(resolvedAppId);
      }

      _initialized = true;

      log('OneSignal initialized');
    } catch (e, s) {
      log('OneSignal.init error: $e', error: e, stackTrace: s);
    }
  }

  // EN: Handles register User.
  // AR: تتعامل مع register User.
  static Future<void> registerUser({
    required String whatsapp,
    required bool isAdmin,
    bool requestPermission = false,
  }) async {
    if (whatsapp.trim().isEmpty) return;

    await init();
    if (!_initialized) {
      log('OneSignal register skipped: not initialized');
      return;
    }

    try {
      final externalId = _buildExternalId(whatsapp, isAdmin);
      if (kIsWeb) {
        await OneSignalWebBridge.login(externalId);
        if (requestPermission) {
          await OneSignalWebBridge.requestPermission();
        }
      } else {
        await OneSignal.login(externalId);
        if (requestPermission) {
          await OneSignal.Notifications.requestPermission(true);
        }
      }

      final subscriptionId = await _getSubscriptionId();
      await _saveUser(
        whatsapp: whatsapp,
        isAdmin: isAdmin,
        subscriptionId: subscriptionId,
        externalId: externalId,
      );
    } catch (e, s) {
      log('OneSignal.registerUser error: $e', error: e, stackTrace: s);
    }
  }

  // EN: Requests notification permission explicitly.
  // AR: تطلب صلاحية الإشعارات بشكل صريح.
  static Future<void> requestPermission() async {
    await init();
    if (!_initialized) {
      log('OneSignal permission skipped: not initialized');
      return;
    }

    try {
      if (kIsWeb) {
        await OneSignalWebBridge.requestPermission();
      } else {
        await OneSignal.Notifications.requestPermission(true);
      }
    } catch (e, s) {
      log('OneSignal.requestPermission error: $e', error: e, stackTrace: s);
    }
  }

  // EN: Handles logout.
  // AR: تتعامل مع logout.
  static Future<void> logout() async {
    try {
      if (kIsWeb) {
        await OneSignalWebBridge.logout();
      } else {
        await OneSignal.logout();
      }
    } catch (e) {
      log('OneSignal.logout error: $e');
    }
  }

  // EN: Gets Subscription Id.
  // AR: تجلب Subscription Id.
  static Future<String?> _getSubscriptionId() async {
    if (kIsWeb) {
      return OneSignalWebBridge.getSubscriptionId();
    }

    final id = OneSignal.User.pushSubscription.id;
    return (id != null && id.isNotEmpty) ? id : null;
  }

  // EN: Saves User.
  // AR: تحفظ User.
  static Future<void> _saveUser({
    required String whatsapp,
    required bool isAdmin,
    String? subscriptionId,
    required String externalId,
  }) async {
    try {
      final data = <String, dynamic>{
        'is_admin': isAdmin,
        'whatsapp': whatsapp,
        'external_id': externalId,
        'updated_at': FieldValue.serverTimestamp(),
        'platforms': FieldValue.arrayUnion([_platformLabel()]),
      };

      if (subscriptionId != null && subscriptionId.isNotEmpty) {
        data['subscription_ids'] = FieldValue.arrayUnion([subscriptionId]);
      }

      await FirebaseFirestore.instance
          .collection('onesignal_players')
          .doc(externalId)
          .set(data, SetOptions(merge: true));
    } catch (e, s) {
      log('OneSignal.saveUser error: $e', error: e, stackTrace: s);
    }
  }

  // EN: Handles platform Label.
  // AR: تتعامل مع platform Label.
  static String _platformLabel() {
    if (kIsWeb) return 'web';

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  // EN: Builds external ID with role prefix.
  // AR: يبني معرف خارجي مع بادئة الدور.
  static String _buildExternalId(String whatsapp, bool isAdmin) {
    final normalized = _normalizeWhatsapp(whatsapp);
    return isAdmin ? 'admin:$normalized' : 'user:$normalized';
  }

  // EN: Normalizes WhatsApp to digits only for consistent external IDs.
  // AR: تطبع رقم واتساب لأرقام فقط لتوحيد المعرفات.
  static String _normalizeWhatsapp(String whatsapp) {
    return whatsapp.replaceAll(RegExp(r'[^0-9]'), '').trim();
  }
}
