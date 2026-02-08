// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:developer';

import 'package:flutter/foundation.dart' show kDebugMode;

import 'onesignal_service.dart';

class NotificationService {
  NotificationService._();

  // EN: Initializes init.
  // AR: تهيّئ init.
  static Future<void> init() async {
    await OneSignalService.init();
    if (kDebugMode) {
      log('NotificationService.init() -> OneSignal init');
    }
  }

  // EN: Initializes User Notifications.
  // AR: تهيّئ User Notifications.
  static Future<void> initUserNotifications(String whatsapp) async {
    await OneSignalService.registerUser(whatsapp: whatsapp, isAdmin: false);
  }

  // EN: Initializes Admin Notifications.
  // AR: تهيّئ Admin Notifications.
  static Future<void> initAdminNotifications(String whatsapp) async {
    await OneSignalService.registerUser(whatsapp: whatsapp, isAdmin: true);
  }

  // EN: Saves user token (legacy no-op for OneSignal).
  // AR: تحفظ توكن المستخدم (لا تعمل مع OneSignal).
  static Future<void> saveUserToken({
    required String collection,
    required String docId,
  }) async {
    if (kDebugMode) {
      log(
        'saveUserToken(collection: $collection, docId: $docId) -> no-op',
      );
    }
  }

  // EN: Removes User Notifications.
  // AR: تزيل User Notifications.
  static Future<void> removeUserNotifications(String whatsapp) async {
    await OneSignalService.logout();
  }

  // EN: Removes Admin Notifications.
  // AR: تزيل Admin Notifications.
  static Future<void> removeAdminNotifications(String whatsapp) async {
    await OneSignalService.logout();
  }

  // EN: Initializes ialize Foreground Notifications.
  // AR: تهيّئ ialize Foreground Notifications.
  static void initializeForegroundNotifications() {
    if (kDebugMode) {
      log('initializeForegroundNotifications() -> no-op (OneSignal only)');
    }
  }

  // EN: Listens to To User Orders.
  // AR: تستمع إلى To User Orders.
  static void listenToUserOrders(String userWhatsapp) {
    if (kDebugMode) {
      log('listenToUserOrders($userWhatsapp) -> no-op (OneSignal only)');
    }
  }

  // EN: Listens to To Admin Orders.
  // AR: تستمع إلى To Admin Orders.
  static void listenToAdminOrders() {
    if (kDebugMode) {
      log('listenToAdminOrders() -> no-op (OneSignal only)');
    }
  }

  // EN: Listens to To User Ramadan Codes.
  // AR: تستمع إلى To User Ramadan Codes.
  static void listenToUserRamadanCodes(String userWhatsapp) {
    if (kDebugMode) {
      log('listenToUserRamadanCodes($userWhatsapp) -> no-op (OneSignal only)');
    }
  }

  // EN: Listens to To Admin Ramadan Codes.
  // AR: تستمع إلى To Admin Ramadan Codes.
  static void listenToAdminRamadanCodes() {
    if (kDebugMode) {
      log('listenToAdminRamadanCodes() -> no-op (OneSignal only)');
    }
  }

  // EN: Disposes Listeners.
  // AR: تنهي Listeners.
  static Future<void> disposeListeners() async {
    if (kDebugMode) {
      log('disposeListeners() -> no-op (OneSignal only)');
    }
  }
}
