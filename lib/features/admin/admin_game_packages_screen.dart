// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/tt_colors.dart';
import '../../models/game_package.dart';
import '../../widgets/glass_app_bar.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/top_snackbar.dart';

class AdminGamePackagesScreen extends StatefulWidget {
  const AdminGamePackagesScreen({super.key});

  @override
  State<AdminGamePackagesScreen> createState() =>
      _AdminGamePackagesScreenState();
}

class _AdminGamePackagesScreenState extends State<AdminGamePackagesScreen> {
  bool _seeding = false;

  Future<void> _openEditor({GamePackage? package}) async {
    final isNew = package == null;
    final gameValue = ValueNotifier<String>(
      package?.game.isNotEmpty == true ? package!.game : 'pubg',
    );
    final labelCtrl = TextEditingController(text: package?.label ?? '');
    final qtyCtrl =
        TextEditingController(text: package?.quantity.toString() ?? '');
    final priceCtrl =
        TextEditingController(text: package?.price.toString() ?? '');
    bool enabled = package?.enabled ?? true;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: TTColors.cardBg,
          title: Text(isNew ? "إضافة باقة" : "تعديل باقة"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<String>(
                  valueListenable: gameValue,
                  builder: (_, value, __) {
                    return DropdownButtonFormField<String>(
                      initialValue: value,
                      decoration: const InputDecoration(labelText: "اللعبة"),
                      items: GamePackage.gameOrder()
                          .map(
                            (g) => DropdownMenuItem(
                              value: g,
                              child: Text(GamePackage.gameLabel(g)),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) gameValue.value = v;
                      },
                    );
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(labelText: "اسم الباقة"),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "الكمية"),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: priceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: "السعر (جنيه)"),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  value: enabled,
                  onChanged: (v) => setDialogState(() => enabled = v),
                  title: const Text("تفعيل الباقة"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("إلغاء"),
            ),
            ElevatedButton(
              onPressed: () async {
                final label = labelCtrl.text.trim();
                final qty = int.tryParse(qtyCtrl.text.trim());
                final price = double.tryParse(priceCtrl.text.trim());

                if (label.isEmpty || qty == null || price == null) {
                  TopSnackBar.show(
                    context,
                    "الرجاء إدخال البيانات بشكل صحيح",
                    backgroundColor: Colors.red,
                    textColor: Colors.white,
                    icon: Icons.error,
                  );
                  return;
                }

                final data = {
                  'game': gameValue.value,
                  'label': label,
                  'quantity': qty,
                  'price': price,
                  'enabled': enabled,
                  'sort': qty,
                  'updated_at': FieldValue.serverTimestamp(),
                };

                final col =
                    FirebaseFirestore.instance.collection('game_packages');
                if (package == null) {
                  await col.add({
                    ...data,
                    'created_at': FieldValue.serverTimestamp(),
                  });
                } else {
                  await col.doc(package.id).set(
                        data,
                        SetOptions(merge: true),
                      );
                }

                if (mounted) {
                  Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: TTColors.primaryCyan,
                foregroundColor: Colors.black,
              ),
              child: const Text("حفظ"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _seedDefaults() async {
    setState(() => _seeding = true);
    try {
      final defaults = <Map<String, dynamic>>[
        // PUBG
        {'game': 'pubg', 'label': '60 UC', 'quantity': 60},
        {'game': 'pubg', 'label': '325 UC', 'quantity': 325},
        {'game': 'pubg', 'label': '660 UC', 'quantity': 660},
        {'game': 'pubg', 'label': '1800 UC', 'quantity': 1800},
        {'game': 'pubg', 'label': '3850 UC', 'quantity': 3850},
        {'game': 'pubg', 'label': '8100 UC', 'quantity': 8100},
        // Call of Duty
        {'game': 'cod', 'label': '80 CP', 'quantity': 80},
        {'game': 'cod', 'label': '420 CP', 'quantity': 420},
        {'game': 'cod', 'label': '880 CP', 'quantity': 880},
        {'game': 'cod', 'label': '2400 CP', 'quantity': 2400},
        {'game': 'cod', 'label': '5000 CP', 'quantity': 5000},
        {'game': 'cod', 'label': '10800 CP', 'quantity': 10800},
        // Free Fire
        {'game': 'freefire', 'label': '100 Diamonds', 'quantity': 100},
        {'game': 'freefire', 'label': '210 Diamonds', 'quantity': 210},
        {'game': 'freefire', 'label': '530 Diamonds', 'quantity': 530},
        {'game': 'freefire', 'label': '1080 Diamonds', 'quantity': 1080},
        {'game': 'freefire', 'label': '2200 Diamonds', 'quantity': 2200},
      ];

      final col = FirebaseFirestore.instance.collection('game_packages');
      final batch = FirebaseFirestore.instance.batch();
      for (final item in defaults) {
        final doc = col.doc();
        batch.set(doc, {
          ...item,
          'price': 0,
          'enabled': true,
          'sort': item['quantity'],
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      if (!mounted) return;
      TopSnackBar.show(
        context,
        "تمت إضافة الباقات الافتراضية ✅",
        backgroundColor: Colors.green,
        textColor: Colors.white,
        icon: Icons.check_circle,
      );
    } catch (_) {
      if (!mounted) return;
      TopSnackBar.show(
        context,
        "فشل إضافة الباقات",
        backgroundColor: Colors.red,
        textColor: Colors.white,
        icon: Icons.error,
      );
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlassAppBar(
        title: const Text("شحن الألعاب"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openEditor(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('game_packages')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("خطأ: ${snapshot.error}"));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final packages = snapshot.data!.docs
              .map((d) => GamePackage.fromDoc(d))
              .toList()
            ..sort((a, b) {
              final order = {
                'pubg': 0,
                'freefire': 1,
                'cod': 2,
              };
              final g1 = order[a.game] ?? 9;
              final g2 = order[b.game] ?? 9;
              if (g1 != g2) return g1.compareTo(g2);
              return a.sort.compareTo(b.sort);
            });

          if (packages.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("لا توجد باقات حتى الآن"),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _seeding ? null : _seedDefaults,
                    icon: _seeding
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_fix_high),
                    label: const Text("إضافة الباقات الافتراضية"),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ...packages.map((pkg) {
                return GlassCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  child: ListTile(
                    title: Text(
                      "${GamePackage.gameLabel(pkg.game)} - ${pkg.label}",
                      style: const TextStyle(fontFamily: 'Cairo'),
                    ),
                    subtitle: Text(
                      "الكمية: ${pkg.quantity} | السعر: ${pkg.price} جنيه",
                      style: TextStyle(color: TTColors.textGray),
                    ),
                    trailing: Icon(
                      pkg.enabled ? Icons.check_circle : Icons.pause_circle,
                      color:
                          pkg.enabled ? Colors.green : Colors.orangeAccent,
                    ),
                    onTap: () => _openEditor(package: pkg),
                  ),
                );
              }).toList(),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _seeding ? null : _seedDefaults,
                icon: const Icon(Icons.auto_fix_high),
                label: const Text("إضافة الباقات الافتراضية"),
              ),
            ],
          );
        },
      ),
    );
  }
}
