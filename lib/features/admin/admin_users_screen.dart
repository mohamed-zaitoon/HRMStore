// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/tt_colors.dart';
import '../../widgets/glass_app_bar.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/top_snackbar.dart';

class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});

  Map<String, dynamic> _normalizeUser(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
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
      'created_at': data['created_at'],
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GlassAppBar(title: Text('بيانات المستخدمين')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('لا توجد بيانات مستخدمين'));
          }

          // أزل التكرار بالاعتماد على رقم الواتساب، احتفظ بأحدث سجل
          final Map<String, Map<String, dynamic>> unique = {};
          for (final doc in docs) {
            final u = _normalizeUser(doc);
            final key = u['whatsapp'] as String;
            final existing = unique[key];
            if (existing == null) {
              unique[key] = u;
            } else {
              final at = existing['created_at'];
              final bt = u['created_at'];
              if (bt is Timestamp &&
                  at is Timestamp &&
                  bt.compareTo(at) > 0) {
                unique[key] = u;
              }
            }
          }

          final items = unique.values.toList()
            ..sort((a, b) {
              final at = a['created_at'];
              final bt = b['created_at'];
              if (at is Timestamp && bt is Timestamp) {
                return bt.compareTo(at);
              }
              return 0;
            });

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final user = items[index];
              final name = user['name'] as String;
              final whatsapp = user['whatsapp'] as String;
              final tiktok = user['tiktok'] as String;
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
                        color: TTColors.textWhite,
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
                            style: TextStyle(color: TTColors.textGray),
                          ),
                        ),
                        IconButton(
                          tooltip: 'نسخ',
                          icon: const Icon(Icons.copy, size: 18),
                          color: TTColors.primaryCyan,
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
                      style: TextStyle(color: TTColors.textGray),
                    ),
                  ],
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemCount: items.length,
          );
        },
      ),
    );
  }
}
