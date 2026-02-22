// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/tt_colors.dart';
import '../../services/cloudflare_notify_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/glass_app_bar.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/snow_background.dart';
import '../../widgets/top_snackbar.dart';

class RamadanCodesScreen extends StatefulWidget {
  final String name;
  final String whatsapp;
  final String tiktok;

  // EN: Creates RamadanCodesScreen.
  // AR: ينشئ RamadanCodesScreen.
  const RamadanCodesScreen({
    super.key,
    required this.name,
    required this.whatsapp,
    required this.tiktok,
  });

  @override
  State<RamadanCodesScreen> createState() => _RamadanCodesScreenState();
}

class _RamadanCodesScreenState extends State<RamadanCodesScreen> {
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    NotificationService.listenToUserRamadanCodes(widget.whatsapp);
  }

  Future<void> _requestRamadanCode() async {
    if (widget.name.trim().isEmpty || widget.whatsapp.trim().isEmpty) {
      _showMsg("البيانات ناقصة", color: Colors.red);
      return;
    }

    setState(() => _requesting = true);

    try {
      final existing = await FirebaseFirestore.instance
          .collection('code_requests')
          .where('whatsapp', isEqualTo: widget.whatsapp)
          .where('status', isEqualTo: 'pending')
          .get();

      if (!mounted) return;

      if (existing.docs.isNotEmpty) {
        _showMsg("لديك طلب قيد الانتظار", color: Colors.orange);
        setState(() => _requesting = false);
        return;
      }

      final reqRef = await FirebaseFirestore.instance.collection('code_requests').add({
        'name': widget.name,
        'whatsapp': widget.whatsapp,
        'tiktok': widget.tiktok,
        'status': 'pending',
        'created_at': FieldValue.serverTimestamp(),
      });
      unawaited(
        CloudflareNotifyService.notifyAdminsCodeRequest(
          requestId: reqRef.id,
          name: widget.name,
          whatsapp: widget.whatsapp,
          tiktok: widget.tiktok,
        ),
      );

      if (!mounted) return;
      _showMsg("تم إرسال الطلب", color: Colors.green);
    } catch (e) {
      if (!mounted) return;
      _showMsg("خطأ في الطلب", color: Colors.red);
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  void _showMsg(String msg, {Color color = TTColors.primaryCyan}) {
    TopSnackBar.show(
      context,
      msg,
      backgroundColor: color,
      textColor: Colors.white,
      icon: Icons.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GlassAppBar(title: Text("أكواد خصم رمضان")),
      body: Stack(
        children: [
          const SnowBackground(),
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GlassCard(
                      margin: EdgeInsets.zero,
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          const Text(
                            "طلب كود الخصم",
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "اضغط على الزر لطلب كود الخصم الخاص بك.",
                            style: TextStyle(color: TTColors.textGray),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _requesting
                                  ? null
                                  : _requestRamadanCode,
                              icon: _requesting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : const Icon(Icons.card_giftcard),
                              label: const Text("طلب كود الخصم"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: TTColors.goldAccent,
                                foregroundColor: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('code_requests')
                          .where('whatsapp', isEqualTo: widget.whatsapp)
                          .orderBy('created_at', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return GlassCard(
                            margin: EdgeInsets.zero,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  "يجب تفعيل الفهرسة (Index) لتعمل هذه الصفحة",
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                SelectableText(
                                  snapshot.error.toString(),
                                  style: TextStyle(
                                    color: TTColors.textGray,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: TTColors.primaryCyan,
                            ),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(
                            child: Text("لم تطلب أي أكواد حتى الآن"),
                          );
                        }

                        return ListView(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: snapshot.data!.docs.map((d) {
                            final data = d.data() as Map<String, dynamic>;
                            final String? promoCode = data['promo_code'];
                            final bool isSent = promoCode?.isNotEmpty == true;

                            return GlassCard(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              borderColor: isSent
                                  ? Colors.green
                                  : Colors.orange,
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isSent
                                            ? Icons.check_circle
                                            : Icons.hourglass_bottom,
                                        color: isSent
                                            ? Colors.green
                                            : Colors.orange,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        isSent
                                            ? "تم إرسال الكود! 🎉"
                                            : "قيد المراجعة... ⏳",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: TTColors.textWhite,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Divider(
                                    color: Theme.of(context).dividerColor,
                                  ),
                                  if (promoCode != null &&
                                      promoCode.isNotEmpty) ...[
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
                                        Clipboard.setData(
                                          ClipboardData(text: promoCode),
                                        );
                                        TopSnackBar.show(
                                          context,
                                          "تم نسخ الكود!",
                                          backgroundColor: TTColors.cardBg,
                                          textColor: TTColors.textWhite,
                                          icon: Icons.copy,
                                        );
                                      },
                                    ),
                                  ] else
                                    Text(
                                      "سيظهر الكود هنا فور موافقة الإدارة.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: TTColors.textGray,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
