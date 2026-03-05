// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
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

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
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
    final email = (data['email'] ?? '').toString();
    final tiktokVal = (data['tiktok'] ?? '').toString();
    final username = (data['username'] ?? tiktokVal).toString();
    final displayName = rawName.isNotEmpty
        ? rawName
        : (data['display_name'] ?? tiktokVal).toString().isNotEmpty
        ? (data['display_name'] ?? tiktokVal).toString()
        : whatsapp;
    return {
      'whatsapp': whatsapp,
      'name': displayName,
      'email': email,
      'uid': (data['uid'] ?? '').toString(),
      'username': username,
      'tiktok': tiktokVal,
      'password_hash': (data['password_hash'] ?? '').toString(),
      'balance_points': _toInt(data['balance_points']),
      'created_at': data['created_at'],
      'updated_at': data['updated_at'],
      'ref': doc.reference,
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

  Future<void> _updateUser(
    BuildContext context,
    DocumentReference ref,
    Map<String, dynamic> data,
    String success,
  ) async {
    try {
      await ref.set({
        ...data,
        'status_updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      TopSnackBar.show(context, success, icon: Icons.check_circle);
    } catch (e) {
      TopSnackBar.show(
        context,
        'تعذر تحديث الحساب',
        icon: Icons.error,
        backgroundColor: Colors.red,
      );
    }
  }

  Future<void> _editUser(
    BuildContext context,
    Map<String, dynamic> user,
  ) async {
    final ref = user['ref'] as DocumentReference?;
    if (ref == null) return;

    final nameCtrl = TextEditingController(
      text: (user['name'] ?? '').toString(),
    );
    final waCtrl = TextEditingController(
      text: (user['whatsapp'] ?? '').toString(),
    );
    final emailCtrl = TextEditingController(
      text: (user['email'] ?? '').toString(),
    );
    final tiktokCtrl = TextEditingController(
      text: (user['tiktok'] ?? user['username'] ?? '').toString(),
    );
    final balanceCtrl = TextEditingController(
      text: (user['balance_points'] ?? 0).toString(),
    );
    final passwordCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('تعديل بيانات المستخدم'),
        content: Builder(
          builder: (dialogCtx) {
            final media = MediaQuery.of(dialogCtx);
            final maxHeight = media.size.height * 0.75;
            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: media.viewInsets.bottom + 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'الاسم'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: waCtrl,
                      decoration: const InputDecoration(
                        labelText: 'رقم الواتساب',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'البريد الإلكتروني',
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: tiktokCtrl,
                      decoration: const InputDecoration(
                        labelText: 'يوزر تيك توك',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: balanceCtrl,
                      decoration: const InputDecoration(
                        labelText: 'الرصيد (نقاط)',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: passwordCtrl,
                      decoration: const InputDecoration(
                        labelText: 'كلمة سر جديدة (اختياري)',
                        helperText: 'اتركها فارغة للإبقاء على الحالية',
                      ),
                      obscureText: true,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final wa = _normalizeWhatsapp(waCtrl.text);
              final bal = int.tryParse(balanceCtrl.text.trim());
              final newPassword = passwordCtrl.text.trim();
              if (wa.isEmpty || bal == null) {
                TopSnackBar.show(
                  context,
                  'أدخل رقم واتساب ورصيد صحيح',
                  icon: Icons.error,
                  backgroundColor: Colors.red,
                );
                return;
              }
              if (newPassword.isNotEmpty && newPassword.length < 6) {
                TopSnackBar.show(
                  context,
                  'كلمة السر يجب ألا تقل عن 6 أحرف',
                  icon: Icons.error,
                  backgroundColor: Colors.red,
                );
                return;
              }
              Navigator.pop(ctx);
              final update = <String, dynamic>{
                'name': nameCtrl.text.trim(),
                'whatsapp': wa,
                'tiktok': tiktokCtrl.text.trim(),
                'username': tiktokCtrl.text.trim(),
                'email': emailCtrl.text.trim().toLowerCase(),
                'balance_points': bal,
                'updated_at': FieldValue.serverTimestamp(),
              };

              if (newPassword.isNotEmpty) {
                update['password'] = newPassword;
                update['password_hash'] = _hashPassword(newPassword);
              }

              await _updateUser(context, ref, update, 'تم حفظ التعديلات');
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(
    BuildContext context,
    Map<String, dynamic> user,
  ) async {
    final ref = user['ref'] as DocumentReference?;
    if (ref == null) return;

    final whatsapp = (user['whatsapp'] ?? '').toString();
    final name = (user['name'] ?? '').toString();

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('حذف الحساب'),
            content: Text(
              'سيتم حذف حساب $name\nرقم واتساب: $whatsapp\nلا يمكن التراجع عن الحذف.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('تأكيد الحذف'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    try {
      await ref.delete();
      TopSnackBar.show(
        context,
        'تم حذف الحساب',
        icon: Icons.delete_forever,
        backgroundColor: Colors.red.shade700,
      );
    } catch (e) {
      TopSnackBar.show(
        context,
        'تعذر حذف الحساب',
        icon: Icons.error,
        backgroundColor: Colors.red,
      );
    }
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
                      final email = (user['email'] ?? '').toString();
                      final tiktok = (user['tiktok'] ?? '').toString();
                      final balancePoints = _toInt(user['balance_points']);
                      final totalOrders =
                          orderCounts[_userKeyFromWhatsapp(whatsapp)] ?? 0;
                      final ref = user['ref'] as DocumentReference?;

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
                            if (email.isNotEmpty) ...[
                              Text(
                                'البريد: $email',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
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
                            if (ref != null) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton(
                                    onPressed: () => _editUser(context, user),
                                    child: const Text('تعديل البيانات'),
                                  ),
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: BorderSide(
                                        color: Colors.red.withOpacity(0.7),
                                      ),
                                    ),
                                    onPressed: () => _deleteUser(context, user),
                                    child: const Text('حذف الحساب'),
                                  ),
                                ],
                              ),
                            ],
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
