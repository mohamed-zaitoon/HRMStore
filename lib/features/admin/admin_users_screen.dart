// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/glass_app_bar.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/snow_background.dart';
import '../../widgets/top_snackbar.dart';

class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});

  String _normalizeWhatsapp(String value) {
    return value.replaceAll(RegExp(r'[^0-9+]'), '').trim();
  }

  String _userKeyFromWhatsapp(String value) {
    final normalized = _normalizeWhatsapp(value);
    if (normalized.isNotEmpty) return normalized;
    return value.trim();
  }

  int _toInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse((raw ?? '').toString().trim()) ?? 0;
  }

  Timestamp? _latestTimestamp(Map<String, dynamic> user) {
    final updated = user['updated_at'];
    if (updated is Timestamp) return updated;
    final created = user['created_at'];
    if (created is Timestamp) return created;
    return null;
  }

  Map<String, dynamic> _normalizeUser(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final whatsapp = (data['whatsapp'] ?? doc.id).toString();
    final rawName = (data['name'] ?? '').toString();
    final tiktokVal = (data['tiktok'] ?? '').toString();
    final displayName = rawName.isNotEmpty
        ? rawName
        : (data['display_name'] ?? tiktokVal).toString().isNotEmpty
        ? (data['display_name'] ?? tiktokVal).toString()
        : whatsapp;
    return {
      'whatsapp': whatsapp,
      'name': displayName,
      'tiktok': tiktokVal,
      'balance_points': _toInt(data['balance_points']),
      'created_at': data['created_at'],
      'updated_at': data['updated_at'],
    };
  }

  Map<String, int> _buildOrdersCount(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final counts = <String, int>{};
    for (final doc in docs) {
      final data = doc.data();
      final whatsapp = (data['user_whatsapp'] ?? data['whatsapp'] ?? '')
          .toString()
          .trim();
      final key = _userKeyFromWhatsapp(whatsapp);
      if (key.isEmpty) continue;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: const GlassAppBar(title: Text('بيانات المستخدمين')),
      body: Stack(
        children: [
          const SnowBackground(),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, usersSnapshot) {
              if (!usersSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final userDocs = usersSnapshot.data!.docs;
              if (userDocs.isEmpty) {
                return const Center(child: Text('لا توجد بيانات مستخدمين'));
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .snapshots(),
                builder: (context, ordersSnapshot) {
                  final orderCounts = ordersSnapshot.hasData
                      ? _buildOrdersCount(ordersSnapshot.data!.docs)
                      : <String, int>{};

                  // أزل التكرار بالاعتماد على رقم الواتساب، واحتفظ بالأحدث (updated_at ثم created_at)
                  final Map<String, Map<String, dynamic>> unique = {};
                  for (final doc in userDocs) {
                    final user = _normalizeUser(doc);
                    final whatsapp = (user['whatsapp'] ?? '').toString();
                    final key = _userKeyFromWhatsapp(whatsapp);
                    if (key.isEmpty) continue;

                    final existing = unique[key];
                    if (existing == null) {
                      unique[key] = user;
                      continue;
                    }

                    final existingTs = _latestTimestamp(existing);
                    final incomingTs = _latestTimestamp(user);
                    if (incomingTs != null &&
                        (existingTs == null ||
                            incomingTs.compareTo(existingTs) > 0)) {
                      unique[key] = user;
                    }
                  }

                  final items = unique.values.toList()
                    ..sort((a, b) {
                      final at = _latestTimestamp(a);
                      final bt = _latestTimestamp(b);
                      if (at != null && bt != null) return bt.compareTo(at);
                      if (bt != null) return 1;
                      if (at != null) return -1;
                      return 0;
                    });

                  final content = ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final user = items[index];
                      final name = (user['name'] ?? '').toString();
                      final whatsapp = (user['whatsapp'] ?? '').toString();
                      final tiktok = (user['tiktok'] ?? '').toString();
                      final balancePoints = _toInt(user['balance_points']);
                      final totalOrders =
                          orderCounts[_userKeyFromWhatsapp(whatsapp)] ?? 0;

                      return GlassCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isEmpty ? 'بدون اسم' : name,
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'واتساب: $whatsapp',
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'نسخ',
                                  icon: const Icon(Icons.copy, size: 18),
                                  color: colorScheme.primary,
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(text: whatsapp),
                                    );
                                    TopSnackBar.show(
                                      context,
                                      'تم نسخ رقم الواتساب',
                                      icon: Icons.copy,
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'تيك توك: ${tiktok.isEmpty ? '-' : tiktok}',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                _statChip(
                                  context: context,
                                  icon: Icons.account_balance_wallet_rounded,
                                  text: 'الرصيد: $balancePoints نقطة',
                                ),
                                _statChip(
                                  context: context,
                                  icon: Icons.receipt_long_rounded,
                                  text: 'إجمالي الطلبات: $totalOrders',
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                    separatorBuilder: (_, index) => const SizedBox(height: 10),
                    itemCount: items.length,
                  );

                  if (!kIsWeb) return content;

                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 920),
                      child: content,
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _statChip({
    required BuildContext context,
    required IconData icon,
    required String text,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primary.withAlpha(24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.primary.withAlpha(72)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 12,
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
