// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/tt_colors.dart';
import '../../widgets/top_snackbar.dart';
import '../../widgets/glass_app_bar.dart';
import '../../widgets/glass_card.dart';

class AdminCodeRequestsScreen extends StatelessWidget {
  // EN: Creates AdminCodeRequestsScreen.
  // AR: ينشئ AdminCodeRequestsScreen.
  const AdminCodeRequestsScreen({super.key});

  // EN: Builds widget UI.
  // AR: تبني واجهة الودجت.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GlassAppBar(title: Text("طلبات أكواد المستخدمين 🙋‍♂️")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('code_requests')
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (c, s) {
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (s.data!.docs.isEmpty) {
            return const Center(child: Text("لا توجد طلبات"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: s.data!.docs.length,
            itemBuilder: (ctx, i) {
              final doc = s.data!.docs[i];
              final data = doc.data() as Map<String, dynamic>;

              final String? currentCode = data['promo_code'];
              final bool isSent = currentCode != null && currentCode.isNotEmpty;

              return GlassCard(
                margin: const EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.zero,
                borderColor: isSent ? Colors.green : Colors.orange,
                child: ExpansionTile(
                  collapsedTextColor: TTColors.textWhite,
                  textColor: TTColors.textWhite,
                  leading: CircleAvatar(
                    backgroundColor: isSent ? Colors.grey : Colors.orange,
                    child: Icon(
                      isSent ? Icons.check : Icons.card_giftcard,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    data['name'] ?? "بدون اسم",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: TTColors.textWhite,
                    ),
                  ),
                  subtitle: Text(
                    data['whatsapp'] ?? "لا يوجد رقم",
                    style: TextStyle(color: TTColors.textGray),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          if (isSent)
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.withAlpha(26),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "تم الإرسال مسبقاً: $currentCode",
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.send),
                            label: Text(
                              isSent ? "تعديل الكود" : "إرسال الكود للمستخدم",
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: TTColors.goldAccent,
                              foregroundColor: Colors.black,
                              minimumSize: const Size(double.infinity, 45),
                            ),
                            onPressed: () => _showSendCodeDialog(
                              context,
                              doc.id,
                              currentCode ?? "",
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // EN: Shows Send Code Dialog.
  // AR: تعرض Send Code Dialog.
  void _showSendCodeDialog(BuildContext context, String docId, String oldCode) {
    final codeCtrl = TextEditingController(text: oldCode);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: TTColors.cardBg,
        title: const Text("تخصيص كود خصم"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("ضع كود الخصم الذي سيستلمه المستخدم"),

            const SizedBox(height: 15),

            TextField(
              controller: codeCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: "كود الخصم (مثال: RAMADAN20)",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("إلغاء", style: TextStyle(color: TTColors.textGray)),
          ),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: TTColors.goldAccent,
            ),
            onPressed: () async {
              final String newCode = codeCtrl.text.trim().toUpperCase();

              if (newCode.isEmpty) return;

              await FirebaseFirestore.instance
                  .collection('code_requests')
                  .doc(docId)
                  .update({
                    'promo_code': newCode,
                    'status': 'sent',
                    'sent_at': FieldValue.serverTimestamp(),
                  });

              if (!context.mounted) return;
              if (ctx.mounted) Navigator.pop(ctx);

              TopSnackBar.show(
                context,
                "تم حفظ الكود وسيتم إرسال إشعار تلقائيًا ✅",
                backgroundColor: TTColors.cardBg,
                textColor: TTColors.textWhite,
                icon: Icons.check_circle,
              );
            },
            child: const Text("حفظ"),
          ),
        ],
      ),
    );
  }
}
