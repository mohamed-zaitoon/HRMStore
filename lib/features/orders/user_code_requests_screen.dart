// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/tt_colors.dart';
import '../../widgets/top_snackbar.dart';
import '../../widgets/glass_app_bar.dart';
import '../../widgets/glass_card.dart';

class UserCodeRequestsScreen extends StatelessWidget {
  final String whatsapp;

  // EN: Creates UserCodeRequestsScreen.
  // AR: ينشئ UserCodeRequestsScreen.
  const UserCodeRequestsScreen({super.key, required this.whatsapp});

  // EN: Builds widget UI.
  // AR: تبني واجهة الودجت.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GlassAppBar(title: Text("أكواد العروض الخاصة بي 🎁")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('code_requests')
            .where('whatsapp', isEqualTo: whatsapp)
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (c, s) {
          if (s.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 50,
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      "يجب تفعيل الفهرسة (Index) لتعمل هذه الصفحة",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 15),

                    SelectableText(
                      s.error.toString(),
                      style: TextStyle(color: TTColors.textGray, fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          }

          if (s.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!s.hasData || s.data!.docs.isEmpty) {
            return const Center(child: Text("لم تطلب أي أكواد حتى الآن"));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: s.data!.docs.map((d) {
              final data = d.data() as Map<String, dynamic>;
              final String? promoCode = data['promo_code'];
              final bool isSent = promoCode?.isNotEmpty == true;

              return GlassCard(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                borderColor: isSent ? Colors.green : Colors.orange,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          isSent ? Icons.check_circle : Icons.hourglass_bottom,
                          color: isSent ? Colors.green : Colors.orange,
                        ),

                        const SizedBox(width: 10),

                        Text(
                          isSent ? "تم إرسال الكود! 🎉" : "قيد المراجعة... ⏳",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: TTColors.textWhite,
                          ),
                        ),
                      ],
                    ),

                    Divider(color: Theme.of(context).dividerColor),
                    if (promoCode != null && promoCode.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withAlpha(26),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Column(
                          children: [
                            Text(
                              "الكود الخاص بك هو:",
                              style: TextStyle(
                                color: TTColors.textGray,
                                fontSize: 12,
                              ),
                            ),

                            SelectableText(
                              promoCode,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: TTColors.goldAccent,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.copy),
                        label: const Text("نسخ الكود"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TTColors.goldAccent,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: promoCode));
                          TopSnackBar.show(
                            context,
                            "تم نسخ الكود!",
                            backgroundColor: TTColors.cardBg,
                            textColor: TTColors.textWhite,
                            icon: Icons.copy,
                          );
                        },
                      ),
                    ] else ...[
                      Text(
                        "سيظهر الكود هنا فور موافقة الإدارة.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: TTColors.textGray),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
