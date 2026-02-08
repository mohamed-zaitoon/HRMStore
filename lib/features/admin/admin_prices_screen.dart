// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/tt_colors.dart';
import '../../widgets/top_snackbar.dart';
import '../../widgets/glass_app_bar.dart';
import '../../widgets/glass_card.dart';

class AdminPricesScreen extends StatefulWidget {
  // EN: Creates AdminPricesScreen.
  // AR: ينشئ AdminPricesScreen.
  const AdminPricesScreen({super.key});

  // EN: Creates state object.
  // AR: تنشئ كائن الحالة.
  @override
  State<AdminPricesScreen> createState() => _AdminPricesScreenState();
}

class _AdminPricesScreenState extends State<AdminPricesScreen> {
  final TextEditingController _costCtrl = TextEditingController();
  bool _isSaving = false;
  bool _isEditing = false;

  final List<double> _markups = const [8.8, 4, 3.2, 2.4, 1.6, 0.8];

  // EN: Releases resources.
  // AR: تفرّغ الموارد.
  @override
  void dispose() {
    _costCtrl.dispose();
    super.dispose();
  }

  // EN: Applies cost to all tiers.
  // AR: تطبق التكلفة على كل الشرائح.
  Future<void> _applyCost(BuildContext context) async {
    final cost = double.tryParse(_costCtrl.text.trim());
    if (cost == null || cost <= 0) {
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
      final snap = await FirebaseFirestore.instance
          .collection('prices')
          .orderBy('min')
          .get();

      if (snap.docs.length != _markups.length) {
        TopSnackBar.show(
          context,
          "عدد الشرائح (${snap.docs.length}) لا يطابق عدد النِسب (${_markups.length})",
          backgroundColor: Colors.red,
          textColor: Colors.white,
          icon: Icons.error,
        );
        setState(() => _isSaving = false);
        return;
      }

      final batch = FirebaseFirestore.instance.batch();
      for (var i = 0; i < snap.docs.length; i++) {
        final markup = _markups[i];
        final newPrice =
            double.parse((cost * (1 + (markup / 100))).toStringAsFixed(2));
        batch.update(snap.docs[i].reference, {'pricePer1000': newPrice});
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

  Future<void> _editPrice(
    BuildContext context,
    DocumentSnapshot doc,
    double currentPrice,
  ) async {
    final controller = TextEditingController(
      text: currentPrice.toStringAsFixed(2),
    );
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: TTColors.cardBg,
          title: const Text("تعديل السعر النهائي"),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: "سعر كل 1000",
            ),
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
                      final value =
                          double.tryParse(controller.text.trim());
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
                        await doc.reference
                            .update({'pricePer1000': value});
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
                backgroundColor: TTColors.primaryCyan,
                foregroundColor: Colors.black,
              ),
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
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
    return Scaffold(
      appBar: const GlassAppBar(title: Text("تعديل الأسعار")),
      body: StreamBuilder<QuerySnapshot>(
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
                    const SizedBox(height: 10),
                    Text(
                      "سيتم إضافة النِسب التالية بالترتيب:",
                      style: TextStyle(color: TTColors.textGray),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _markups.map((e) => "$e%").join(" - "),
                      style: TextStyle(
                        color: TTColors.primaryCyan,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : () => _applyCost(context),
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(
                          _isSaving ? "جاري الحفظ..." : "تطبيق التكلفة",
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TTColors.primaryCyan,
                          foregroundColor: Colors.black,
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
                          color: TTColors.textWhite,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "سعر كل 1000: $price ج.م",
                        style: TextStyle(color: TTColors.textGray),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _isSaving || _isEditing
                              ? null
                              : () => _editPrice(context, doc, price),
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
    );
  }
}
