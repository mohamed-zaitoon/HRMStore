// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'device_service.dart';

class AdminSessionService {
  // EN: Handles logout Current Device.
  // AR: تتعامل مع logout Current Device.
  static Future<void> logoutCurrentDevice(String adminId) async {
    final deviceId = await DeviceService.getDeviceId();

    await FirebaseFirestore.instance
        .collection('admins')
        .doc(adminId)
        .collection('sessions')
        .doc(deviceId)
        .delete();
  }
}
