// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_navigator.dart';
import '../core/order_status.dart';
import '../widgets/top_snackbar.dart';
import 'onesignal_service.dart';
import 'remote_config_service.dart';

class NotificationService {
  NotificationService._();
  static const String _modeHybrid = 'hybrid';
  static const String _modeOneSignal = 'onesignal';
  static const String _modeRealtime = 'realtime';
  static const String _cloudflareUrlDefine = String.fromEnvironment(
    'CF_NOTIFY_URL',
    defaultValue: '',
  );
  static const String _adminOrdersLastSeenKey = 'notif_last_seen_admin_orders';
  static const String _adminCodesLastSeenKey = 'notif_last_seen_admin_codes';
  static const String _userOrdersLastSeenPrefix =
      'notif_last_seen_user_orders_';
  static const String _userCodesLastSeenPrefix = 'notif_last_seen_user_codes_';

  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _userOrdersSub;
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _adminOrdersSub;
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _userCodesSub;
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _adminCodesSub;

  static final Map<String, String> _userOrderStatusById = <String, String>{};
  static final Map<String, String> _adminOrderStatusById = <String, String>{};
  static final Map<String, String> _userCodeStatusById = <String, String>{};
  static final Map<String, String> _userCodeValueById = <String, String>{};
  static final Set<String> _adminPendingCodeIds = <String>{};

  static bool _userOrdersPrimed = false;
  static bool _adminOrdersPrimed = false;
  static bool _userCodesPrimed = false;
  static bool _adminCodesPrimed = false;
  static SharedPreferences? _prefsCache;

  // EN: Handles current notification mode from Remote Config.
  // AR: تتعامل مع وضع الإشعارات الحالي من الريموت كونفج.
  static String get notificationMode {
    try {
      final mode = RemoteConfigService.instance.notificationMode;
      if (mode == _modeHybrid ||
          mode == _modeOneSignal ||
          mode == _modeRealtime) {
        return mode;
      }
      return _modeRealtime;
    } catch (_) {
      return _modeRealtime;
    }
  }

  static bool _isOneSignalEnabled() {
    try {
      final hasCloudflareEndpoint =
          RemoteConfigService.instance.cloudflareNotifyUrl.isNotEmpty ||
          _cloudflareUrlDefine.trim().isNotEmpty;
      final cloudflareEnabled =
          RemoteConfigService.instance.cloudflareNotifyEnabled &&
          hasCloudflareEndpoint;
      if (cloudflareEnabled) return true;
      return notificationMode != _modeRealtime;
    } catch (_) {
      return true;
    }
  }

  static bool _isRealtimeEnabled() {
    try {
      if (notificationMode != _modeRealtime) return false;
      if (_isOneSignalEnabled()) return false;
      return true;
    } catch (_) {
      return true;
    }
  }

  // EN: Initializes init.
  // AR: تهيّئ init.
  static Future<void> init() async {
    if (_isOneSignalEnabled()) {
      await OneSignalService.init();
    }
    if (kDebugMode) {
      log('NotificationService.init() -> mode: $notificationMode');
    }
  }

  // EN: Initializes User Notifications.
  // AR: تهيّئ User Notifications.
  static Future<void> initUserNotifications(
    String whatsapp, {
    bool requestPermission = false,
  }) async {
    if (!_isOneSignalEnabled()) {
      if (kDebugMode) {
        log('initUserNotifications skipped (mode: $notificationMode)');
      }
      return;
    }
    await OneSignalService.registerUser(
      whatsapp: whatsapp,
      isAdmin: false,
      requestPermission: requestPermission,
    );
  }

  // EN: Initializes Admin Notifications.
  // AR: تهيّئ Admin Notifications.
  static Future<void> initAdminNotifications(
    String whatsapp, {
    bool requestPermission = false,
  }) async {
    if (!_isOneSignalEnabled()) {
      if (kDebugMode) {
        log('initAdminNotifications skipped (mode: $notificationMode)');
      }
      return;
    }
    await OneSignalService.registerUser(
      whatsapp: whatsapp,
      isAdmin: true,
      requestPermission: requestPermission,
    );
  }

  // EN: Saves user token (legacy no-op for OneSignal).
  // AR: تحفظ توكن المستخدم (لا تعمل مع OneSignal).
  static Future<void> saveUserToken({
    required String collection,
    required String docId,
  }) async {
    if (kDebugMode) {
      log('saveUserToken(collection: $collection, docId: $docId) -> no-op');
    }
  }

  // EN: Removes User Notifications.
  // AR: تزيل User Notifications.
  static Future<void> removeUserNotifications(String whatsapp) async {
    await _cancelAndClearUserStreams();
    await pushLogout();
  }

  // EN: Removes Admin Notifications.
  // AR: تزيل Admin Notifications.
  static Future<void> removeAdminNotifications(String whatsapp) async {
    await _cancelAndClearAdminStreams();
    await pushLogout();
  }

  // EN: Requests push permission.
  // AR: تطلب صلاحية إشعارات الدفع.
  static Future<void> requestPermission() async {
    if (!_isOneSignalEnabled()) {
      if (kDebugMode) {
        log('requestPermission skipped (mode: $notificationMode)');
      }
      return;
    }
    await OneSignalService.requestPermission();
  }

  // EN: Logs out push identity.
  // AR: تسجّل خروج هوية إشعارات الدفع.
  static Future<void> pushLogout() async {
    await OneSignalService.logout();
  }

  // EN: Initializes ialize Foreground Notifications.
  // AR: تهيّئ ialize Foreground Notifications.
  static void initializeForegroundNotifications() {
    if (kDebugMode) {
      log('initializeForegroundNotifications() -> Firestore listeners active');
    }
  }

  // EN: Listens to To User Orders.
  // AR: تستمع إلى To User Orders.
  static void listenToUserOrders(String userWhatsapp) {
    if (!_isRealtimeEnabled()) {
      _userOrdersSub?.cancel();
      _userOrdersSub = null;
      _userOrderStatusById.clear();
      _userOrdersPrimed = false;
      if (kDebugMode) {
        log('listenToUserOrders skipped (mode: $notificationMode)');
      }
      return;
    }

    final query = _queryByWhatsapp(
      collection: FirebaseFirestore.instance.collection('orders'),
      field: 'user_whatsapp',
      whatsapp: userWhatsapp,
    );
    if (query == null) return;
    final normalized = _normalizeDigits(userWhatsapp);
    final scopeKey =
        '$_userOrdersLastSeenPrefix${normalized.isEmpty ? 'unknown' : normalized}';

    _userOrdersSub?.cancel();
    _userOrderStatusById.clear();
    _userOrdersPrimed = false;

    _userOrdersSub = query.snapshots().listen(
      (snapshot) async {
        DateTime? lastSeen = await _readLastSeen(scopeKey);
        final bool canReplayHistory = lastSeen != null;
        if (lastSeen == null) {
          lastSeen = DateTime.now();
          await _writeLastSeen(scopeKey, lastSeen);
        }

        if (!_userOrdersPrimed) {
          DateTime latestSeen = lastSeen;
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final status = _statusFrom(data);
            _userOrderStatusById[doc.id] = status;

            if (!canReplayHistory) continue;
            if (status.isEmpty || status == 'pending_payment') continue;

            final eventAt = _bestTimestamp(data, const [
              'updated_at',
              'created_at',
            ]);
            if (!_isAfterLastSeen(eventAt, lastSeen)) continue;
            _showUserOrderStatusNotification(status: status);
            if (eventAt.isAfter(latestSeen)) {
              latestSeen = eventAt;
            }
          }
          if (canReplayHistory && latestSeen.isAfter(lastSeen)) {
            await _writeLastSeen(scopeKey, latestSeen);
          }
          _userOrdersPrimed = true;
          if (kDebugMode) {
            log(
              'listenToUserOrders(${_safeNumber(userWhatsapp)}) -> primed ${snapshot.docs.length}',
            );
          }
          return;
        }

        for (final change in snapshot.docChanges) {
          final docId = change.doc.id;
          if (change.type == DocumentChangeType.removed) {
            _userOrderStatusById.remove(docId);
            continue;
          }

          final data = change.doc.data() ?? <String, dynamic>{};
          final status = _statusFrom(data);
          final prevStatus = _userOrderStatusById[docId] ?? '';
          _userOrderStatusById[docId] = status;

          if (status.isEmpty || status == prevStatus) continue;
          final eventAt = _bestTimestamp(data, const [
            'updated_at',
            'created_at',
          ], fallback: DateTime.now());
          if (!_isAfterLastSeen(eventAt, lastSeen)) continue;

          await _writeLastSeen(scopeKey, eventAt);
          _showUserOrderStatusNotification(status: status);
        }
      },
      onError: (error) {
        if (kDebugMode) {
          log('listenToUserOrders error: $error');
        }
      },
    );
  }

  // EN: Listens to To Admin Orders.
  // AR: تستمع إلى To Admin Orders.
  static void listenToAdminOrders() {
    if (!_isRealtimeEnabled()) {
      _adminOrdersSub?.cancel();
      _adminOrdersSub = null;
      _adminOrderStatusById.clear();
      _adminOrdersPrimed = false;
      if (kDebugMode) {
        log('listenToAdminOrders skipped (mode: $notificationMode)');
      }
      return;
    }

    final query = FirebaseFirestore.instance
        .collection('orders')
        .where(
          'status',
          whereIn: const ['pending_payment', 'pending_review', 'processing'],
        );

    _adminOrdersSub?.cancel();
    _adminOrderStatusById.clear();
    _adminOrdersPrimed = false;

    _adminOrdersSub = query.snapshots().listen(
      (snapshot) async {
        DateTime? lastSeen = await _readLastSeen(_adminOrdersLastSeenKey);
        final bool canReplayHistory = lastSeen != null;
        if (lastSeen == null) {
          lastSeen = DateTime.now();
          await _writeLastSeen(_adminOrdersLastSeenKey, lastSeen);
        }

        if (!_adminOrdersPrimed) {
          DateTime latestSeen = lastSeen;
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final status = _statusFrom(data);
            _adminOrderStatusById[doc.id] = status;

            if (!canReplayHistory) continue;

            final createdAt = _bestTimestamp(data, const [
              'created_at',
              'updated_at',
            ]);
            if (_isAfterLastSeen(createdAt, lastSeen)) {
              _showAdminNewOrderNotification(data: data);
              if (createdAt.isAfter(latestSeen)) {
                latestSeen = createdAt;
              }
              continue;
            }

            final hasReceipt = _hasReceiptProof(data);
            if (status == 'pending_review' && hasReceipt) {
              final receiptAt = _bestTimestamp(data, const [
                'receipt_uploaded_at',
                'updated_at',
                'created_at',
              ]);
              if (_isAfterLastSeen(receiptAt, lastSeen)) {
                _showInAppNotification(
                  'تم رفع إيصال جديد من مستخدم',
                  color: Colors.orange,
                  icon: Icons.receipt_long,
                );
                if (receiptAt.isAfter(latestSeen)) {
                  latestSeen = receiptAt;
                }
              }
            }
          }
          if (canReplayHistory && latestSeen.isAfter(lastSeen)) {
            await _writeLastSeen(_adminOrdersLastSeenKey, latestSeen);
          }
          _adminOrdersPrimed = true;
          if (kDebugMode) {
            log('listenToAdminOrders() -> primed ${snapshot.docs.length}');
          }
          return;
        }

        for (final change in snapshot.docChanges) {
          final docId = change.doc.id;
          if (change.type == DocumentChangeType.removed) {
            _adminOrderStatusById.remove(docId);
            continue;
          }

          final data = change.doc.data() ?? <String, dynamic>{};
          final status = _statusFrom(data);
          final prevStatus = _adminOrderStatusById[docId] ?? '';
          _adminOrderStatusById[docId] = status;

          if (change.type == DocumentChangeType.added) {
            final createdAt = _bestTimestamp(data, const [
              'created_at',
              'updated_at',
            ], fallback: DateTime.now());
            if (!_isAfterLastSeen(createdAt, lastSeen)) continue;
            await _writeLastSeen(_adminOrdersLastSeenKey, createdAt);
            _showAdminNewOrderNotification(data: data);
            continue;
          }

          if (status == prevStatus) continue;

          if (prevStatus == 'pending_payment' && status == 'pending_review') {
            final receiptAt = _bestTimestamp(data, const [
              'receipt_uploaded_at',
              'updated_at',
              'created_at',
            ], fallback: DateTime.now());
            if (!_isAfterLastSeen(receiptAt, lastSeen)) continue;
            await _writeLastSeen(_adminOrdersLastSeenKey, receiptAt);
            _showInAppNotification(
              'تم رفع إيصال جديد من مستخدم',
              color: Colors.orange,
              icon: Icons.receipt_long,
            );
          }
        }
      },
      onError: (error) {
        if (kDebugMode) {
          log('listenToAdminOrders error: $error');
        }
      },
    );
  }

  // EN: Listens to To User Ramadan Codes.
  // AR: تستمع إلى To User Ramadan Codes.
  static void listenToUserRamadanCodes(String userWhatsapp) {
    if (!_isRealtimeEnabled()) {
      _userCodesSub?.cancel();
      _userCodesSub = null;
      _userCodeStatusById.clear();
      _userCodeValueById.clear();
      _userCodesPrimed = false;
      if (kDebugMode) {
        log('listenToUserRamadanCodes skipped (mode: $notificationMode)');
      }
      return;
    }

    final query = _queryByWhatsapp(
      collection: FirebaseFirestore.instance.collection('code_requests'),
      field: 'whatsapp',
      whatsapp: userWhatsapp,
    );
    if (query == null) return;
    final normalized = _normalizeDigits(userWhatsapp);
    final scopeKey =
        '$_userCodesLastSeenPrefix${normalized.isEmpty ? 'unknown' : normalized}';

    _userCodesSub?.cancel();
    _userCodeStatusById.clear();
    _userCodeValueById.clear();
    _userCodesPrimed = false;

    _userCodesSub = query.snapshots().listen(
      (snapshot) async {
        DateTime? lastSeen = await _readLastSeen(scopeKey);
        final bool canReplayHistory = lastSeen != null;
        if (lastSeen == null) {
          lastSeen = DateTime.now();
          await _writeLastSeen(scopeKey, lastSeen);
        }

        if (!_userCodesPrimed) {
          DateTime latestSeen = lastSeen;
          for (final doc in snapshot.docs) {
            final data = doc.data();
            _userCodeStatusById[doc.id] = _statusFrom(data);
            _userCodeValueById[doc.id] = _promoCodeFrom(data);

            if (!canReplayHistory) continue;

            final status = _statusFrom(data);
            final promoCode = _promoCodeFrom(data);
            final eventAt = _bestTimestamp(data, const [
              'sent_at',
              'updated_at',
              'created_at',
            ]);
            if (!_isAfterLastSeen(eventAt, lastSeen)) continue;

            if (promoCode.isNotEmpty) {
              _showInAppNotification(
                _promoCodeSentMessage(promoCode),
                color: Colors.green,
                icon: Icons.card_giftcard,
              );
            } else if (status == 'approved') {
              _showInAppNotification(
                'تم قبول طلب الكود ✅',
                color: Colors.green,
                icon: Icons.verified_rounded,
              );
            } else if (status == 'rejected' || status == 'sent') {
              _showInAppNotification(
                'تم تحديث طلب الكود',
                color: Colors.orange,
                icon: Icons.notifications_active,
              );
            } else {
              continue;
            }

            if (eventAt.isAfter(latestSeen)) {
              latestSeen = eventAt;
            }
          }
          if (canReplayHistory && latestSeen.isAfter(lastSeen)) {
            await _writeLastSeen(scopeKey, latestSeen);
          }
          _userCodesPrimed = true;
          if (kDebugMode) {
            log(
              'listenToUserRamadanCodes(${_safeNumber(userWhatsapp)}) -> primed ${snapshot.docs.length}',
            );
          }
          return;
        }

        for (final change in snapshot.docChanges) {
          final docId = change.doc.id;
          if (change.type == DocumentChangeType.removed) {
            _userCodeStatusById.remove(docId);
            _userCodeValueById.remove(docId);
            continue;
          }

          final data = change.doc.data() ?? <String, dynamic>{};
          final status = _statusFrom(data);
          final promoCode = _promoCodeFrom(data);
          final prevStatus = _userCodeStatusById[docId] ?? '';
          final prevCode = _userCodeValueById[docId] ?? '';
          _userCodeStatusById[docId] = status;
          _userCodeValueById[docId] = promoCode;
          final eventAt = _bestTimestamp(data, const [
            'sent_at',
            'updated_at',
            'created_at',
          ], fallback: DateTime.now());

          if (promoCode.isNotEmpty && promoCode != prevCode) {
            if (!_isAfterLastSeen(eventAt, lastSeen)) continue;
            await _writeLastSeen(scopeKey, eventAt);
            _showInAppNotification(
              _promoCodeSentMessage(promoCode),
              color: Colors.green,
              icon: Icons.card_giftcard,
            );
            continue;
          }

          if (status.isEmpty || status == prevStatus) continue;
          if (status == 'approved') {
            if (!_isAfterLastSeen(eventAt, lastSeen)) continue;
            await _writeLastSeen(scopeKey, eventAt);
            _showInAppNotification(
              'تم قبول طلب الكود ✅',
              color: Colors.green,
              icon: Icons.verified_rounded,
            );
          } else if (status == 'rejected') {
            if (!_isAfterLastSeen(eventAt, lastSeen)) continue;
            await _writeLastSeen(scopeKey, eventAt);
            _showInAppNotification(
              'تم رفض طلب الكود ❌',
              color: Colors.red,
              icon: Icons.cancel_outlined,
            );
          }
        }
      },
      onError: (error) {
        if (kDebugMode) {
          log('listenToUserRamadanCodes error: $error');
        }
      },
    );
  }

  // EN: Listens to To Admin Ramadan Codes.
  // AR: تستمع إلى To Admin Ramadan Codes.
  static void listenToAdminRamadanCodes() {
    if (!_isRealtimeEnabled()) {
      _adminCodesSub?.cancel();
      _adminCodesSub = null;
      _adminPendingCodeIds.clear();
      _adminCodesPrimed = false;
      if (kDebugMode) {
        log('listenToAdminRamadanCodes skipped (mode: $notificationMode)');
      }
      return;
    }

    final query = FirebaseFirestore.instance
        .collection('code_requests')
        .where('status', isEqualTo: 'pending');

    _adminCodesSub?.cancel();
    _adminPendingCodeIds.clear();
    _adminCodesPrimed = false;

    _adminCodesSub = query.snapshots().listen(
      (snapshot) async {
        DateTime? lastSeen = await _readLastSeen(_adminCodesLastSeenKey);
        final bool canReplayHistory = lastSeen != null;
        if (lastSeen == null) {
          lastSeen = DateTime.now();
          await _writeLastSeen(_adminCodesLastSeenKey, lastSeen);
        }

        if (!_adminCodesPrimed) {
          DateTime latestSeen = lastSeen;
          for (final doc in snapshot.docs) {
            _adminPendingCodeIds.add(doc.id);

            if (!canReplayHistory) continue;
            final data = doc.data();
            final createdAt = _bestTimestamp(data, const [
              'created_at',
              'updated_at',
            ]);
            if (!_isAfterLastSeen(createdAt, lastSeen)) continue;

            final name = (data['name'] ?? '').toString().trim();
            _showInAppNotification(
              _newPromoCodeRequestMessage(name: name),
              color: Colors.amber,
              icon: Icons.card_giftcard_rounded,
            );
            if (createdAt.isAfter(latestSeen)) {
              latestSeen = createdAt;
            }
          }
          if (canReplayHistory && latestSeen.isAfter(lastSeen)) {
            await _writeLastSeen(_adminCodesLastSeenKey, latestSeen);
          }
          _adminCodesPrimed = true;
          if (kDebugMode) {
            log(
              'listenToAdminRamadanCodes() -> primed ${snapshot.docs.length}',
            );
          }
          return;
        }

        for (final change in snapshot.docChanges) {
          final docId = change.doc.id;
          if (change.type == DocumentChangeType.removed) {
            _adminPendingCodeIds.remove(docId);
            continue;
          }

          _adminPendingCodeIds.add(docId);
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data() ?? <String, dynamic>{};
            final createdAt = _bestTimestamp(data, const [
              'created_at',
              'updated_at',
            ], fallback: DateTime.now());
            if (!_isAfterLastSeen(createdAt, lastSeen)) continue;
            await _writeLastSeen(_adminCodesLastSeenKey, createdAt);
            final name = (data['name'] ?? '').toString().trim();
            _showInAppNotification(
              _newPromoCodeRequestMessage(name: name),
              color: Colors.amber,
              icon: Icons.card_giftcard_rounded,
            );
          }
        }
      },
      onError: (error) {
        if (kDebugMode) {
          log('listenToAdminRamadanCodes error: $error');
        }
      },
    );
  }

  // EN: Disposes Listeners.
  // AR: تنهي Listeners.
  static Future<void> disposeListeners() async {
    await _cancelAndClearUserStreams();
    await _cancelAndClearAdminStreams();
    if (kDebugMode) log('disposeListeners() -> listeners cancelled');
  }

  static Future<void> _cancelAndClearUserStreams() async {
    await _userOrdersSub?.cancel();
    await _userCodesSub?.cancel();
    _userOrdersSub = null;
    _userCodesSub = null;
    _userOrderStatusById.clear();
    _userCodeStatusById.clear();
    _userCodeValueById.clear();
    _userOrdersPrimed = false;
    _userCodesPrimed = false;
  }

  static Future<void> _cancelAndClearAdminStreams() async {
    await _adminOrdersSub?.cancel();
    await _adminCodesSub?.cancel();
    _adminOrdersSub = null;
    _adminCodesSub = null;
    _adminOrderStatusById.clear();
    _adminPendingCodeIds.clear();
    _adminOrdersPrimed = false;
    _adminCodesPrimed = false;
  }

  static Future<SharedPreferences> _prefs() async {
    return _prefsCache ??= await SharedPreferences.getInstance();
  }

  static Future<DateTime?> _readLastSeen(String key) async {
    try {
      final prefs = await _prefs();
      final storedMillis = prefs.getInt(key);
      if (storedMillis != null && storedMillis > 0) {
        return DateTime.fromMillisecondsSinceEpoch(storedMillis, isUtc: true);
      }

      final storedIso = (prefs.getString(key) ?? '').trim();
      if (storedIso.isEmpty) return null;
      final parsed = DateTime.tryParse(storedIso);
      if (parsed == null) return null;
      final utc = parsed.toUtc();
      await prefs.setInt(key, utc.millisecondsSinceEpoch);
      return utc;
    } catch (error) {
      if (kDebugMode) {
        log('NotificationService._readLastSeen($key) error: $error');
      }
      return null;
    }
  }

  static Future<void> _writeLastSeen(String key, DateTime value) async {
    try {
      final prefs = await _prefs();
      await prefs.setInt(key, value.toUtc().millisecondsSinceEpoch);
    } catch (error) {
      if (kDebugMode) {
        log('NotificationService._writeLastSeen($key) error: $error');
      }
    }
  }

  static DateTime _bestTimestamp(
    Map<String, dynamic> data,
    List<String> keys, {
    DateTime? fallback,
  }) {
    for (final key in keys) {
      final parsed = _parseTimestamp(data[key]);
      if (parsed != null) return parsed;
    }
    return (fallback ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true))
        .toUtc();
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate().toUtc();
    if (value is DateTime) return value.toUtc();
    if (value is int) {
      final millis = value > 1000000000000 ? value : value * 1000;
      return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value.trim());
      return parsed?.toUtc();
    }
    return null;
  }

  static bool _isAfterLastSeen(DateTime eventAt, DateTime lastSeen) {
    return eventAt.toUtc().isAfter(lastSeen.toUtc());
  }

  static String _normalizeDigits(String value) {
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
    return normalized.toString().replaceAll(RegExp(r'[^0-9]'), '').trim();
  }

  static bool _hasReceiptProof(Map<String, dynamic> data) {
    final receiptUrl = (data['receipt_url'] ?? '').toString().trim();
    final receiptPath = (data['receipt_path'] ?? '').toString().trim();
    if (receiptUrl.isNotEmpty || receiptPath.isNotEmpty) return true;
    return _parseTimestamp(data['receipt_uploaded_at']) != null;
  }

  static Query<Map<String, dynamic>>? _queryByWhatsapp({
    required CollectionReference<Map<String, dynamic>> collection,
    required String field,
    required String whatsapp,
  }) {
    final candidates = _whatsappCandidates(whatsapp);
    if (candidates.isEmpty) {
      if (kDebugMode) {
        log('NotificationService -> invalid whatsapp for $field listener');
      }
      return null;
    }
    if (candidates.length == 1) {
      return collection.where(field, isEqualTo: candidates.first);
    }
    return collection.where(field, whereIn: candidates.take(10).toList());
  }

  static List<String> _whatsappCandidates(String input) {
    final raw = input.trim();
    final normalized = _normalizeDigits(raw);
    final set = <String>{};
    if (raw.isNotEmpty) set.add(raw);
    if (normalized.isNotEmpty) set.add(normalized);
    return set.toList(growable: false);
  }

  static String _statusFrom(Map<String, dynamic> data) {
    return (data['status'] ?? '').toString().trim();
  }

  static String _promoCodeFrom(Map<String, dynamic> data) {
    return (data['promo_code'] ?? '').toString().trim();
  }

  static String _promoSeasonLabel() {
    try {
      if (RemoteConfigService.instance.isRamadan) return 'رمضان';
    } catch (_) {}
    try {
      if (FirebaseRemoteConfig.instance.getBool('is_eid')) return 'العيد';
    } catch (_) {}
    return '';
  }

  static String _promoCodeSentMessage(String promoCode) {
    final season = _promoSeasonLabel();
    if (season.isNotEmpty) {
      return 'تم إرسال كود $season: $promoCode';
    }
    return 'تم إرسال كود الخصم: $promoCode';
  }

  static String _newPromoCodeRequestMessage({required String name}) {
    final season = _promoSeasonLabel();
    final codeLabel = season.isNotEmpty ? 'كود $season' : 'كود الخصم';
    if (name.isNotEmpty) {
      return 'طلب $codeLabel جديد من $name';
    }
    return 'طلب $codeLabel جديد';
  }

  static void _showUserOrderStatusNotification({required String status}) {
    if (status == 'pending_payment') return;

    String message;
    IconData icon;
    if (status == 'pending_review') {
      message = 'تم استلام إيصالك وجارٍ المراجعة ⏳';
      icon = Icons.receipt_long;
    } else if (status == 'processing') {
      message = 'طلبك دخل مرحلة التنفيذ ⚙️';
      icon = Icons.settings;
    } else if (status == 'completed') {
      message = 'تم تنفيذ طلبك بنجاح ✅';
      icon = Icons.check_circle;
    } else if (status == 'rejected') {
      message = 'تم رفض طلبك ❌';
      icon = Icons.cancel;
    } else if (status == 'cancelled') {
      message = 'تم إلغاء طلبك 🚫';
      icon = Icons.block;
    } else {
      message = 'تم تحديث حالة طلبك: ${OrderStatusHelper.label(status)}';
      icon = Icons.notifications_active;
    }

    _showInAppNotification(
      message,
      color: OrderStatusHelper.color(status),
      icon: icon,
    );
  }

  static void _showAdminNewOrderNotification({
    required Map<String, dynamic> data,
  }) {
    final name = (data['name'] ?? '').toString().trim();
    final summary = _orderSummary(data);
    final who = name.isNotEmpty ? name : 'عميل';
    final message = summary.isEmpty
        ? 'طلب شحن جديد من $who'
        : 'طلب شحن جديد من $who - $summary';
    _showInAppNotification(
      message,
      color: Colors.blue,
      icon: Icons.shopping_bag_rounded,
    );
  }

  static String _orderSummary(Map<String, dynamic> data) {
    final productType = (data['product_type'] ?? '').toString();
    if (productType == 'game') {
      final packageLabel = (data['package_label'] ?? '').toString().trim();
      if (packageLabel.isNotEmpty) return packageLabel;
      return 'شحن لعبة';
    }
    if (productType == 'balance_topup') {
      final points = (data['balance_points_requested'] ?? '').toString().trim();
      if (points.isNotEmpty) return 'شحن رصيد $points نقطة';
      return 'شحن رصيد نقاط';
    }
    if (productType == 'tiktok_promo') {
      return 'ترويج فيديو تيك توك';
    }
    final points = (data['points'] ?? '').toString().trim();
    if (points.isNotEmpty) return '$points نقطة';
    return '';
  }

  static void _showInAppNotification(
    String message, {
    required Color color,
    required IconData icon,
  }) {
    final context = AppNavigator.context;
    if (context == null) {
      if (kDebugMode) {
        log('NotificationService: context unavailable for message: $message');
      }
      return;
    }
    TopSnackBar.show(
      context,
      message,
      backgroundColor: color,
      textColor: Colors.white,
      icon: icon,
    );
  }

  static String _safeNumber(String whatsapp) {
    final digits = whatsapp.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length <= 4) return digits;
    final tail = digits.substring(digits.length - 4);
    return '***$tail';
  }
}
