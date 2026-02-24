// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../widgets/glass_app_bar.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/snow_background.dart';
import '../../widgets/top_snackbar.dart';

class AdminOffersScreen extends StatefulWidget {
  const AdminOffersScreen({super.key});

  @override
  State<AdminOffersScreen> createState() => _AdminOffersScreenState();
}

class _AdminOffersScreenState extends State<AdminOffersScreen> {
  final TextEditingController _offerRateFor100Ctrl = TextEditingController();
  final TextEditingController _offerRateFor500Ctrl = TextEditingController();
  final TextEditingController _offerRateFor1000Ctrl = TextEditingController();
  final TextEditingController _offerRateFor50000Ctrl = TextEditingController();
  final TextEditingController _offerRateFor75000Ctrl = TextEditingController();
  final TextEditingController _offersTitleCtrl = TextEditingController();
  final TextEditingController _offersRequestCtaCtrl = TextEditingController();

  bool _isSavingOffers = false;
  bool _isLoadingOffers = true;
  bool _offersEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  @override
  void dispose() {
    _offerRateFor100Ctrl.dispose();
    _offerRateFor500Ctrl.dispose();
    _offerRateFor1000Ctrl.dispose();
    _offerRateFor50000Ctrl.dispose();
    _offerRateFor75000Ctrl.dispose();
    _offersTitleCtrl.dispose();
    _offersRequestCtaCtrl.dispose();
    super.dispose();
  }

  double? _parseNonNegative(String raw) {
    final value = double.tryParse(raw.trim().replaceAll(',', '.'));
    if (value == null || value < 0) return null;
    return value;
  }

  double _readDoubleField(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim()) ?? 0;
    return 0;
  }

  Future<void> _loadOffers() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('offers')
          .doc('current')
          .get();
      if (!mounted) return;
      final data = doc.data() ?? const <String, dynamic>{};
      final rate100 = _readDoubleField(data, 'rate_100') > 0
          ? _readDoubleField(data, 'rate_100')
          : _readDoubleField(data, 'offer5');
      final rate500 = _readDoubleField(data, 'rate_500') > 0
          ? _readDoubleField(data, 'rate_500')
          : rate100;
      final rate1000 = _readDoubleField(data, 'rate_1000') > 0
          ? _readDoubleField(data, 'rate_1000')
          : rate500;
      final rate50000 = _readDoubleField(data, 'rate_50000') > 0
          ? _readDoubleField(data, 'rate_50000')
          : _readDoubleField(data, 'offer50');
      final rate75000 = _readDoubleField(data, 'rate_75000') > 0
          ? _readDoubleField(data, 'rate_75000')
          : rate50000;
      _offerRateFor100Ctrl.text = rate100.toStringAsFixed(2);
      _offerRateFor500Ctrl.text = rate500.toStringAsFixed(2);
      _offerRateFor1000Ctrl.text = rate1000.toStringAsFixed(2);
      _offerRateFor50000Ctrl.text = rate50000.toStringAsFixed(2);
      _offerRateFor75000Ctrl.text = rate75000.toStringAsFixed(2);
      _offersTitleCtrl.text = (data['title'] as String? ?? '✨ عروض الخصم ✨')
          .trim();
      _offersRequestCtaCtrl.text =
          (data['request_cta'] as String? ?? 'اضغط لطلب كود الخصم الخاص بك')
              .trim();
      _offersEnabled = data['enabled'] as bool? ?? true;
    } catch (_) {
      if (!mounted) return;
      _offerRateFor100Ctrl.text = '0';
      _offerRateFor500Ctrl.text = '0';
      _offerRateFor1000Ctrl.text = '0';
      _offerRateFor50000Ctrl.text = '0';
      _offerRateFor75000Ctrl.text = '0';
      _offersTitleCtrl.text = '✨ عروض الخصم ✨';
      _offersRequestCtaCtrl.text = 'اضغط لطلب كود الخصم الخاص بك';
      _offersEnabled = true;
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingOffers = false;
        });
      }
    }
  }

  Future<void> _saveOffers() async {
    final rate100 = _parseNonNegative(_offerRateFor100Ctrl.text);
    final rate500 = _parseNonNegative(_offerRateFor500Ctrl.text);
    final rate1000 = _parseNonNegative(_offerRateFor1000Ctrl.text);
    final rate50000 = _parseNonNegative(_offerRateFor50000Ctrl.text);
    final rate75000 = _parseNonNegative(_offerRateFor75000Ctrl.text);
    if (rate100 == null ||
        rate500 == null ||
        rate1000 == null ||
        rate50000 == null ||
        rate75000 == null) {
      TopSnackBar.show(
        context,
        "أدخل أسعار عروض صحيحة (0 أو أكبر)",
        backgroundColor: Colors.red,
        textColor: Colors.white,
        icon: Icons.error,
      );
      return;
    }

    setState(() => _isSavingOffers = true);
    try {
      await FirebaseFirestore.instance.collection('offers').doc('current').set({
        'enabled': _offersEnabled,
        'rate_100': double.parse(rate100.toStringAsFixed(2)),
        'rate_500': double.parse(rate500.toStringAsFixed(2)),
        'rate_1000': double.parse(rate1000.toStringAsFixed(2)),
        'rate_50000': double.parse(rate50000.toStringAsFixed(2)),
        'rate_75000': double.parse(rate75000.toStringAsFixed(2)),
        'title': _offersTitleCtrl.text.trim(),
        'request_cta': _offersRequestCtaCtrl.text.trim(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      TopSnackBar.show(
        context,
        "تم حفظ إعدادات العروض ✅",
        backgroundColor: Colors.green,
        textColor: Colors.white,
        icon: Icons.check_circle,
      );
    } catch (_) {
      if (!mounted) return;
      TopSnackBar.show(
        context,
        "فشل حفظ إعدادات العروض",
        backgroundColor: Colors.red,
        textColor: Colors.white,
        icon: Icons.error,
      );
    } finally {
      if (mounted) setState(() => _isSavingOffers = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GlassAppBar(title: Text("عروض الأسعار")),
      body: Stack(
        children: [
          const SnowBackground(),
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GlassCard(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "إعدادات العروض (Firestore / offers)",
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _offersEnabled,
                      onChanged: _isLoadingOffers || _isSavingOffers
                          ? null
                          : (value) => setState(() => _offersEnabled = value),
                      title: const Text("تفعيل أكواد الخصم"),
                    ),
                    TextField(
                      controller: _offersTitleCtrl,
                      enabled: !_isLoadingOffers && !_isSavingOffers,
                      decoration: const InputDecoration(
                        labelText: "عنوان صندوق العروض",
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _offersRequestCtaCtrl,
                      enabled: !_isLoadingOffers && !_isSavingOffers,
                      decoration: const InputDecoration(
                        labelText: "نص زر طلب الكود",
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _offerRateFor100Ctrl,
                      enabled: !_isLoadingOffers && !_isSavingOffers,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: "سعر كل 1000 من 100 إلى 499",
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _offerRateFor500Ctrl,
                      enabled: !_isLoadingOffers && !_isSavingOffers,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: "سعر كل 1000 من 500 إلى 999",
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _offerRateFor1000Ctrl,
                      enabled: !_isLoadingOffers && !_isSavingOffers,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: "سعر كل 1000 من 1000 إلى 49999",
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _offerRateFor50000Ctrl,
                      enabled: !_isLoadingOffers && !_isSavingOffers,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: "سعر كل 1000 من 50000 إلى 74999",
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _offerRateFor75000Ctrl,
                      enabled: !_isLoadingOffers && !_isSavingOffers,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: "سعر كل 1000 من 75000 فأكثر",
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoadingOffers || _isSavingOffers
                            ? null
                            : _saveOffers,
                        icon: _isSavingOffers
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
                            : const Icon(Icons.local_offer),
                        label: Text(
                          _isSavingOffers
                              ? "جاري حفظ العروض..."
                              : "حفظ إعدادات العروض",
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
            ],
          ),
        ],
      ),
    );
  }
}
