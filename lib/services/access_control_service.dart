// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AccessDecision {
  final bool allowed;
  final String reason;
  final String country;
  final bool vpn;

  const AccessDecision({
    required this.allowed,
    this.reason = 'ok',
    this.country = '',
    this.vpn = false,
  });

  const AccessDecision.allow()
      : allowed = true,
        reason = 'ok',
        country = '',
        vpn = false;
}

class AccessControlService {
  static const Duration _timeout = Duration(seconds: 8);

  static Future<AccessDecision> checkAccess() async {
    try {
      final projectId = Firebase.app().options.projectId;
      if (projectId.isEmpty) return const AccessDecision.allow();

      final uri = Uri.parse(
        'https://us-central1-$projectId.cloudfunctions.net/checkAccess',
      );

      final resp = await http.get(uri).timeout(_timeout);
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        return const AccessDecision.allow();
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final allowed = data['allowed'] == true;
      return AccessDecision(
        allowed: allowed,
        reason: (data['reason'] ?? 'unknown').toString(),
        country: (data['country'] ?? '').toString(),
        vpn: data['vpn'] == true,
      );
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Access check failed: $e');
      }
      return const AccessDecision.allow();
    }
  }
}
