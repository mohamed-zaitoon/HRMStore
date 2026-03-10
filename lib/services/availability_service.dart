// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, kReleaseMode;

class AvailabilityDecision {
  final bool allowed;
  final String message;
  final bool maintenance;

  const AvailabilityDecision({
    required this.allowed,
    required this.message,
    required this.maintenance,
  });

  const AvailabilityDecision.allow()
    : allowed = true,
      message = '',
      maintenance = false;
}

class AvailabilityService {
  AvailabilityService._();

  static final _doc = FirebaseFirestore.instance
      .collection('app_settings')
      .doc('availability');
  static const String _defaultMaintenanceMessage =
      'الشحن غير متاح حالياً بسبب صيانة.';
  static const String _defaultPlatformPauseMessage =
      'الخدمة متوقفة مؤقتاً حالياً (ليست صيانة).';

  static Stream<AvailabilityDecision> stream() {
    return _doc.snapshots().map(_fromSnapshot);
  }

  // EN: Checks latest availability on demand.
  // AR: تفحص أحدث حالة توافر عند الطلب.
  static Future<AvailabilityDecision> checkNow() async {
    try {
      final snapshot = await _doc.get(const GetOptions(source: Source.server));
      return _fromSnapshot(snapshot);
    } catch (_) {
      final snapshot = await _doc.get();
      return _fromSnapshot(snapshot);
    }
  }

  static AvailabilityDecision _fromSnapshot(DocumentSnapshot snapshot) {
    if (!snapshot.exists) return const AvailabilityDecision.allow();
    final data = snapshot.data() as Map<String, dynamic>? ?? {};

    if (!kReleaseMode) {
      return const AvailabilityDecision.allow();
    }

    const android = TargetPlatform.android;
    final isAndroidRelease = !kIsWeb && defaultTargetPlatform == android;

    final enabled = data['enabled'] == null ? true : data['enabled'] == true;
    final maintenanceMessage =
        (data['maintenance_message'] ?? _defaultMaintenanceMessage)
            .toString()
            .trim();
    if (!enabled && (kIsWeb || isAndroidRelease)) {
      return AvailabilityDecision(
        allowed: false,
        message: maintenanceMessage.isEmpty
            ? _defaultMaintenanceMessage
            : maintenanceMessage,
        maintenance: true,
      );
    }

    final platformPauseMessage =
        (data['platform_pause_message'] ?? _defaultPlatformPauseMessage)
            .toString()
            .trim();

    final webEnabled = data['web_enabled'] == null ? true : data['web_enabled'] == true;
    final webPauseMessage = (data['web_pause_message'] ?? platformPauseMessage)
        .toString()
        .trim();
    if (kIsWeb && !webEnabled) {
      return AvailabilityDecision(
        allowed: false,
        message: webPauseMessage.isEmpty
            ? _defaultPlatformPauseMessage
            : webPauseMessage,
        maintenance: false,
      );
    }
    final androidReleaseEnabled = data['android_release_enabled'] == null
        ? true
        : data['android_release_enabled'] == true;
    final androidReleasePauseMessage =
        (data['android_release_pause_message'] ?? platformPauseMessage)
            .toString()
            .trim();
    if (isAndroidRelease && !androidReleaseEnabled) {
      return AvailabilityDecision(
        allowed: false,
        message: androidReleasePauseMessage.isEmpty
            ? _defaultPlatformPauseMessage
            : androidReleasePauseMessage,
        maintenance: false,
      );
    }

    return const AvailabilityDecision.allow();
  }
}
