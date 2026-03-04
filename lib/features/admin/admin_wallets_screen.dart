// Open-source code. Copyright Mohamed Zaitoon 2025-2026.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../widgets/glass_app_bar.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/snow_background.dart';
import '../../widgets/top_snackbar.dart';

class AdminWalletsScreen extends StatelessWidget {
  const AdminWalletsScreen({super.key});

  // EN: Extracts every wallet number stored in a wallets document,
  //     whether it's a single 'number', a list under 'numbers',
  //     or multiple values combined in one string; returns unique, trimmed values.
  // AR: يستخرج كل أرقام المحافظ داخل مستند wallets سواء كانت في حقل مفرد
  //     باسم number أو في قائمة numbers أو مجمعة كسلسلة نصية؛ يعيد القيم
  //     بعد تنظيفها وإزالة التكرار.
  List<String> _extractWallets(Map<String, dynamic> data, String docId) {
    final List<String> wallets = [];

    void addIfValid(dynamic v) {
      if (v is String && v.trim().isNotEmpty) {
        wallets.add(v.trim());
      } else if (v is num) {
        wallets.add(v.toString());
      }
    }

    if (data['number'] != null) addIfValid(data['number']);

    if (data['numbers'] is List) {
      for (final v in (data['numbers'] as List)) {
        addIfValid(v);
      }
    }

    // If a single string field contains multiple numbers separated by spaces/commas/newlines.
    if (wallets.isEmpty && data['number'] is String) {
      final parts = (data['number'] as String)
          .split(RegExp(r'[\\s,;\\n]+'))
          .where((e) => e.trim().isNotEmpty);
      wallets.addAll(parts);
    }

    // As a last resort pick any string/num field in the doc.
    if (wallets.isEmpty) {
      for (final entry in data.entries) {
        addIfValid(entry.value);
      }
    }

    if (wallets.isEmpty) wallets.add(docId);
    return wallets.toSet().toList(); // ensure unique
  }

  // EN: Chooses a readable label for the wallet card using label/provider/name,
  //     falling back to the document ID if none are provided.
  // AR: يحدد تسمية واضحة لبطاقة المحفظة بالاعتماد على الحقول label أو provider أو name،
  //     ويعود إلى معرّف المستند إذا لم تتوفر أي تسمية.
  String _extractLabel(Map<String, dynamic> data, String docId) {
    final label = data['label'] ?? data['provider'] ?? data['name'];
    if (label is String && label.trim().isNotEmpty) return label.trim();
    return docId;
  }

  // EN: Builds the admin wallets screen: listens to Firestore, flattens all wallet
  //     numbers into a list, and renders copy-friendly cards for each entry.
  // AR: يبني شاشة محافظ الأدمن: يستمع لتحديثات Firestore، يجمع كل الأرقام في قائمة،
  //     ويعرض بطاقات قابلة للنسخ لكل رقم على حدة.
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: const GlassAppBar(title: Text("المحافظ 💳")),
      body: Stack(
        children: [
          const SnowBackground(),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('wallets')
                .snapshots(),
            builder: (ctx, snap) {
              if (snap.hasError) {
                return const Center(child: Text('خطأ في جلب البيانات'));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return const Center(child: Text('لا توجد محافظ مضافة بعد'));
              }

              final List<_WalletEntry> items = [];
              for (final doc in docs) {
                final data = doc.data();
                final label = _extractLabel(data, doc.id);
                for (final w in _extractWallets(data, doc.id)) {
                  items.add(_WalletEntry(label: label, number: w));
                }
              }

              if (items.isEmpty) {
                return const Center(child: Text('لا توجد محافظ مضافة بعد'));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                physics: const BouncingScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (context, _) => const SizedBox(height: 12),
                itemBuilder: (c, i) {
                  final item = items[i];

                  return GlassCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: colorScheme.primaryContainer,
                          foregroundColor: colorScheme.onPrimaryContainer,
                          child: const Icon(Icons.account_balance_wallet),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.label,
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.number,
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy),
                          color: colorScheme.primary,
                          tooltip: 'نسخ',
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: item.number),
                            );
                            if (c.mounted) {
                              TopSnackBar.show(
                                c,
                                'تم نسخ رقم المحفظة',
                                backgroundColor: Colors.green,
                                textColor: Colors.white,
                                icon: Icons.check,
                              );
                            }
                          },
                        ),
                      ],
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
}

class _WalletEntry {
  final String label;
  final String number;
  _WalletEntry({required this.label, required this.number});
}
