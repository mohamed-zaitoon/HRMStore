// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:convert';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'remote_config_service.dart';

class ReceiptUploadResult {
  final String url;
  final String path;

  ReceiptUploadResult({required this.url, required this.path});
}

class ReceiptStorageService {
  static const String _imgBbPathPrefix = 'imgbb:';

  // EN: Uploads receipt to Firebase Storage.
  // AR: ترفع إيصال الدفع إلى Firebase Storage.
  static Future<ReceiptUploadResult?> uploadWithPath({
    required Uint8List bytes,
    required String whatsapp,
    String? orderId,
  }) async {
    final safeWhatsapp = whatsapp.replaceAll(RegExp(r'[^0-9+]'), '').trim();
    final owner = safeWhatsapp.isEmpty ? 'unknown' : safeWhatsapp;
    final id = (orderId != null && orderId.isNotEmpty)
        ? orderId
        : DateTime.now().millisecondsSinceEpoch.toString();

    final firebaseRes = await _uploadToFirebase(
      bytes: bytes,
      owner: owner,
      id: id,
    );
    if (firebaseRes != null) return firebaseRes;

    return _uploadToImgBb(bytes: bytes, owner: owner, id: id);
  }

  static Future<ReceiptUploadResult?> _uploadToFirebase({
    required Uint8List bytes,
    required String owner,
    required String id,
  }) async {
    try {
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
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ReceiptStorageService: Firebase upload failed ($e)');
      }
      return null;
    }
  }

  static Future<ReceiptUploadResult?> _uploadToImgBb({
    required Uint8List bytes,
    required String owner,
    required String id,
  }) async {
    try {
      String apiKey = '';
      int expiration = 0;
      try {
        apiKey = RemoteConfigService.instance.imgbbApiKey;
        expiration = RemoteConfigService.instance.imgbbExpiration;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('ReceiptStorageService: Remote Config not ready ($e)');
        }
      }

      if (apiKey.trim().isEmpty) {
        if (kDebugMode) {
          debugPrint('ReceiptStorageService: imgBB API key is empty');
        }
        return null;
      }

      final uri = Uri.https('api.imgbb.com', '/1/upload', {
        'key': apiKey.trim(),
        if (expiration > 0) 'expiration': expiration.toString(),
      });

      final response = await http.post(
        uri,
        body: <String, String>{
          'image': base64Encode(bytes),
          'name': 'receipt_${owner}_$id',
        },
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (kDebugMode) {
          debugPrint(
            'ReceiptStorageService: imgBB upload failed (${response.statusCode})',
          );
        }
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;

      final dynamic data = decoded['data'];
      if (data is! Map) return null;

      final url = (data['url'] ?? data['display_url'] ?? '').toString().trim();
      if (url.isEmpty) return null;

      final deleteUrl = (data['delete_url'] ?? '').toString().trim();
      final encodedDeleteUrl = deleteUrl.isEmpty
          ? ''
          : Uri.encodeComponent(deleteUrl);
      final syntheticPath = '$_imgBbPathPrefix$encodedDeleteUrl';

      return ReceiptUploadResult(url: url, path: syntheticPath);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ReceiptStorageService: imgBB upload error ($e)');
      }
      return null;
    }
  }

  /// Backward-compatible: returns only URL.
  static Future<String?> upload({
    required Uint8List bytes,
    required String whatsapp,
    String? orderId,
  }) async {
    final res = await uploadWithPath(
      bytes: bytes,
      whatsapp: whatsapp,
      orderId: orderId,
    );
    return res?.url;
  }

  static Future<void> deleteByPath(String path) async {
    if (path.isEmpty) return;
    if (path.startsWith(_imgBbPathPrefix)) {
      await _deleteImgBbByPath(path);
      return;
    }

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

  static Future<void> _deleteImgBbByPath(String path) async {
    try {
      final encodedDeleteUrl = path.substring(_imgBbPathPrefix.length).trim();
      if (encodedDeleteUrl.isEmpty) return;

      final deleteUrl = Uri.decodeComponent(encodedDeleteUrl);
      final uri = Uri.tryParse(deleteUrl);
      if (uri == null) return;

      await http.get(uri);
    } catch (_) {
      // ignore
    }
  }
}
