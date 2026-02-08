// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../../core/tt_colors.dart';
import '../../widgets/top_snackbar.dart';
import '../../widgets/glass_app_bar.dart';
import '../../widgets/glass_card.dart';

class AdminPromoCodesScreen extends StatelessWidget {
  // EN: Creates AdminPromoCodesScreen.
  // AR: ينشئ AdminPromoCodesScreen.
  const AdminPromoCodesScreen({super.key});

  // EN: Builds widget UI.
  // AR: تبني واجهة الودجت.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlassAppBar(
        title: const Text("إدارة أكواد الخصم 🎫"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddCodeDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('promo_codes')
            .snapshots(),
        builder: (c, s) {
          if (!s.hasData)
            return const Center(child: CircularProgressIndicator());
          if (s.data!.docs.isEmpty)
            return const Center(child: Text("لا توجد أكواد مسجلة"));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: s.data!.docs.length,
            itemBuilder: (ctx, i) {
              final doc = s.data!.docs[i];
              final data = doc.data() as Map<String, dynamic>;
              final code = doc.id;
              final isUsed = data['is_used'] == true;
              final brightness = Theme.of(context).brightness;
              final statusColor = isUsed
                  ? (brightness == Brightness.dark
                        ? Colors.redAccent
                        : Colors.red.shade700)
                  : (brightness == Brightness.dark
                        ? Colors.greenAccent
                        : Colors.green.shade700);

              return GlassCard(
                margin: const EdgeInsets.only(bottom: 10),
                padding: EdgeInsets.zero,
                borderColor: statusColor,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: statusColor.withAlpha(38),
                    child: Icon(
                      isUsed ? Icons.block : Icons.check_circle,
                      color: statusColor,
                    ),
                  ),
                  title: SelectableText(
                    code,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                      fontSize: 18,
                      color: TTColors.textWhite,
                    ),
                  ),
                  subtitle: Text(
                    isUsed ? "مستخدم (غير فعال)" : "متاح للتفعيل",
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.copy, color: TTColors.textGray),
                        tooltip: "نسخ الكود",
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: code));
                          TopSnackBar.show(
                            context,
                            "تم نسخ الكود",
                            backgroundColor: TTColors.cardBg,
                            textColor: TTColors.textWhite,
                            icon: Icons.copy,
                          );
                        },
                      ),

                      Switch(
                        value: !isUsed,
                        activeThumbColor: Colors.green,
                        inactiveTrackColor: Colors.red,
                        onChanged: (val) {
                          doc.reference.update({'is_used': !val});
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // EN: Shows Add Code Dialog.
  // AR: تعرض Add Code Dialog.
  void _showAddCodeDialog(BuildContext context) {
    final codeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TTColors.cardBg,
        title: const Text(
          "إضافة كود جديد",
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        content: TextField(
          controller: codeCtrl,
          decoration: const InputDecoration(
            labelText: "اكتب الكود (مثلاً RAMADAN_01)",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء"),
          ),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: TTColors.goldAccent,
            ),
            onPressed: () {
              if (codeCtrl.text.isNotEmpty) {
                FirebaseFirestore.instance
                    .collection('promo_codes')
                    .doc(codeCtrl.text.trim().toUpperCase())
                    .set({
                      'is_used': false,
                      'created_at': FieldValue.serverTimestamp(),
                    });
                Navigator.pop(ctx);
              }
            },
            child: const Text("حفظ", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }
}
