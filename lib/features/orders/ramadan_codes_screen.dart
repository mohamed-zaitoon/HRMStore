// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/tt_colors.dart';
import '../../services/cloudflare_notify_service.dart';
import '../../services/notification_service.dart';
import '../../services/remote_config_service.dart';
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
  bool _seasonLoaded = false;
  bool _isRamadanSeason = false;
  bool _isEidSeason = false;

  bool get _isSeasonalPromoEnabled =>
      (_isRamadanSeason && !_isEidSeason) ||
      (_isEidSeason && !_isRamadanSeason);

  String get _seasonalPromoTitle => _isSeasonalPromoEnabled
      ? 'أكواد خصم ${_isEidSeason ? 'العيد' : 'رمضان'}'
      : 'أكواد الخصم';

  @override
  void initState() {
    super.initState();
    NotificationService.listenToUserRamadanCodes(widget.whatsapp);
    unawaited(_loadSeasonFlags());
  }

  Future<void> _loadSeasonFlags() async {
    try {
      await RemoteConfigService.instance.init();
    } catch (_) {}

    if (!mounted) return;

    final isRamadanRaw = RemoteConfigService.instance.isRamadan;
    final isEidRaw = RemoteConfigService.instance.isEid;
    setState(() {
      _isRamadanSeason = isRamadanRaw && !isEidRaw;
      _isEidSeason = isEidRaw && !isRamadanRaw;
      _seasonLoaded = true;
    });
  }

  Future<void> _requestDiscountCode() async {
    if (!_isSeasonalPromoEnabled) {
      _showMsg("أكواد الخصم غير متاحة حالياً", color: Colors.orange);
      return;
    }
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

      final reqRef = await FirebaseFirestore.instance
          .collection('code_requests')
          .add({
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

  Widget _buildPromoCodeSection(String promoCode) {
    final normalizedCode = promoCode.trim().toUpperCase();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('promo_codes')
          .doc(normalizedCode)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final isUsed = data['is_used'] == true;
        final codeColor = isUsed
            ? const Color(0xFFFCA5A5)
            : TTColors.goldAccent;
        final borderColor = isUsed ? Colors.red : Colors.green;
        final boxColor = isUsed
            ? Colors.red.withAlpha(18)
            : Colors.green.withAlpha(26);

        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: boxColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  Text(
                    "الكود الخاص بك هو:",
                    style: TextStyle(color: TTColors.textGray, fontSize: 12),
                  ),
                  SelectableText(
                    normalizedCode,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: codeColor,
                      letterSpacing: 2,
                      decoration: isUsed ? TextDecoration.lineThrough : null,
                      decorationColor: codeColor,
                      decorationThickness: isUsed ? 2 : null,
                    ),
                  ),
                  if (isUsed)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        "تم استخدامه",
                        style: TextStyle(
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: Icon(isUsed ? Icons.check_circle : Icons.copy),
              label: Text(isUsed ? "تم استخدامه" : "نسخ الكود"),
              style: ElevatedButton.styleFrom(
                backgroundColor: isUsed
                    ? Theme.of(context).disabledColor
                    : TTColors.goldAccent,
                foregroundColor: isUsed ? TTColors.textWhite : Colors.black,
              ),
              onPressed: isUsed
                  ? null
                  : () {
                      Clipboard.setData(ClipboardData(text: normalizedCode));
                      TopSnackBar.show(
                        context,
                        "تم نسخ الكود!",
                        backgroundColor: TTColors.cardBg,
                        textColor: TTColors.textWhite,
                        icon: Icons.copy,
                      );
                    },
            ),
          ],
        );
      },
    );
  }

  Future<void> _handlePageSwipeRefresh() async {
    await _loadSeasonFlags();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlassAppBar(title: Text(_seasonalPromoTitle)),
      body: Stack(
        children: [
          const SnowBackground(),
          if (!_seasonLoaded)
            (!kIsWeb
                ? CustomMaterialIndicator(
                    onRefresh: _handlePageSwipeRefresh,
                    color: TTColors.primaryCyan,
                    backgroundColor: TTColors.cardBg,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(
                          height: 420,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: TTColors.primaryCyan,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const Center(
                    child: CircularProgressIndicator(
                      color: TTColors.primaryCyan,
                    ),
                  ))
          else if (!_isSeasonalPromoEnabled)
            (!kIsWeb
                ? CustomMaterialIndicator(
                    onRefresh: _handlePageSwipeRefresh,
                    color: TTColors.primaryCyan,
                    backgroundColor: TTColors.cardBg,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: 420,
                          child: Center(
                            child: Text(
                              "أكواد الخصم غير متاحة حالياً",
                              style: TextStyle(
                                color: TTColors.textGray,
                                fontFamily: 'Cairo',
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Center(
                    child: Text(
                      "أكواد الخصم غير متاحة حالياً",
                      style: TextStyle(
                        color: TTColors.textGray,
                        fontFamily: 'Cairo',
                        fontSize: 16,
                      ),
                    ),
                  ))
          else
            (!kIsWeb
                ? CustomMaterialIndicator(
                    onRefresh: _handlePageSwipeRefresh,
                    color: TTColors.primaryCyan,
                    backgroundColor: TTColors.cardBg,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
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
                                      style: TextStyle(
                                        color: TTColors.textGray,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: _requesting
                                            ? null
                                            : _requestDiscountCode,
                                        icon: _requesting
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
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
                                    .where(
                                      'whatsapp',
                                      isEqualTo: widget.whatsapp,
                                    )
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

                                  if (!snapshot.hasData ||
                                      snapshot.data!.docs.isEmpty) {
                                    return const Center(
                                      child: Text("لم تطلب أي أكواد حتى الآن"),
                                    );
                                  }

                                  return ListView(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    children: snapshot.data!.docs.map((d) {
                                      final data =
                                          d.data() as Map<String, dynamic>;
                                      final String? promoCode =
                                          data['promo_code'];
                                      final bool isSent =
                                          promoCode?.isNotEmpty == true;

                                      return GlassCard(
                                        margin: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
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
                                              color: Theme.of(
                                                context,
                                              ).dividerColor,
                                            ),
                                            if (promoCode != null &&
                                                promoCode.isNotEmpty) ...[
                                              _buildPromoCodeSection(promoCode),
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
                  )
                : SingleChildScrollView(
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
                                          : _requestDiscountCode,
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

                                if (!snapshot.hasData ||
                                    snapshot.data!.docs.isEmpty) {
                                  return const Center(
                                    child: Text("لم تطلب أي أكواد حتى الآن"),
                                  );
                                }

                                return ListView(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  children: snapshot.data!.docs.map((d) {
                                    final data =
                                        d.data() as Map<String, dynamic>;
                                    final String? promoCode =
                                        data['promo_code'];
                                    final bool isSent =
                                        promoCode?.isNotEmpty == true;

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
                                            color: Theme.of(
                                              context,
                                            ).dividerColor,
                                          ),
                                          if (promoCode != null &&
                                              promoCode.isNotEmpty) ...[
                                            _buildPromoCodeSection(promoCode),
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
                  )),
        ],
      ),
    );
  }
}
