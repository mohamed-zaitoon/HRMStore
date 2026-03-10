// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_service.dart';

class AdminSessionData {
  final String adminId;
  final String username;
  final String whatsapp;
  final DateTime expiryAt;

  const AdminSessionData({
    required this.adminId,
    required this.username,
    required this.whatsapp,
    required this.expiryAt,
  });
}

class AdminSessionService {
  static const String _kAdminId = 'admin_id';
  static const String _kAdminUsername = 'admin_username';
  static const String _kAdminWhatsapp = 'admin_whatsapp';
  static const String _kAdminExpiry = 'admin_expiry';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static Future<void> saveLocalSession({
    required String adminId,
    required String username,
    required String whatsapp,
    required DateTime expiryAt,
  }) async {
    await _writeSecure(_kAdminId, adminId.trim());
    await _writeSecure(_kAdminUsername, username.trim());
    await _writeSecure(_kAdminWhatsapp, whatsapp.trim());
    await _writeSecure(_kAdminExpiry, expiryAt.toIso8601String());

    final prefs = await SharedPreferences.getInstance();
    await _clearLegacyPrefs(prefs);
  }

  static Future<AdminSessionData?> getLocalSession() async {
    await migrateFromLegacyPrefsIfNeeded();

    final adminId = await _readSecure(_kAdminId);
    final username = await _readSecure(_kAdminUsername);
    final whatsapp = await _readSecure(_kAdminWhatsapp);
    final expiryStr = await _readSecure(_kAdminExpiry);

    final parsedExpiry = DateTime.tryParse(expiryStr ?? '');
    if (adminId == null ||
        adminId.trim().isEmpty ||
        parsedExpiry == null ||
        parsedExpiry.isBefore(DateTime.now())) {
      return null;
    }

    return AdminSessionData(
      adminId: adminId.trim(),
      username: (username ?? '').trim(),
      whatsapp: (whatsapp ?? '').trim(),
      expiryAt: parsedExpiry,
    );
  }

  static Future<String?> getLocalAdminId() async {
    final session = await getLocalSession();
    return session?.adminId;
  }

  static Future<bool> validateCurrentSession() async {
    final session = await getLocalSession();
    if (session == null) {
      await clearLocalSession();
      return false;
    }

    if (DateTime.now().isAfter(session.expiryAt)) {
      await clearLocalSession();
      return false;
    }

    final serverOk = await _isServerSessionValid(session.adminId);
    if (!serverOk) {
      await clearLocalSession();
      return false;
    }

    return true;
  }

  // EN: Handles logout Current Device.
  // AR: تتعامل مع logout Current Device.
  static Future<void> logoutCurrentDevice([String? adminId]) async {
    final String resolvedAdminId = (adminId ?? '').trim().isNotEmpty
        ? adminId!.trim()
        : (await getLocalAdminId() ?? '');
    if (resolvedAdminId.isEmpty) return;

    final deviceId = await DeviceService.getDeviceId();

    await FirebaseFirestore.instance
        .collection('admins')
        .doc(resolvedAdminId)
        .collection('sessions')
        .doc(deviceId)
        .delete()
        .catchError((_) {});
  }

  static Future<void> clearLocalSession() async {
    await _deleteSecure(_kAdminId);
    await _deleteSecure(_kAdminUsername);
    await _deleteSecure(_kAdminWhatsapp);
    await _deleteSecure(_kAdminExpiry);

    final prefs = await SharedPreferences.getInstance();
    await _clearLegacyPrefs(prefs);
  }

  static Future<void> migrateFromLegacyPrefsIfNeeded() async {
    final secureAdminId = await _readSecure(_kAdminId);
    if ((secureAdminId ?? '').trim().isNotEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final adminId = (prefs.getString(_kAdminId) ?? '').trim();
    if (adminId.isEmpty) return;

    final username = (prefs.getString(_kAdminUsername) ?? '').trim();
    final whatsapp = (prefs.getString(_kAdminWhatsapp) ?? '').trim();
    final expiryStr = (prefs.getString(_kAdminExpiry) ?? '').trim();
    final expiryDate =
        DateTime.tryParse(expiryStr) ??
        DateTime.now().add(const Duration(hours: 12));

    await saveLocalSession(
      adminId: adminId,
      username: username,
      whatsapp: whatsapp,
      expiryAt: expiryDate,
    );
  }

  static Future<bool> _isServerSessionValid(String adminId) async {
    final deviceId = await DeviceService.getDeviceId();
    if (deviceId.trim().isEmpty) return false;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(adminId.trim())
          .collection('sessions')
          .doc(deviceId)
          .get();

      if (!doc.exists) return false;
      final data = doc.data() ?? <String, dynamic>{};
      final expiry = data['expiry_at'];
      if (expiry is Timestamp && DateTime.now().isAfter(expiry.toDate())) {
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _writeSecure(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (_) {}
  }

  static Future<String?> _readSecure(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _deleteSecure(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (_) {}
  }

  static Future<void> _clearLegacyPrefs(SharedPreferences prefs) async {
    await prefs.remove(_kAdminId);
    await prefs.remove(_kAdminUsername);
    await prefs.remove(_kAdminWhatsapp);
    await prefs.remove(_kAdminExpiry);
  }
}
