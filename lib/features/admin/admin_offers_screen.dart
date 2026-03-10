// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../utils/offer_discount_tiers.dart';
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
  final TextEditingController _offersTitleCtrl = TextEditingController();
  final TextEditingController _offersRequestCtaCtrl = TextEditingController();

  bool _isSavingOffers = false;
  bool _isLoadingOffers = true;
  bool _offersEnabled = true;
  List<_OfferTierInput> _offerTierInputs = <_OfferTierInput>[];

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  @override
  void dispose() {
    _disposeTierInputs();
    _offersTitleCtrl.dispose();
    _offersRequestCtaCtrl.dispose();
    super.dispose();
  }

  void _disposeTierInputs() {
    for (final tier in _offerTierInputs) {
      tier.offerPriceCtrl.dispose();
    }
  }

  String _formatNumber(double value) {
    final fixed = value.toStringAsFixed(6);
    return fixed
        .replaceFirst(RegExp(r'\.?0+$'), '')
        .replaceAll(RegExp(r'(\.\d*?)0+$'), r'$1');
  }

  String _formatDisplayedPrice(double value) {
    final rounded = double.parse(value.toStringAsFixed(1));
    return _formatNumber(rounded);
  }

  double? _parseOfferPrice(String raw) {
    final value = parseOfferNumber(raw);
    if (value == null || value <= 0) return null;
    return value;
  }

  Future<void> _loadOffers() async {
    if (mounted) {
      setState(() => _isLoadingOffers = true);
    }

    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('offers').doc('current').get(),
        FirebaseFirestore.instance.collection('prices').orderBy('min').get(),
      ]);
      if (!mounted) return;

      final offersData =
          (results[0] as DocumentSnapshot<Map<String, dynamic>>).data() ??
          const <String, dynamic>{};
      final priceDocs =
          (results[1] as QuerySnapshot<Map<String, dynamic>>).docs;
      final savedOfferTiers = OfferPriceTier.parseList(
        offersData['offer_tiers'],
      );
      final savedDiscountTiers = OfferDiscountTier.parseList(
        offersData['discount_tiers'],
      );

      final nextInputs = <_OfferTierInput>[];
      for (final doc in priceDocs) {
        final data = doc.data();
        final min = (data['min'] as num?)?.toInt() ?? 0;
        final max = (data['max'] as num?)?.toInt() ?? 0;
        final pricePer1000 = parseOfferNumber(data['pricePer1000']) ?? 0;
        final matchedOfferTier = savedOfferTiers.where((tier) {
          return tier.min == min && tier.max == max;
        }).firstOrNull;
        final matchedDiscountTier = savedDiscountTiers.where((tier) {
          return tier.min == min && tier.max == max;
        }).firstOrNull;

        final legacyOfferRate = legacyOfferRateForPoints(
          data: offersData,
          points: min.toDouble(),
        );
        final migratedOfferPrice =
            matchedOfferTier?.pricePer1000 ??
            (matchedDiscountTier != null && pricePer1000 > 0
                ? applyDiscountPercent(
                    baseRate: pricePer1000,
                    discountPercent: matchedDiscountTier.discountPercent,
                  )
                : null) ??
            (legacyOfferRate > 0 ? legacyOfferRate : null) ??
            pricePer1000;

        nextInputs.add(
          _OfferTierInput(
            min: min,
            max: max,
            basePricePer1000: pricePer1000,
            offerPriceCtrl: TextEditingController(
              text: migratedOfferPrice <= 0
                  ? ''
                  : _formatDisplayedPrice(migratedOfferPrice),
            ),
          ),
        );
      }

      _disposeTierInputs();
      _offerTierInputs = nextInputs;
      _offersTitleCtrl.text =
          (offersData['title'] as String? ?? '✨ عروض الخصم ✨').trim();
      _offersRequestCtaCtrl.text =
          (offersData['request_cta'] as String? ??
                  'اضغط لطلب كود الخصم الخاص بك')
              .trim();
      _offersEnabled = offersData['enabled'] as bool? ?? true;
    } catch (_) {
      if (!mounted) return;
      _disposeTierInputs();
      _offerTierInputs = <_OfferTierInput>[];
      _offersTitleCtrl.text = '✨ عروض الخصم ✨';
      _offersRequestCtaCtrl.text = 'اضغط لطلب كود الخصم الخاص بك';
      _offersEnabled = true;
      TopSnackBar.show(
        context,
        'تعذر تحميل إعدادات العروض أو الشرائح الأساسية',
        backgroundColor: Colors.red,
        textColor: Colors.white,
        icon: Icons.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingOffers = false);
      }
    }
  }

  Future<void> _saveOffers() async {
    if (_offerTierInputs.isEmpty) {
      TopSnackBar.show(
        context,
        'لا توجد شرائح أساسية لحفظ أسعار العروض',
        backgroundColor: Colors.red,
        textColor: Colors.white,
        icon: Icons.error,
      );
      return;
    }

    final tiersPayload = <Map<String, dynamic>>[];
    for (final tier in _offerTierInputs) {
      final offerPrice = _parseOfferPrice(tier.offerPriceCtrl.text);
      if (offerPrice == null) {
        TopSnackBar.show(
          context,
          'أدخل سعر 1000 صالحًا لكل شريحة في العروض',
          backgroundColor: Colors.red,
          textColor: Colors.white,
          icon: Icons.error,
        );
        return;
      }
      tiersPayload.add(
        OfferPriceTier(
          min: tier.min,
          max: tier.max,
          pricePer1000: offerPrice,
        ).toMap(),
      );
    }

    setState(() => _isSavingOffers = true);
    try {
      await FirebaseFirestore.instance.collection('offers').doc('current').set({
        'enabled': _offersEnabled,
        'offer_mode': 'manual_price',
        'offer_tiers': tiersPayload,
        'title': _offersTitleCtrl.text.trim(),
        'request_cta': _offersRequestCtaCtrl.text.trim(),
        'discount_mode': FieldValue.delete(),
        'discount_tiers': FieldValue.delete(),
        'rate_100': FieldValue.delete(),
        'rate_500': FieldValue.delete(),
        'rate_1000': FieldValue.delete(),
        'rate_50000': FieldValue.delete(),
        'rate_75000': FieldValue.delete(),
        'offer5': FieldValue.delete(),
        'offer50': FieldValue.delete(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      TopSnackBar.show(
        context,
        'تم حفظ أسعار العروض اليدوية حسب الشرائح الأساسية ✅',
        backgroundColor: Colors.green,
        textColor: Colors.white,
        icon: Icons.check_circle,
      );
    } catch (_) {
      if (!mounted) return;
      TopSnackBar.show(
        context,
        'فشل حفظ إعدادات العروض',
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
    final colorScheme = Theme.of(context).colorScheme;
    final disabled = _isLoadingOffers || _isSavingOffers;

    return Scaffold(
      appBar: GlassAppBar(
        title: const Text('عروض الأسعار'),
        actions: [
          IconButton(
            onPressed: disabled ? null : _loadOffers,
            icon: _isLoadingOffers
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'إعادة تحميل الشرائح',
          ),
        ],
      ),
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
                      'إعدادات العروض (Firestore / offers)',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'الشرائح هنا يتم سحبها تلقائيًا من الشرائح الأساسية في الأسعار. لكل شريحة اكتب سعر العرض يدويًا بدون نسب.',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _offersEnabled,
                      onChanged: disabled
                          ? null
                          : (value) => setState(() => _offersEnabled = value),
                      title: const Text('تفعيل أكواد الخصم'),
                    ),
                    TextField(
                      controller: _offersTitleCtrl,
                      enabled: !disabled,
                      decoration: const InputDecoration(
                        labelText: 'عنوان صندوق العروض',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _offersRequestCtaCtrl,
                      enabled: !disabled,
                      decoration: const InputDecoration(
                        labelText: 'نص زر طلب الكود',
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_offerTierInputs.isEmpty)
                      Text(
                        _isLoadingOffers
                            ? 'جاري تحميل الشرائح...'
                            : 'لا توجد شرائح أساسية حالياً. أضف الشرائح من شاشة الأسعار أولاً.',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontFamily: 'Cairo',
                        ),
                      )
                    else
                      ..._offerTierInputs.map(
                        (tier) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildTierCard(
                            context,
                            tier: tier,
                            disabled: disabled,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: disabled ? null : _saveOffers,
                        icon: _isSavingOffers
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.onPrimary,
                                ),
                              )
                            : const Icon(Icons.local_offer),
                        label: Text(
                          _isSavingOffers
                              ? 'جاري حفظ العروض...'
                              : 'حفظ إعدادات العروض',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
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

  Widget _buildTierCard(
    BuildContext context, {
    required _OfferTierInput tier,
    required bool disabled,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final previewOfferPrice = _parseOfferPrice(tier.offerPriceCtrl.text);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface.withAlpha(72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الشريحة: ${tier.min} - ${tier.max}',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'سعر 1000 الأساسي: ${_formatDisplayedPrice(tier.basePricePer1000)} ج.م',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontFamily: 'Cairo',
            ),
          ),
          if (previewOfferPrice != null) ...[
            const SizedBox(height: 2),
            Text(
              'سعر 1000 في العرض: ${_formatDisplayedPrice(previewOfferPrice)} ج.م',
              style: TextStyle(
                color: colorScheme.primary,
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: tier.offerPriceCtrl,
            enabled: !disabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'سعر 1000 في العرض',
              hintText: 'مثال: 148.5',
            ),
            onChanged: (_) {
              if (!mounted) return;
              setState(() {});
            },
          ),
        ],
      ),
    );
  }
}

class _OfferTierInput {
  const _OfferTierInput({
    required this.min,
    required this.max,
    required this.basePricePer1000,
    required this.offerPriceCtrl,
  });

  final int min;
  final int max;
  final double basePricePer1000;
  final TextEditingController offerPriceCtrl;
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    if (isEmpty) return null;
    return first;
  }
}
