// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/app_navigator.dart';
import '../../widgets/glass_app_bar.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/snow_background.dart';
import '../../widgets/top_snackbar.dart';

class AdminPricesScreen extends StatefulWidget {
  const AdminPricesScreen({super.key});

  @override
  State<AdminPricesScreen> createState() => _AdminPricesScreenState();
}

class _AdminPricesScreenState extends State<AdminPricesScreen> {
  static const double _defaultUsdCostPer1000 = 10.41;

  final TextEditingController _usdRateCtrl = TextEditingController();
  final TextEditingController _usdCostPer1000Ctrl = TextEditingController(
    text: _defaultUsdCostPer1000.toString(),
  );
  final TextEditingController _egpCostPer1000Ctrl = TextEditingController();

  bool _isEditing = false;
  bool _isLoadingPricing = false;

  @override
  void initState() {
    super.initState();
    _usdRateCtrl.addListener(_handlePricingInputsChanged);
    _usdCostPer1000Ctrl.addListener(_handlePricingInputsChanged);
    _loadPricingSettings();
  }

  @override
  void dispose() {
    _usdRateCtrl.removeListener(_handlePricingInputsChanged);
    _usdCostPer1000Ctrl.removeListener(_handlePricingInputsChanged);
    _usdRateCtrl.dispose();
    _usdCostPer1000Ctrl.dispose();
    _egpCostPer1000Ctrl.dispose();
    super.dispose();
  }

  void _handlePricingInputsChanged() {
    _syncEgpCostFromInputs();
    if (!mounted) return;
    setState(() {});
  }

  double? _parseNumber(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) {
      final normalized = raw.trim().replaceAll(',', '.');
      if (normalized.isEmpty) return null;
      return double.tryParse(normalized);
    }
    return null;
  }

  double? _parsePositive(dynamic raw) {
    final value = _parseNumber(raw);
    if (value == null || value <= 0) return null;
    return value;
  }

  double? _parseMargin(dynamic raw) {
    final value = _parseNumber(raw);
    if (value == null || value < 0) return null;
    return value;
  }

  String _formatNumber(double value) {
    final fixed = value.toStringAsFixed(3);
    return fixed
        .replaceFirst(RegExp(r'\.?0+$'), '')
        .replaceAll(RegExp(r'(\.\d*?)0+$'), r'$1');
  }

  double _roundToSingleDecimal(double value) {
    return double.parse(value.toStringAsFixed(1));
  }

  String _formatSingleDecimal(double value) {
    return _roundToSingleDecimal(value).toStringAsFixed(1);
  }

  String _rangeLabel(int min, int max) => '$min - $max';

  _PricingInputs? _pricingInputs() {
    final usdRate = _parsePositive(_usdRateCtrl.text);
    final usdCostPer1000 = _parsePositive(_usdCostPer1000Ctrl.text);
    if (usdRate == null || usdCostPer1000 == null) return null;
    final egpCostPer1000 = _roundToSingleDecimal(usdRate * usdCostPer1000);
    return _PricingInputs(
      usdRate: usdRate,
      usdCostPer1000: usdCostPer1000,
      egpCostPer1000: egpCostPer1000,
    );
  }

  _PricingInputs? _requirePricingInputs() {
    final pricing = _pricingInputs();
    if (pricing != null) return pricing;

    TopSnackBar.show(
      context,
      'أدخل سعر الدولار وسعر 1000 بالدولار أولاً',
      backgroundColor: Colors.red,
      textColor: Colors.white,
      icon: Icons.error,
    );
    return null;
  }

  void _syncEgpCostFromInputs() {
    final pricing = _pricingInputs();
    final nextText = pricing == null
        ? ''
        : _formatSingleDecimal(pricing.egpCostPer1000);
    if (_egpCostPer1000Ctrl.text != nextText) {
      _egpCostPer1000Ctrl.text = nextText;
    }
  }

  double _computePricePer1000({
    required double baseCostPer1000Egp,
    required double marginPercent,
  }) {
    return _roundToSingleDecimal(
      baseCostPer1000Egp * (1 + marginPercent / 100),
    );
  }

  double? _deriveMarginFromPrice({
    required double pricePer1000,
    required double baseCostPer1000Egp,
  }) {
    if (baseCostPer1000Egp <= 0) return null;
    return ((pricePer1000 - baseCostPer1000Egp) / baseCostPer1000Egp) * 100;
  }

  double? _storedMargin(Map<String, dynamic> data) {
    return _parseMargin(data['marginPercent'] ?? data['margin_percent']);
  }

  String? _validateRange({required int min, required int max}) {
    final allowEqualForTop = min == 100000 && max == 100000;
    if (min < 150) {
      return 'الحد الأدنى يجب أن يكون 150 أو أكثر';
    }
    if (max > 100000) {
      return 'الحد الأقصى يجب ألا يتجاوز 100000';
    }
    if (!allowEqualForTop && min >= max) {
      return 'الحد الأدنى يجب أن يكون أقل من الحد الأقصى';
    }
    return null;
  }

  void _persistPricingSettingsInBatch(
    WriteBatch batch,
    _PricingInputs pricing,
  ) {
    final pricingDoc = FirebaseFirestore.instance
        .collection('app_settings')
        .doc('pricing');
    final currencyDoc = FirebaseFirestore.instance
        .collection('app_settings')
        .doc('currency');

    batch.set(pricingDoc, {
      'usd_rate': pricing.usdRate,
      'usd_cost_per_1000': pricing.usdCostPer1000,
      'egp_cost_per_1000': pricing.egpCostPer1000,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.set(currencyDoc, {
      'usd_price': pricing.usdRate,
      'usd_egp': pricing.usdRate,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _loadPricingSettings({bool fromServer = true}) async {
    setState(() => _isLoadingPricing = true);
    try {
      final pricingSnap = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('pricing')
          .get(GetOptions(source: fromServer ? Source.server : Source.cache));
      final currencySnap = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('currency')
          .get(GetOptions(source: fromServer ? Source.server : Source.cache));

      final pricingData = pricingSnap.data() ?? const <String, dynamic>{};
      final currencyData = currencySnap.data() ?? const <String, dynamic>{};

      final usdRate =
          _parsePositive(pricingData['usd_rate']) ??
          _parsePositive(currencyData['usd_price'] ?? currencyData['usd_egp']);
      final usdCostPer1000 =
          _parsePositive(pricingData['usd_cost_per_1000']) ??
          _defaultUsdCostPer1000;

      _usdRateCtrl.text = usdRate == null ? '' : _formatNumber(usdRate);
      _usdCostPer1000Ctrl.text = _formatNumber(usdCostPer1000);
      _syncEgpCostFromInputs();
    } catch (_) {
      if (fromServer) {
        await _loadPricingSettings(fromServer: false);
        return;
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingPricing = false);
      }
    }
  }

  Future<void> _savePricingSettingsOnly() async {
    final pricing = _requirePricingInputs();
    if (pricing == null) return;

    setState(() => _isEditing = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      _persistPricingSettingsInBatch(batch, pricing);
      await batch.commit();

      if (!mounted) return;
      TopSnackBar.show(
        context,
        'تم حفظ الإعدادات. سعر 1000 بالجنيه = ${_formatSingleDecimal(pricing.egpCostPer1000)}',
        backgroundColor: Colors.green,
        textColor: Colors.white,
        icon: Icons.check_circle,
      );
    } catch (_) {
      if (!mounted) return;
      TopSnackBar.show(
        context,
        'تعذر حفظ الإعدادات',
        backgroundColor: Colors.red,
        textColor: Colors.white,
        icon: Icons.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isEditing = false);
      }
    }
  }

  Future<void> _applyPricingToAllRanges() async {
    final pricing = _requirePricingInputs();
    if (pricing == null) return;

    setState(() => _isEditing = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('prices')
          .orderBy('min')
          .get();

      final missingMargins = <String>[];
      for (final doc in snap.docs) {
        if (_storedMargin(doc.data()) != null) continue;
        final data = doc.data();
        final min = (data['min'] as num?)?.toInt() ?? 0;
        final max = (data['max'] as num?)?.toInt() ?? 0;
        missingMargins.add(_rangeLabel(min, max));
      }

      if (missingMargins.isNotEmpty) {
        final preview = missingMargins.take(3).join('، ');
        final suffix = missingMargins.length > 3 ? ' ...' : '';
        throw FormatException(
          'أدخل النسبة يدويًا لكل شريحة أولاً. الشرائح الناقصة: $preview$suffix',
        );
      }

      final batch = FirebaseFirestore.instance.batch();
      _persistPricingSettingsInBatch(batch, pricing);

      for (final doc in snap.docs) {
        final data = doc.data();
        final margin = _storedMargin(data)!;
        final newPrice = _computePricePer1000(
          baseCostPer1000Egp: pricing.egpCostPer1000,
          marginPercent: margin,
        );
        batch.update(doc.reference, {
          'pricePer1000': newPrice,
          'marginPercent': margin,
          'margin_percent': margin,
        });
      }

      await batch.commit();

      if (!mounted) return;
      TopSnackBar.show(
        context,
        'تم تحديث ${snap.docs.length} شريحة من سعر الدولار والنسب',
        backgroundColor: Colors.green,
        textColor: Colors.white,
        icon: Icons.check_circle,
      );
    } catch (e) {
      if (!mounted) return;
      TopSnackBar.show(
        context,
        e is FormatException ? e.message : 'تعذر تحديث الشرائح',
        backgroundColor: Colors.red,
        textColor: Colors.white,
        icon: Icons.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isEditing = false);
      }
    }
  }

  double _dialogMaxHeight(BuildContext ctx) {
    final mq = MediaQuery.of(ctx);
    final available = mq.size.height - mq.viewInsets.bottom - 200;
    return available.clamp(240.0, 620.0);
  }

  Widget _buildPricingCard(
    BuildContext context, {
    required ColorScheme colorScheme,
    required _PricingInputs? pricing,
  }) {
    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'التسعير من الدولار والنسب',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'الأدمن يكتب سعر الدولار وسعر 1000 بالدولار، '
            'ثم يتم إنتاج سعر 1000 بالجنيه تلقائيًا مع التقريب لمنزلة عشرية واحدة فقط. '
            'كل شريحة تُكتب بحدها الأدنى والأقصى والنسبة فقط.',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _usdRateCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'سعر الدولار'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _usdCostPer1000Ctrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'سعر 1000 بالدولار',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _egpCostPer1000Ctrl,
            readOnly: true,
            enableInteractiveSelection: false,
            decoration: const InputDecoration(labelText: 'سعر 1000 بالجنيه'),
          ),
          const SizedBox(height: 8),
          Text(
            pricing == null
                ? 'أدخل القيم الأساسية ليتم الحساب تلقائيًا.'
                : 'سعر 1000 بالجنيه الحالي: ${_formatSingleDecimal(pricing.egpCostPer1000)} ج.م',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontFamily: 'Cairo',
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _isEditing ? null : _savePricingSettingsOnly,
                icon: const Icon(Icons.save_outlined),
                label: const Text('حفظ الإعدادات'),
              ),
              OutlinedButton.icon(
                onPressed: _isEditing ? null : _applyPricingToAllRanges,
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('تحديث كل الشرائح'),
              ),
              OutlinedButton.icon(
                onPressed: _isEditing ? null : () => _editRange(null),
                icon: const Icon(Icons.add),
                label: const Text('إضافة شريحة'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editRange(
    QueryDocumentSnapshot<Map<String, dynamic>>? doc,
  ) async {
    final pricing = _requirePricingInputs();
    if (pricing == null) return;

    final data = doc?.data() ?? const <String, dynamic>{};
    final storedPrice = _parsePositive(data['pricePer1000']);
    final storedMargin = _storedMargin(data);
    final derivedMargin =
        storedMargin ??
        (storedPrice == null
            ? null
            : _deriveMarginFromPrice(
                pricePer1000: storedPrice,
                baseCostPer1000Egp: pricing.egpCostPer1000,
              ));

    final result = await showDialog<_EditRangeDialogResult>(
      context: context,
      builder: (ctx) => _EditRangeDialog(
        title: doc == null ? 'إضافة شريحة جديدة' : 'تعديل الشريحة',
        baseCostPer1000Egp: pricing.egpCostPer1000,
        initialMin: (data['min'] as num?)?.toInt(),
        initialMax: (data['max'] as num?)?.toInt(),
        initialMargin: derivedMargin,
        allowDelete: doc != null,
        showDerivedMarginHint: storedMargin == null && derivedMargin != null,
        formatSingleDecimal: _formatSingleDecimal,
        dialogMaxHeight: _dialogMaxHeight,
      ),
    );

    if (!mounted || result == null) return;

    if (result.deleteRequested) {
      if (doc == null) return;
      setState(() => _isEditing = true);
      try {
        await doc.reference.delete();
        if (!mounted) return;
        TopSnackBar.show(
          context,
          'تم حذف الشريحة',
          backgroundColor: Colors.green,
          textColor: Colors.white,
          icon: Icons.check_circle,
        );
      } catch (_) {
        if (!mounted) return;
        TopSnackBar.show(
          context,
          'تعذر الحذف',
          backgroundColor: Colors.red,
          textColor: Colors.white,
          icon: Icons.error,
        );
      } finally {
        if (mounted) setState(() => _isEditing = false);
      }
      return;
    }

    final min = result.min;
    final max = result.max;
    final margin = result.margin;

    if (min == null || max == null || margin == null) {
      TopSnackBar.show(
        context,
        'أدخل min و max و النسبة بقيم صحيحة',
        backgroundColor: Colors.red,
        textColor: Colors.white,
        icon: Icons.error,
      );
      return;
    }

    final rangeError = _validateRange(min: min, max: max);
    if (rangeError != null) {
      TopSnackBar.show(
        context,
        rangeError,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        icon: Icons.error,
      );
      return;
    }

    final latestPricing = _requirePricingInputs();
    if (latestPricing == null) return;

    final autoPrice = _computePricePer1000(
      baseCostPer1000Egp: latestPricing.egpCostPer1000,
      marginPercent: margin,
    );

    setState(() => _isEditing = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('prices')
          .orderBy('min')
          .get();
      final overlaps = snap.docs.where((d) {
        if (doc != null && d.id == doc.id) {
          return false;
        }
        final dMin = (d['min'] as num?)?.toInt() ?? 0;
        final dMax = (d['max'] as num?)?.toInt() ?? 0;
        final separated = max < dMin || min > dMax;
        return !separated;
      });
      if (overlaps.isNotEmpty) {
        if (!mounted) return;
        TopSnackBar.show(
          context,
          'الشريحة تتداخل مع شريحة أخرى، عدل الحدود.',
          backgroundColor: Colors.red,
          textColor: Colors.white,
          icon: Icons.error,
        );
        return;
      }

      final batch = FirebaseFirestore.instance.batch();
      _persistPricingSettingsInBatch(batch, latestPricing);

      final dataToSave = {
        'min': min,
        'max': max,
        'marginPercent': margin,
        'margin_percent': margin,
        'pricePer1000': autoPrice,
      };

      if (doc == null) {
        final ref = FirebaseFirestore.instance.collection('prices').doc();
        batch.set(ref, dataToSave);
      } else {
        batch.update(doc.reference, dataToSave);
      }

      await batch.commit();

      if (!mounted) return;
      TopSnackBar.show(
        context,
        'تم الحفظ. السعر الناتج ${_formatSingleDecimal(autoPrice)} ج.م',
        backgroundColor: Colors.green,
        textColor: Colors.white,
        icon: Icons.check_circle,
      );
    } catch (_) {
      if (!mounted) return;
      TopSnackBar.show(
        context,
        'تعذر الحفظ',
        backgroundColor: Colors.red,
        textColor: Colors.white,
        icon: Icons.error,
      );
    } finally {
      if (mounted) setState(() => _isEditing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pricing = _pricingInputs();

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: GlassAppBar(
        title: const Text('تعديل الأسعار'),
        actions: [
          IconButton(
            icon: _isLoadingPricing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'إعادة تحميل الإعدادات',
            onPressed: _isLoadingPricing || _isEditing
                ? null
                : () => _loadPricingSettings(),
          ),
          IconButton(
            icon: const Icon(Icons.auto_fix_high),
            tooltip: 'تحديث كل الشرائح',
            onPressed: _isEditing ? null : _applyPricingToAllRanges,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'إضافة شريحة',
            onPressed: _isEditing ? null : () => _editRange(null),
          ),
          IconButton(
            icon: const Icon(Icons.local_offer),
            tooltip: 'عروض الأسعار',
            onPressed: () {
              AppNavigator.pushNamed(context, '/admin/offers');
            },
          ),
          IconButton(
            icon: const Icon(Icons.calculate),
            tooltip: 'حاسبة التكلفة اليدوية',
            onPressed: () {
              AppNavigator.pushNamed(context, '/admin/cost-calculator');
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          const SnowBackground(),
          SafeArea(
            bottom: false,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('prices')
                  .orderBy('min')
                  .snapshots(),
              builder: (c, s) {
                Widget rangesSliver;
                if (!s.hasData) {
                  rangesSliver = const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  );
                } else if (s.data!.docs.isEmpty) {
                  rangesSliver = SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('لا توجد أسعار مسجلة'),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _isEditing
                                  ? null
                                  : () => _editRange(null),
                              icon: const Icon(Icons.add),
                              label: const Text('إضافة شريحة'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                } else {
                  final docs = s.data!.docs;
                  rangesSliver = SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final doc = docs[index];
                      final data = doc.data();
                      final min = (data['min'] as num?)?.toInt() ?? 0;
                      final max = (data['max'] as num?)?.toInt() ?? 0;
                      final price =
                          (data['pricePer1000'] as num?)?.toDouble() ?? 0;
                      final margin = _storedMargin(data);
                      final livePrice = pricing == null || margin == null
                          ? null
                          : _computePricePer1000(
                              baseCostPer1000Egp: pricing.egpCostPer1000,
                              marginPercent: margin,
                            );
                      final showLivePrice =
                          livePrice != null &&
                          (livePrice - price).abs() > 0.049;

                      return GlassCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'المدى: $min - $max',
                                    style: TextStyle(
                                      color: colorScheme.onSurface,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'سعر كل 1000 الحالي: ${_formatSingleDecimal(price)} ج.م',
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    margin == null
                                        ? 'النسبة: غير محددة'
                                        : 'النسبة: ${_formatNumber(margin)}%',
                                    style: TextStyle(
                                      color: margin == null
                                          ? Colors.orange
                                          : colorScheme.onSurfaceVariant,
                                      fontFamily: 'Cairo',
                                    ),
                                  ),
                                  if (showLivePrice)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        'السعر بعد تطبيق الإعدادات الحالية: ${_formatSingleDecimal(livePrice)} ج.م',
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontFamily: 'Cairo',
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _isEditing
                                  ? null
                                  : () => _editRange(doc),
                              icon: const Icon(Icons.edit),
                              label: const Text('تعديل'),
                            ),
                          ],
                        ),
                      );
                    }, childCount: docs.length),
                  );
                }

                return CustomScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      sliver: SliverToBoxAdapter(
                        child: _buildPricingCard(
                          context,
                          colorScheme: colorScheme,
                          pricing: pricing,
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      sliver: rangesSliver,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PricingInputs {
  const _PricingInputs({
    required this.usdRate,
    required this.usdCostPer1000,
    required this.egpCostPer1000,
  });

  final double usdRate;
  final double usdCostPer1000;
  final double egpCostPer1000;
}

class _EditRangeDialogResult {
  const _EditRangeDialogResult({
    this.min,
    this.max,
    this.margin,
    this.deleteRequested = false,
  });

  const _EditRangeDialogResult.delete() : this(deleteRequested: true);

  final int? min;
  final int? max;
  final double? margin;
  final bool deleteRequested;
}

class _EditRangeDialog extends StatefulWidget {
  const _EditRangeDialog({
    required this.title,
    required this.baseCostPer1000Egp,
    required this.allowDelete,
    required this.showDerivedMarginHint,
    required this.formatSingleDecimal,
    required this.dialogMaxHeight,
    this.initialMin,
    this.initialMax,
    this.initialMargin,
  });

  final String title;
  final double baseCostPer1000Egp;
  final int? initialMin;
  final int? initialMax;
  final double? initialMargin;
  final bool allowDelete;
  final bool showDerivedMarginHint;
  final String Function(double value) formatSingleDecimal;
  final double Function(BuildContext context) dialogMaxHeight;

  @override
  State<_EditRangeDialog> createState() => _EditRangeDialogState();
}

class _EditRangeDialogState extends State<_EditRangeDialog> {
  late final TextEditingController _minCtrl;
  late final TextEditingController _maxCtrl;
  late final TextEditingController _marginCtrl;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _minCtrl = TextEditingController(
      text: widget.initialMin == null ? '' : widget.initialMin.toString(),
    );
    _maxCtrl = TextEditingController(
      text: widget.initialMax == null ? '' : widget.initialMax.toString(),
    );
    _marginCtrl = TextEditingController(
      text: widget.initialMargin == null
          ? ''
          : widget.initialMargin!
                .toStringAsFixed(3)
                .replaceFirst(RegExp(r'\.?0+$'), '')
                .replaceAll(RegExp(r'(\.\d*?)0+$'), r'$1'),
    );
    _marginCtrl.addListener(_handleInputChanged);
  }

  @override
  void dispose() {
    _marginCtrl.removeListener(_handleInputChanged);
    _minCtrl.dispose();
    _maxCtrl.dispose();
    _marginCtrl.dispose();
    super.dispose();
  }

  void _handleInputChanged() {
    if (!mounted) return;
    setState(() {
      _errorMessage = '';
    });
  }

  double? _parseNumber(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  int? _parseWholeNumber(String raw) {
    final value = _parseNumber(raw);
    if (value == null || value != value.roundToDouble()) return null;
    return value.toInt();
  }

  double? _parseMargin(String raw) {
    final value = _parseNumber(raw);
    if (value == null || value < 0) return null;
    return value;
  }

  double _roundToSingleDecimal(double value) {
    return double.parse(value.toStringAsFixed(1));
  }

  double? _previewPrice() {
    final margin = _parseMargin(_marginCtrl.text);
    if (margin == null) return null;
    return _roundToSingleDecimal(
      widget.baseCostPer1000Egp * (1 + margin / 100),
    );
  }

  void _submit() {
    final min = _parseWholeNumber(_minCtrl.text);
    final max = _parseWholeNumber(_maxCtrl.text);
    final margin = _parseMargin(_marginCtrl.text);
    if (min == null || max == null || margin == null) {
      setState(() {
        _errorMessage = 'أدخل min و max و النسبة بقيم صحيحة';
      });
      return;
    }
    Navigator.of(
      context,
    ).pop(_EditRangeDialogResult(min: min, max: max, margin: margin));
  }

  @override
  Widget build(BuildContext context) {
    final previewPrice = _previewPrice();
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: widget.dialogMaxHeight(context),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'سعر 1000 بالجنيه الحالي: ${widget.formatSingleDecimal(widget.baseCostPer1000Egp)} ج.م',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _minCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: false,
                ),
                decoration: const InputDecoration(labelText: 'الحد الأدنى'),
              ),
              TextField(
                controller: _maxCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: false,
                ),
                decoration: const InputDecoration(labelText: 'الحد الأقصى'),
              ),
              TextField(
                controller: _marginCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'النسبة %',
                  hintText: 'مثال: 8.5',
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'سعر الشريحة الناتج تلقائيًا',
                ),
                child: Text(
                  previewPrice == null
                      ? '--'
                      : '${widget.formatSingleDecimal(previewPrice)} ج.م',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (widget.showDerivedMarginHint)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'تم استنتاج النسبة من السعر الحالي. راجعها قبل الحفظ.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontFamily: 'Cairo',
                      fontSize: 12,
                    ),
                  ),
                ),
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _errorMessage,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontFamily: 'Cairo',
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      actions: [
        SizedBox(
          width: double.maxFinite,
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (widget.allowDelete)
                TextButton(
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).pop(const _EditRangeDialogResult.delete());
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('حذف'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
