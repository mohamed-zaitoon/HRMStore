// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:cloud_firestore/cloud_firestore.dart';

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

    final enabled = data['enabled'] == null ? true : data['enabled'] == true;
    final maintenanceMessage =
        (data['maintenance_message'] ?? 'الشحن غير متاح حاليا صيانه')
            .toString();

    if (!enabled) {
      return AvailabilityDecision(
        allowed: false,
        message: maintenanceMessage,
        maintenance: true,
      );
    }

    return const AvailabilityDecision.allow();
  }
}
