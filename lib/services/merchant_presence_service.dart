// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

class MerchantPresenceService {
  MerchantPresenceService._();

  static Timer? _heartbeat;
  static String? _currentMerchantId;
  static String? _currentMerchantDocId;
  static Set<String> _currentMerchantDocIds = <String>{};

  static CollectionReference<Map<String, dynamic>> get _users =>
      FirebaseFirestore.instance.collection('users');

  /// يبدأ تحديث حالة التواجد للتاجر كل دقيقة.
  static Future<void> start({
    required String merchantId,
    required String merchantWhatsapp,
  }) async {
    final trimmedMerchantId = merchantId.trim();
    _currentMerchantId = trimmedMerchantId;
    final resolvedDocId = await _resolveMerchantDocId(
      merchantId: trimmedMerchantId,
      merchantWhatsapp: merchantWhatsapp,
    );
    final resolvedDocIds = await _resolveMerchantDocIds(
      merchantId: trimmedMerchantId,
      merchantWhatsapp: merchantWhatsapp,
    );
    if (resolvedDocId != null && resolvedDocId.trim().isNotEmpty) {
      resolvedDocIds.add(resolvedDocId.trim());
    }
    if (resolvedDocIds.isEmpty && trimmedMerchantId.isNotEmpty) {
      resolvedDocIds.add(trimmedMerchantId);
    }
    _currentMerchantDocId = resolvedDocId ?? trimmedMerchantId;
    _currentMerchantDocIds = Set<String>.from(resolvedDocIds);
    if (resolvedDocIds.isEmpty) return;

    final targetDocId = _currentMerchantDocId ?? resolvedDocIds.first;
    final manualOffline = await _isManualOffline(targetDocId);
    if (manualOffline) {
      _heartbeat?.cancel();
      _heartbeat = null;
      await _markOffline(merchantDocIds: resolvedDocIds, silent: true);
      return;
    }
    await _markOnline(
      merchantId: trimmedMerchantId,
      merchantDocIds: resolvedDocIds,
      merchantWhatsapp: merchantWhatsapp,
    );
    _heartbeat?.cancel();
    final heartbeatDocIds = Set<String>.from(resolvedDocIds);
    _heartbeat = Timer.periodic(const Duration(minutes: 1), (_) {
      _markOnline(
        merchantId: trimmedMerchantId,
        merchantDocIds: heartbeatDocIds,
        merchantWhatsapp: merchantWhatsapp,
        silent: true,
      );
    });
  }

  /// يوقف التحديث ويضبط الحالة كأوفلاين.
  static Future<void> stop({bool markOffline = true}) async {
    _heartbeat?.cancel();
    _heartbeat = null;
    final merchantDocIds = Set<String>.from(_currentMerchantDocIds);
    final merchantDocId = _currentMerchantDocId ?? _currentMerchantId;
    if (merchantDocIds.isEmpty && merchantDocId != null) {
      merchantDocIds.add(merchantDocId);
    }
    _currentMerchantId = null;
    _currentMerchantDocId = null;
    _currentMerchantDocIds = <String>{};
    if (!markOffline || merchantDocIds.isEmpty) {
      return;
    }
    await _markOffline(merchantDocIds: merchantDocIds, silent: true);
  }

  static Future<bool> _isManualOffline(String merchantId) async {
    if (merchantId.trim().isEmpty) return false;
    try {
      final snap = await _users.doc(merchantId).get();
      return snap.data()?['merchant_manual_offline'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setManualOffline({
    required String merchantId,
    required String merchantWhatsapp,
    required bool manualOffline,
  }) async {
    final trimmedMerchantId = merchantId.trim();
    if (trimmedMerchantId.isEmpty) return;
    final resolvedDocId = await _resolveMerchantDocId(
      merchantId: trimmedMerchantId,
      merchantWhatsapp: merchantWhatsapp,
    );
    final resolvedDocIds = await _resolveMerchantDocIds(
      merchantId: trimmedMerchantId,
      merchantWhatsapp: merchantWhatsapp,
    );
    if (resolvedDocId != null && resolvedDocId.trim().isNotEmpty) {
      resolvedDocIds.add(resolvedDocId.trim());
    }
    if (resolvedDocIds.isEmpty) {
      resolvedDocIds.add(trimmedMerchantId);
    }
    final targetDocId = resolvedDocId ?? trimmedMerchantId;
    final normalizedWhatsapp = _normalizeWhatsapp(merchantWhatsapp);
    _currentMerchantId = trimmedMerchantId;
    _currentMerchantDocId = targetDocId;
    _currentMerchantDocIds = Set<String>.from(resolvedDocIds);
    await _updateMerchantDocs(
      merchantDocIds: resolvedDocIds,
      data: {
        'merchant_manual_offline': manualOffline,
        'merchant_whatsapp': normalizedWhatsapp,
        'is_merchant': true,
        if (trimmedMerchantId.isNotEmpty) 'uid': trimmedMerchantId,
        if (manualOffline) 'merchant_online': false,
        if (manualOffline) 'merchant_last_seen': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
    );
    if (manualOffline) {
      await stop(markOffline: true);
      return;
    }
    await start(
      merchantId: trimmedMerchantId,
      merchantWhatsapp: merchantWhatsapp,
    );
  }

  static String _normalizeWhatsapp(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '').trim();
  }

  static Future<String?> _resolveMerchantDocId({
    required String merchantId,
    required String merchantWhatsapp,
  }) async {
    final trimmedId = merchantId.trim();
    if (trimmedId.isNotEmpty) {
      try {
        final byId = await _users.doc(trimmedId).get();
        if (byId.exists) return byId.id;
      } catch (_) {}
      try {
        final byUid = await _users
            .where('uid', isEqualTo: trimmedId)
            .limit(1)
            .get();
        if (byUid.docs.isNotEmpty) return byUid.docs.first.id;
      } catch (_) {}
    }

    final normalizedWhatsapp = _normalizeWhatsapp(merchantWhatsapp);
    if (normalizedWhatsapp.isNotEmpty) {
      try {
        final byMerchantWhatsapp = await _users
            .where('merchant_whatsapp', isEqualTo: normalizedWhatsapp)
            .limit(1)
            .get();
        if (byMerchantWhatsapp.docs.isNotEmpty) {
          return byMerchantWhatsapp.docs.first.id;
        }
      } catch (_) {}
      try {
        final byWhatsapp = await _users
            .where('whatsapp', isEqualTo: normalizedWhatsapp)
            .limit(1)
            .get();
        if (byWhatsapp.docs.isNotEmpty) return byWhatsapp.docs.first.id;
      } catch (_) {}
      try {
        final byDocId = await _users.doc(normalizedWhatsapp).get();
        if (byDocId.exists) return byDocId.id;
      } catch (_) {}
    }

    return trimmedId.isEmpty ? null : trimmedId;
  }

  static Future<Set<String>> _resolveMerchantDocIds({
    required String merchantId,
    required String merchantWhatsapp,
  }) async {
    final docIds = <String>{};
    final trimmedId = merchantId.trim();
    if (trimmedId.isNotEmpty) {
      docIds.add(trimmedId);
      try {
        final byId = await _users.doc(trimmedId).get();
        if (byId.exists) docIds.add(byId.id.trim());
      } catch (_) {}
      try {
        final byUid = await _users
            .where('uid', isEqualTo: trimmedId)
            .limit(10)
            .get();
        for (final doc in byUid.docs) {
          final id = doc.id.trim();
          if (id.isNotEmpty) docIds.add(id);
        }
      } catch (_) {}
    }

    final normalizedWhatsapp = _normalizeWhatsapp(merchantWhatsapp);
    if (normalizedWhatsapp.isNotEmpty) {
      try {
        final byMerchantWhatsapp = await _users
            .where('merchant_whatsapp', isEqualTo: normalizedWhatsapp)
            .limit(10)
            .get();
        for (final doc in byMerchantWhatsapp.docs) {
          final id = doc.id.trim();
          if (id.isNotEmpty) docIds.add(id);
        }
      } catch (_) {}
      try {
        final byWhatsapp = await _users
            .where('whatsapp', isEqualTo: normalizedWhatsapp)
            .limit(10)
            .get();
        for (final doc in byWhatsapp.docs) {
          final id = doc.id.trim();
          if (id.isNotEmpty) docIds.add(id);
        }
      } catch (_) {}
      try {
        final byDocId = await _users.doc(normalizedWhatsapp).get();
        if (byDocId.exists) {
          final id = byDocId.id.trim();
          if (id.isNotEmpty) docIds.add(id);
        }
      } catch (_) {}
    }

    docIds.removeWhere((id) => id.trim().isEmpty);
    return docIds;
  }

  static Future<void> _markOnline({
    required String merchantId,
    required Set<String> merchantDocIds,
    required String merchantWhatsapp,
    bool silent = false,
  }) async {
    if (merchantDocIds.isEmpty) return;
    final normalizedWhatsapp = _normalizeWhatsapp(merchantWhatsapp);
    await _updateMerchantDocs(
      merchantDocIds: merchantDocIds,
      silent: silent,
      data: {
        'merchant_online': true,
        'merchant_last_seen': FieldValue.serverTimestamp(),
        'merchant_manual_offline': false,
        'merchant_whatsapp': normalizedWhatsapp,
        'is_merchant': true,
        if (merchantId.trim().isNotEmpty) 'uid': merchantId.trim(),
        'updated_at': FieldValue.serverTimestamp(),
      },
    );
  }

  static Future<void> _markOffline({
    required Set<String> merchantDocIds,
    bool silent = false,
  }) async {
    if (merchantDocIds.isEmpty) return;
    await _updateMerchantDocs(
      merchantDocIds: merchantDocIds,
      silent: silent,
      data: {
        'merchant_online': false,
        'merchant_last_seen': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
    );
  }

  static Future<void> _updateMerchantDocs({
    required Set<String> merchantDocIds,
    required Map<String, dynamic> data,
    bool silent = false,
  }) async {
    if (merchantDocIds.isEmpty) return;
    Object? firstError;
    StackTrace? firstStackTrace;

    for (final docId in merchantDocIds) {
      final trimmedDocId = docId.trim();
      if (trimmedDocId.isEmpty) continue;
      try {
        await _users.doc(trimmedDocId).set(data, SetOptions(merge: true));
      } catch (error, stackTrace) {
        if (silent || firstError != null) continue;
        firstError = error;
        firstStackTrace = stackTrace;
      }
    }

    if (!silent && firstError != null && firstStackTrace != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace);
    }
  }
}
