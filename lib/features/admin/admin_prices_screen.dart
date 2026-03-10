// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/app_navigator.dart';
import '../../widgets/glass_app_bar.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/modal_utils.dart';
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

  String _formatNumber(double value) {
    final fixed = value.toStringAsFixed(6);
    return fixed
        .replaceFirst(RegExp(r'\.?0+$'), '')
        .replaceAll(RegExp(r'(\.\d*?)0+$'), r'$1');
  }

  String _formatSingleDecimal(double value) {
    final rounded = double.parse(value.toStringAsFixed(1));
    return _formatNumber(rounded);
  }

  _PricingInputs? _pricingInputs() {
    final usdRate = _parsePositive(_usdRateCtrl.text);
    final usdCostPer1000 = _parsePositive(_usdCostPer1000Ctrl.text);
    if (usdRate == null || usdCostPer1000 == null) return null;
    final egpCostPer1000 = usdRate * usdCostPer1000;
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

  double? _legacyDerivedPricePer1000(
    Map<String, dynamic> data,
    _PricingInputs? pricing,
  ) {
    final storedPrice = _parsePositive(data['pricePer1000']);
    if (storedPrice != null) return storedPrice;

    final margin = _parseNumber(
      data['marginPercent'] ?? data['margin_percent'],
    );
    if (pricing == null || margin == null || margin < 0) return null;
    return pricing.egpCostPer1000 * (1 + margin / 100);
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
            'التكلفة من الدولار والأسعار يدويًا',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'الأدمن يكتب سعر الدولار وسعر 1000 بالدولار فقط، '
            'وسعر التكلفة بالجنيه يظهر تلقائيًا. '
            'بعد ذلك يتم إدخال سعر كل شريحة يدويًا بدون نسب أو هوامش ربح.',
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
            decoration: const InputDecoration(
              labelText: 'سعر تكلفة 1000 بالجنيه',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            pricing == null
                ? 'أدخل القيم الأساسية ليظهر سعر التكلفة بالجنيه تلقائيًا.'
                : 'سعر تكلفة 1000 الحالي: ${_formatSingleDecimal(pricing.egpCostPer1000)} ج.م',
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
    final pricing = _pricingInputs();
    final data = doc?.data() ?? const <String, dynamic>{};
    final initialPrice = _legacyDerivedPricePer1000(data, pricing);

    final result = await showLockedDialog<_EditRangeDialogResult>(
      context: context,
      builder: (ctx) => _EditRangeDialog(
        title: doc == null ? 'إضافة شريحة جديدة' : 'تعديل الشريحة',
        baseCostPer1000Egp: pricing?.egpCostPer1000,
        initialMin: (data['min'] as num?)?.toInt(),
        initialMax: (data['max'] as num?)?.toInt(),
        initialPricePer1000: initialPrice,
        allowDelete: doc != null,
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
    final pricePer1000 = result.pricePer1000;
    if (min == null || max == null || pricePer1000 == null) {
      TopSnackBar.show(
        context,
        'أدخل min و max وسعر الشريحة بقيم صحيحة',
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

    final latestPricing = _pricingInputs();

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
      if (latestPricing != null) {
        _persistPricingSettingsInBatch(batch, latestPricing);
      }

      final createPayload = <String, dynamic>{
        'min': min,
        'max': max,
        'pricePer1000': pricePer1000,
      };
      final updatePayload = <String, dynamic>{
        ...createPayload,
        'marginPercent': FieldValue.delete(),
        'margin_percent': FieldValue.delete(),
      };

      if (doc == null) {
        final ref = FirebaseFirestore.instance.collection('prices').doc();
        batch.set(ref, createPayload);
      } else {
        batch.update(doc.reference, updatePayload);
      }

      await batch.commit();

      if (!mounted) return;
      TopSnackBar.show(
        context,
        'تم حفظ الشريحة. السعر الحالي ${_formatSingleDecimal(pricePer1000)} ج.م',
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
                      final price = _legacyDerivedPricePer1000(data, pricing);

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
                                    price == null
                                        ? 'سعر كل 1000 الحالي: غير محدد'
                                        : 'سعر كل 1000 الحالي: ${_formatSingleDecimal(price)} ج.م',
                                    style: TextStyle(
                                      color: price == null
                                          ? Colors.orange
                                          : colorScheme.onSurfaceVariant,
                                      fontFamily: 'Cairo',
                                    ),
                                  ),
                                  if (pricing != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        'سعر التكلفة الحالي: ${_formatSingleDecimal(pricing.egpCostPer1000)} ج.م',
                                        style: TextStyle(
                                          color: colorScheme.onSurfaceVariant,
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
    this.pricePer1000,
    this.deleteRequested = false,
  });

  const _EditRangeDialogResult.delete() : this(deleteRequested: true);

  final int? min;
  final int? max;
  final double? pricePer1000;
  final bool deleteRequested;
}

class _EditRangeDialog extends StatefulWidget {
  const _EditRangeDialog({
    required this.title,
    required this.allowDelete,
    required this.formatSingleDecimal,
    required this.dialogMaxHeight,
    this.baseCostPer1000Egp,
    this.initialMin,
    this.initialMax,
    this.initialPricePer1000,
  });

  final String title;
  final double? baseCostPer1000Egp;
  final int? initialMin;
  final int? initialMax;
  final double? initialPricePer1000;
  final bool allowDelete;
  final String Function(double value) formatSingleDecimal;
  final double Function(BuildContext context) dialogMaxHeight;

  @override
  State<_EditRangeDialog> createState() => _EditRangeDialogState();
}

class _EditRangeDialogState extends State<_EditRangeDialog> {
  late final TextEditingController _minCtrl;
  late final TextEditingController _maxCtrl;
  late final TextEditingController _priceCtrl;
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
    _priceCtrl = TextEditingController(
      text: widget.initialPricePer1000 == null
          ? ''
          : widget.formatSingleDecimal(widget.initialPricePer1000!),
    );
    _priceCtrl.addListener(_handleInputChanged);
  }

  @override
  void dispose() {
    _priceCtrl.removeListener(_handleInputChanged);
    _minCtrl.dispose();
    _maxCtrl.dispose();
    _priceCtrl.dispose();
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

  double? _parsePositivePrice(String raw) {
    final value = _parseNumber(raw);
    if (value == null || value <= 0) return null;
    return value;
  }

  void _submit() {
    final min = _parseWholeNumber(_minCtrl.text);
    final max = _parseWholeNumber(_maxCtrl.text);
    final pricePer1000 = _parsePositivePrice(_priceCtrl.text);
    if (min == null || max == null || pricePer1000 == null) {
      setState(() {
        _errorMessage = 'أدخل min و max وسعر الشريحة بقيم صحيحة';
      });
      return;
    }

    Navigator.of(context).pop(
      _EditRangeDialogResult(min: min, max: max, pricePer1000: pricePer1000),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              if (widget.baseCostPer1000Egp != null)
                Text(
                  'سعر تكلفة 1000 بالجنيه الحالي: ${widget.formatSingleDecimal(widget.baseCostPer1000Egp!)} ج.م',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontFamily: 'Cairo',
                  ),
                ),
              if (widget.baseCostPer1000Egp != null) const SizedBox(height: 10),
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
                controller: _priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'سعر كل 1000 يدويًا',
                  hintText: 'مثال: 151.5',
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
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
