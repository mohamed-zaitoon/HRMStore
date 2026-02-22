// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:cloud_firestore/cloud_firestore.dart';

class CancelLimitDecision {
  final bool allowed;
  final int cancellationsInLast24Hours;

  const CancelLimitDecision({
    required this.allowed,
    required this.cancellationsInLast24Hours,
  });
}

class CancelLimitService {
  static const int limit = 5;
  static const Duration window = Duration(hours: 24);
  static const int _maxStoredEvents = 20;
  static const String _eventsField = 'cancelled_events_24h_ms';
  static const String _countField = 'cancelled_count_24h';

  static Future<CancelLimitDecision> checkCanCreateOrder({
    required String whatsapp,
    String? uid,
  }) async {
    final ref = await _resolveUserRef(whatsapp: whatsapp, uid: uid);
    if (ref == null) {
      return const CancelLimitDecision(
        allowed: true,
        cancellationsInLast24Hours: 0,
      );
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final cutoffMs = nowMs - window.inMilliseconds;

    final snap = await ref.get();
    final data = snap.data() ?? const <String, dynamic>{};
    final events = _extractRecentEvents(data[_eventsField], cutoffMs);

    final storedCount = data[_countField];
    final bool countMismatch =
        (storedCount is int ? storedCount : null) != events.length;
    final bool eventsChanged = _hasEventsChanged(data[_eventsField], events);

    if (countMismatch || eventsChanged) {
      await ref.set({
        _eventsField: events,
        _countField: events.length,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    return CancelLimitDecision(
      allowed: events.length < limit,
      cancellationsInLast24Hours: events.length,
    );
  }

  static Future<int?> registerCancellation({
    required String whatsapp,
    String? uid,
  }) async {
    final ref = await _resolveUserRef(whatsapp: whatsapp, uid: uid);
    if (ref == null) return null;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final cutoffMs = nowMs - window.inMilliseconds;

    return FirebaseFirestore.instance.runTransaction<int>((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? const <String, dynamic>{};
      final events = _extractRecentEvents(data[_eventsField], cutoffMs)
        ..add(nowMs)
        ..sort();

      if (events.length > _maxStoredEvents) {
        events.removeRange(0, events.length - _maxStoredEvents);
      }

      tx.set(ref, {
        _eventsField: events,
        _countField: events.length,
        'last_cancelled_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return events.length;
    });
  }

  static Future<DocumentReference<Map<String, dynamic>>?> _resolveUserRef({
    required String whatsapp,
    String? uid,
  }) async {
    final users = FirebaseFirestore.instance.collection('users');
    final normalizedUid = (uid ?? '').trim();
    if (normalizedUid.isNotEmpty) {
      final uidRef = users.doc(normalizedUid);
      final uidSnap = await uidRef.get();
      if (uidSnap.exists) return uidRef;

      final uidQuery = await users
          .where('uid', isEqualTo: normalizedUid)
          .limit(1)
          .get();
      if (uidQuery.docs.isNotEmpty) return uidQuery.docs.first.reference;
    }

    final normalizedWhatsapp = whatsapp.trim();
    if (normalizedWhatsapp.isEmpty) return null;

    final whatsappQuery = await users
        .where('whatsapp', isEqualTo: normalizedWhatsapp)
        .limit(1)
        .get();
    if (whatsappQuery.docs.isNotEmpty) {
      return whatsappQuery.docs.first.reference;
    }

    final whatsappRef = users.doc(normalizedWhatsapp);
    final whatsappSnap = await whatsappRef.get();
    if (whatsappSnap.exists) return whatsappRef;

    if (normalizedUid.isNotEmpty) return users.doc(normalizedUid);
    return whatsappRef;
  }

  static List<int> _extractRecentEvents(dynamic raw, int cutoffMs) {
    if (raw is! List) return <int>[];
    final out = <int>[];
    for (final value in raw) {
      final ms = _toMilliseconds(value);
      if (ms != null && ms >= cutoffMs) out.add(ms);
    }
    out.sort();
    return out;
  }

  static int? _toMilliseconds(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    return null;
  }

  static bool _hasEventsChanged(dynamic raw, List<int> events) {
    if (raw is! List) return events.isNotEmpty;
    if (raw.length != events.length) return true;
    for (int i = 0; i < events.length; i++) {
      final rawMs = _toMilliseconds(raw[i]);
      if (rawMs != events[i]) return true;
    }
    return false;
  }
}
