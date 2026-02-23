// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../widgets/top_snackbar.dart';
import '../../widgets/glass_app_bar.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/snow_background.dart';

class AdminPricesScreen extends StatefulWidget {
  // EN: Creates AdminPricesScreen.
  // AR: ينشئ AdminPricesScreen.
  const AdminPricesScreen({super.key});

  // EN: Creates state object.
  // AR: تنشئ كائن الحالة.
  @override
  State<AdminPricesScreen> createState() => _AdminPricesScreenState();
}

class _PriceRange {
  final int min;
  final int max;

  const _PriceRange({required this.min, required this.max});
}

class _AdminPricesScreenState extends State<AdminPricesScreen> {
  final TextEditingController _costCtrl = TextEditingController();
  final TextEditingController _basePricePer1000Ctrl = TextEditingController();
  final TextEditingController _coinsCountCtrl = TextEditingController();
  bool _isSaving = false;
  bool _isEditing = false;
  double? _manualCalculatedCost;

  final List<double> _markups = const [19.23, 7.69, 2.88, 1.92, 0.96];
  final List<_PriceRange> _targetRanges = const [
    _PriceRange(min: 100, max: 499),
    _PriceRange(min: 500, max: 999),
    _PriceRange(min: 1000, max: 29999),
    _PriceRange(min: 50000, max: 74999),
    _PriceRange(min: 75000, max: 2500000),
  ];

  // EN: Releases resources.
  // AR: تفرّغ الموارد.
  @override
  void dispose() {
    _costCtrl.dispose();
    _basePricePer1000Ctrl.dispose();
    _coinsCountCtrl.dispose();
    super.dispose();
  }

  double? _parsePositive(String raw) {
    final value = double.tryParse(raw.trim().replaceAll(',', '.'));
    if (value == null || value <= 0) return null;
    return value;
  }

  // EN: Applies cost to all tiers.
  // AR: تطبق التكلفة على كل الشرائح.
  Future<void> _applyCost() async {
    final cost = _parsePositive(_costCtrl.text);
    if (cost == null) {
      TopSnackBar.show(
        context,
        "الرجاء إدخال سعر تكلفة صحيح",
        backgroundColor: Colors.red,
        textColor: Colors.white,
        icon: Icons.error,
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final docs = await _syncTargetRanges();

      if (docs.length != _markups.length) {
        if (!mounted) return;
        TopSnackBar.show(
          context,
          "عدد الشرائح (${docs.length}) لا يطابق عدد النِسب (${_markups.length})",
          backgroundColor: Colors.red,
          textColor: Colors.white,
          icon: Icons.error,
        );
        setState(() => _isSaving = false);
        return;
      }

      final batch = FirebaseFirestore.instance.batch();
      for (var i = 0; i < docs.length; i++) {
        final markup = _markups[i];
        final newPrice = double.parse(
          (cost * (1 + (markup / 100))).toStringAsFixed(2),
        );
        batch.update(docs[i].reference, {'pricePer1000': newPrice});
      }
      await batch.commit();

      await FirebaseFirestore.instance
          .collection('pricing_meta')
          .doc('current')
          .set({
            'cost_per_1000': cost,
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;
      TopSnackBar.show(
        context,
        "تم تحديث الأسعار ✅",
        backgroundColor: Colors.green,
        textColor: Colors.white,
        icon: Icons.check_circle,
      );
    } catch (e) {
      if (!mounted) return;
      TopSnackBar.show(
        context,
        "حدث خطأ أثناء التحديث",
        backgroundColor: Colors.red,
        textColor: Colors.white,
        icon: Icons.error,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<List<DocumentSnapshot<Map<String, dynamic>>>>
  _syncTargetRanges() async {
    final prices = FirebaseFirestore.instance.collection('prices');
    final snap = await prices.orderBy('min').get();
    final docs = snap.docs;
    final batch = FirebaseFirestore.instance.batch();
    bool changed = false;

    for (var i = 0; i < _targetRanges.length; i++) {
      final target = _targetRanges[i];
      if (i < docs.length) {
        final data = docs[i].data();
        final currentMin = (data['min'] as num?)?.toInt();
        final currentMax = (data['max'] as num?)?.toInt();
        if (currentMin != target.min || currentMax != target.max) {
          batch.update(docs[i].reference, {
            'min': target.min,
            'max': target.max,
          });
          changed = true;
        }
      } else {
        final fallbackPrice = docs.isNotEmpty
            ? ((docs.last.data()['pricePer1000'] as num?)?.toDouble() ?? 0.0)
            : 0.0;
        batch.set(prices.doc(), {
          'min': target.min,
          'max': target.max,
          'pricePer1000': fallbackPrice,
        });
        changed = true;
      }
    }

    if (docs.length > _targetRanges.length) {
      for (var i = _targetRanges.length; i < docs.length; i++) {
        batch.delete(docs[i].reference);
      }
      changed = true;
    }

    if (changed) {
      await batch.commit();
      final updated = await prices.orderBy('min').get();
      return updated.docs;
    }

    return docs;
  }

  void _calculateManualCost(BuildContext context) {
    final basePrice = _parsePositive(_basePricePer1000Ctrl.text);
    if (basePrice == null) {
      TopSnackBar.show(
        context,
        "أدخل سعر 1000 بدون مكسب بشكل صحيح",
        backgroundColor: Colors.red,
        textColor: Colors.white,
        icon: Icons.error,
      );
      return;
    }

    final coins = _parsePositive(_coinsCountCtrl.text);
    if (coins == null) {
      TopSnackBar.show(
        context,
        "أدخل عدد العملات بشكل صحيح",
        backgroundColor: Colors.red,
        textColor: Colors.white,
        icon: Icons.error,
      );
      return;
    }

    final totalCost = double.parse(
      ((coins / 1000) * basePrice).toStringAsFixed(2),
    );

    setState(() {
      _manualCalculatedCost = totalCost;
    });

    TopSnackBar.show(
      context,
      "تم حساب التكلفة اليدوية ✅",
      backgroundColor: Colors.green,
      textColor: Colors.white,
      icon: Icons.check_circle,
    );
  }

  Future<void> _editPrice(DocumentSnapshot doc, double currentPrice) async {
    final controller = TextEditingController(
      text: currentPrice.toStringAsFixed(2),
    );
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(ctx).colorScheme.surface,
          title: const Text("تعديل السعر النهائي"),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: "سعر كل 1000"),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text("إلغاء"),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final value = double.tryParse(controller.text.trim());
                      if (value == null || value <= 0) {
                        TopSnackBar.show(
                          context,
                          "أدخل سعر صحيح",
                          backgroundColor: Colors.red,
                          textColor: Colors.white,
                          icon: Icons.error,
                        );
                        return;
                      }
                      setDialogState(() => saving = true);
                      setState(() => _isEditing = true);
                      try {
                        await doc.reference.update({'pricePer1000': value});
                        if (!mounted) return;
                        TopSnackBar.show(
                          context,
                          "تم حفظ التعديل ✅",
                          backgroundColor: Colors.green,
                          textColor: Colors.white,
                          icon: Icons.check_circle,
                        );
                      } catch (_) {
                        if (!mounted) return;
                        TopSnackBar.show(
                          context,
                          "فشل حفظ التعديل",
                          backgroundColor: Colors.red,
                          textColor: Colors.white,
                          icon: Icons.error,
                        );
                      } finally {
                        if (mounted) setState(() => _isEditing = false);
                        if (ctx.mounted) Navigator.pop(ctx);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.primary,
                foregroundColor: Theme.of(ctx).colorScheme.onPrimary,
              ),
              child: saving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(ctx).colorScheme.onPrimary,
                      ),
                    )
                  : const Text("حفظ"),
            ),
          ],
        ),
      ),
    );
  }

  // EN: Builds widget UI.
  // AR: تبني واجهة الودجت.
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: const GlassAppBar(title: Text("تعديل الأسعار")),
      body: Stack(
        children: [
          const SnowBackground(),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('prices')
                .orderBy('min')
                .snapshots(),
            builder: (c, s) {
              if (!s.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (s.data!.docs.isEmpty) {
                return const Center(child: Text("لا توجد أسعار مسجلة"));
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  GlassCard(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "سعر التكلفة (لكل 1000 نقطة)",
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _costCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: "مثال: 100",
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Divider(),
                        const SizedBox(height: 10),
                        const Text(
                          "حاسبة التكلفة اليدوية (مستقلة)",
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _basePricePer1000Ctrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: "سعر 1000 بدون مكسب",
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _coinsCountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: "عدد العملات المراد حسابها",
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: _isSaving || _isEditing
                                ? null
                                : () => _calculateManualCost(context),
                            icon: const Icon(Icons.calculate),
                            label: const Text("احسب التكلفة"),
                          ),
                        ),
                        if (_manualCalculatedCost != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            "التكلفة: ${_manualCalculatedCost!.toStringAsFixed(2)} ج.م",
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Text(
                          "سيتم إضافة النِسب التالية بالترتيب:",
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _markups.map((e) => "$e%").join(" - "),
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _applyCost,
                            icon: _isSaving
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                    ),
                                  )
                                : const Icon(Icons.save),
                            label: Text(
                              _isSaving ? "جاري الحفظ..." : "تطبيق التكلفة",
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...s.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final int min = (data['min'] as num?)?.toInt() ?? 0;
                    final int max = (data['max'] as num?)?.toInt() ?? 0;
                    final double price =
                        (data['pricePer1000'] as num?)?.toDouble() ?? 0;

                    return GlassCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "المدى: $min - $max",
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "سعر كل 1000: $price ج.م",
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _isSaving || _isEditing
                                  ? null
                                  : () => _editPrice(doc, price),
                              icon: const Icon(Icons.edit),
                              label: const Text("تعديل السعر النهائي"),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
