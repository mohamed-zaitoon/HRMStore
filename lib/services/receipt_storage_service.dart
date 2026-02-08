// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class ReceiptUploadResult {
  final String url;
  final String path;

  ReceiptUploadResult({required this.url, required this.path});
}

class ReceiptStorageService {
  // EN: Uploads receipt to Firebase Storage.
  // AR: ترفع إيصال الدفع إلى Firebase Storage.
  static Future<ReceiptUploadResult?> uploadWithPath({
    required Uint8List bytes,
    required String whatsapp,
    String? orderId,
  }) async {
    try {
      final safeWhatsapp =
          whatsapp.replaceAll(RegExp(r'[^0-9+]'), '').trim();
      final owner = safeWhatsapp.isEmpty ? 'unknown' : safeWhatsapp;
      final id = (orderId != null && orderId.isNotEmpty)
          ? orderId
          : DateTime.now().millisecondsSinceEpoch.toString();

      final ref = FirebaseStorage.instance
          .ref()
          .child('receipts')
          .child(owner)
          .child('$id.jpg');

      final metadata = SettableMetadata(contentType: 'image/jpeg');
      final task = await ref.putData(bytes, metadata);
      if (task.state != TaskState.success) return null;

      final url = await ref.getDownloadURL();
      return ReceiptUploadResult(url: url, path: ref.fullPath);
    } catch (_) {
      return null;
    }
  }

  /// Backward-compatible: returns only URL.
  static Future<String?> upload({
    required Uint8List bytes,
    required String whatsapp,
    String? orderId,
  }) async {
    final res =
        await uploadWithPath(bytes: bytes, whatsapp: whatsapp, orderId: orderId);
    return res?.url;
  }

  static Future<void> deleteByPath(String path) async {
    if (path.isEmpty) return;
    try {
      await FirebaseStorage.instance.ref(path).delete();
    } catch (_) {
      // ignore
    }
  }

  static Future<void> deleteByUrl(String url) async {
    if (url.isEmpty) return;
    try {
      await FirebaseStorage.instance.refFromURL(url).delete();
    } catch (_) {
      // ignore
    }
  }
}
