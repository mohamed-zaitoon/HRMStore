// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class NetworkHealthService {
  static final Uri _firestoreUri = Uri.parse(
    'https://firestore.googleapis.com',
  );

  // EN: Verifies Firestore endpoint reachability (DNS + TLS + HTTP).
  // AR: يتحقق من إمكانية الوصول إلى Firestore (DNS + TLS + HTTP).
  static Future<bool> canReachFirestore({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    try {
      final response = await http.head(_firestoreUri).timeout(timeout);
      return response.statusCode > 0 && response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  // EN: Toggles Firestore network and returns true if operation succeeds.
  // AR: يفعّل/يعطّل شبكة Firestore ويعيد true عند نجاح العملية.
  static Future<bool> setFirestoreNetwork({required bool enabled}) async {
    try {
      if (enabled) {
        await FirebaseFirestore.instance.enableNetwork();
      } else {
        await FirebaseFirestore.instance.disableNetwork();
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
