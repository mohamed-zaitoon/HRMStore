// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  bool _isEditing = false;
  final TextEditingController _baseCostCtrl = TextEditingController(text: '0');
  final TextEditingController _marginCtrl = TextEditingController(text: '0');
  final TextEditingController _usdRateCtrl = TextEditingController(
    text: '50.8',
  );
  final TextEditingController _usdCostCtrl = TextEditingController(
    text: _usdCostPer1000.toString(),
  );
  double? _usdRate;
  bool _loadingUsd = false;
  bool _baseCostAutoFilled = false;

  static const double _usdCostPer1000 = 10.41; // USD cost per 1000

  @override
  void initState() {
    super.initState();
    _loadUsdRate();
  }

  @override
  void dispose() {
    _baseCostCtrl.dispose();
    _marginCtrl.dispose();
    _usdRateCtrl.dispose();
    _usdCostCtrl.dispose();
    super.dispose();
  }

  double? _parsePositive(String raw) {
    final value = double.tryParse(raw.trim().replaceAll(',', '.'));
    if (value == null || value <= 0) return null;
    return value;
  }

  double _ceilToNearestFive(double value) {
    final rounded = value.ceil();
    final rem = rounded % 5;
    return (rem == 0 ? rounded : rounded + (5 - rem)).toDouble();
  }

  double _roundCost(double value) {
    return double.parse(value.toStringAsFixed(1));
  }

  double _roundPrice(double value) {
    return _ceilToNearestFive(value);
  }

  String _formatPrice(double value) => value.toStringAsFixed(0);

  double? _parseUsd(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw.trim());
    return null;
  }

  void _syncBaseCostFromUsd({bool force = false}) {
    final usdRate = _parseUsd(_usdRateCtrl.text);
    final usdCost = _parseUsd(_usdCostCtrl.text);
    if (usdRate == null || usdRate <= 0 || usdCost == null || usdCost <= 0) {
      return;
    }
    if (!_baseCostAutoFilled && !force) return;
    final egpCost = _roundCost(usdRate * usdCost);
    _baseCostAutoFilled = true;
    _baseCostCtrl.text = egpCost.toStringAsFixed(1);
    setState(() {});
  }

  Future<void> _copyPricesAsJson() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('prices')
          .orderBy('min')
          .get();

      final prices = snap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        return {
          'min': data['min'],
          'max': data['max'],
          'pricePer1000': data['pricePer1000'],
        };
      }).toList();

      final json = const JsonEncoder.withIndent(
        '  ',
      ).convert({'prices': prices});
      await Clipboard.setData(ClipboardData(text: json));
      if (!mounted) return;
      TopSnackBar.show(
        context,
        "تم نسخ البيانات كـ JSON",
        backgroundColor: Colors.green,
        textColor: Colors.white,
        icon: Icons.check_circle,
      );
    } catch (e) {
      if (!mounted) return;
      TopSnackBar.show(
        context,
        "تعذر نسخ JSON",
        backgroundColor: Colors.red,
        textColor: Colors.white,
        icon: Icons.error,
      );
    }
  }

  Future<void> _loadUsdRate({bool fromServer = true}) async {
    setState(() => _loadingUsd = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('currency')
          .get(GetOptions(source: fromServer ? Source.server : Source.cache));
      final data = snap.data();
      final rate = _parseUsd(data?['usd_price'] ?? data?['usd_egp']);
      if (rate != null && rate > 0) {
        final egpCost = _roundCost(rate * _usdCostPer1000);
        setState(() {
          _usdRate = rate;
          _usdRateCtrl.text = rate.toStringAsFixed(3);
          if (_baseCostCtrl.text.trim().isEmpty ||
              double.tryParse(_baseCostCtrl.text.trim()) == 0 ||
              !_baseCostAutoFilled) {
            _baseCostAutoFilled = true;
            _baseCostCtrl.text = egpCost.toStringAsFixed(1);
          }
        });
      }
    } catch (_) {
      if (fromServer) {
        await _loadUsdRate(fromServer: false);
      }
    } finally {
      if (mounted) setState(() => _loadingUsd = false);
    }
  }

  double? _autoPriceFromCost() {
    final cost = _parsePositive(_baseCostCtrl.text);
    if (cost == null) return null;
    const margin = 0.0;
    return _roundPrice(cost * (1 + (margin / 100)));
  }

  double? _priceForMinRange(int min) {
    final base = _baseCostEgp();
    if (base <= 0) return null;
    final margin = _marginForMin(min);
    return _roundPrice(base * (1 + margin / 100));
  }

  double _dialogMaxHeight(BuildContext ctx) {
    final mq = MediaQuery.of(ctx);
    final available = mq.size.height - mq.viewInsets.bottom - 200;
    return available.clamp(240.0, 520.0);
  }

  double _baseCostEgp() {
    final rate = _parseUsd(_usdRateCtrl.text);
    final usdCost = _parseUsd(_usdCostCtrl.text);
    if (rate != null && rate > 0 && usdCost != null && usdCost > 0) {
      return rate * usdCost;
    }
    return _parsePositive(_baseCostCtrl.text) ?? 0;
  }

  double? _computeMargin(double pricePer1000) {
    final base = _baseCostEgp();
    if (base <= 0) return null;
    return ((pricePer1000 - base) / base) * 100;
  }

  EdgeInsets _dialogInset(BuildContext ctx) {
    final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
    return EdgeInsets.fromLTRB(
      12,
      28,
      12,
      bottomInset > 0 ? bottomInset + 12 : 24,
    );
  }

  double _marginForMin(int min) {
    // نسب مستخرجة من الأسعار المعتمدة
    if (min >= 100000) return 0.22;
    if (min >= 50000) return 1.17;
    if (min >= 30000) return 2.11;
    if (min >= 10000) return 3.06;
    if (min >= 1000) return 4.0;
    if (min >= 500) return 9.7;
    return 21.0;
  }

  Future<void> _repriceAllFromUsd() async {
    final newRate = _parseUsd(_usdRateCtrl.text);
    if (newRate == null || newRate <= 0) {
      TopSnackBar.show(
        context,
        "أدخل سعر دولار صالح",
        backgroundColor: Colors.red,
        textColor: Colors.white,
        icon: Icons.error,
      );
      return;
    }

    setState(() => _loadingUsd = true);
    try {
      final usdCost = _parseUsd(_usdCostCtrl.text) ?? _usdCostPer1000;
      final baseCost = newRate * usdCost;
      final pricesSnap = await FirebaseFirestore.instance
          .collection('prices')
          .orderBy('min')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in pricesSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final min = (data['min'] as num?)?.toInt() ?? 0;
        final margin = _marginForMin(min);
        final newPrice = _roundPrice(baseCost * (1 + margin / 100));
        batch.update(doc.reference, {'pricePer1000': newPrice});
      }

      // حفظ سعر الدولار في app_settings/currency ليصبح مرجعاً للجولة القادمة
      final currencyDoc = FirebaseFirestore.instance
          .collection('app_settings')
          .doc('currency');
      batch.set(currencyDoc, {'usd_price': newRate}, SetOptions(merge: true));

      await batch.commit();

      setState(() {
        _usdRate = newRate;
        _usdRateCtrl.text = newRate.toStringAsFixed(3);
        _syncBaseCostFromUsd(force: true);
      });

      if (!mounted) return;
      TopSnackBar.show(
        context,
        "تم تحديث الأسعار بناءً على سعر الدولار",
        backgroundColor: Colors.green,
        textColor: Colors.white,
        icon: Icons.check_circle,
      );
    } catch (_) {
      if (!mounted) return;
      TopSnackBar.show(
        context,
        "تعذر تحديث الأسعار",
        backgroundColor: Colors.red,
        textColor: Colors.white,
        icon: Icons.error,
      );
    } finally {
      if (mounted) setState(() => _loadingUsd = false);
    }
  }

  Future<void> _repriceAllWithDefaultMargins() async {
    final baseCost = _baseCostEgp();
    if (baseCost <= 0) {
      TopSnackBar.show(
        context,
        "أدخل سعر دولار وتكلفة صحيحة أولاً",
        backgroundColor: Colors.red,
        textColor: Colors.white,
        icon: Icons.error,
      );
      return;
    }

    setState(() => _loadingUsd = true);
    try {
      final pricesSnap = await FirebaseFirestore.instance
          .collection('prices')
          .orderBy('min')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in pricesSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final int min = (data['min'] as num?)?.toInt() ?? 0;
        final margin = _marginForMin(min);
        final newPrice = _roundPrice(baseCost * (1 + margin / 100));
        batch.update(doc.reference, {'pricePer1000': newPrice});
      }

      await batch.commit();

      if (!mounted) return;
      TopSnackBar.show(
        context,
        "تم تطبيق النسب الافتراضية على كل الشرائح",
        backgroundColor: Colors.green,
        textColor: Colors.white,
        icon: Icons.check_circle,
      );
    } catch (_) {
      if (!mounted) return;
      TopSnackBar.show(
        context,
        "تعذر تطبيق النسب",
        backgroundColor: Colors.red,
        textColor: Colors.white,
        icon: Icons.error,
      );
    } finally {
      if (mounted) setState(() => _loadingUsd = false);
    }
  }

  Future<void> _editRange(DocumentSnapshot? doc) async {
    final data = (doc?.data() as Map<String, dynamic>?) ?? {};
    final minCtrl = TextEditingController(text: '${data['min'] ?? ''}');
    final maxCtrl = TextEditingController(text: '${data['max'] ?? ''}');
    final priceCtrl = TextEditingController(
      text: '${data['pricePer1000'] ?? ''}',
    );
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          scrollable: true,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 24,
          ),
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          backgroundColor: Theme.of(ctx).colorScheme.surface,
          title: Text(doc == null ? "إضافة شريحة جديدة" : "تعديل الشريحة"),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 420,
              maxHeight: _dialogMaxHeight(ctx),
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: minCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: false,
                    ),
                    decoration: const InputDecoration(labelText: "الحد الأدنى"),
                  ),
                  TextField(
                    controller: maxCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: false,
                    ),
                    decoration: const InputDecoration(labelText: "الحد الأقصى"),
                  ),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: "سعر كل 1000"),
                    onTap: () {
                      if (priceCtrl.text.trim().isEmpty) {
                        final min = int.tryParse(minCtrl.text.trim()) ?? 0;
                        final auto = _priceForMinRange(min);
                        if (auto != null) {
                          priceCtrl.text = auto.toStringAsFixed(1);
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          actions: [
            SizedBox(
              width: double.maxFinite,
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: saving
                        ? null
                        : () {
                            final min = int.tryParse(minCtrl.text.trim()) ?? 0;
                            final auto = _priceForMinRange(min);
                            if (auto == null) {
                              TopSnackBar.show(
                                context,
                                "أدخل تكلفة صحيحة وأدنى المدى أولاً",
                                backgroundColor: Colors.red,
                                textColor: Colors.white,
                                icon: Icons.error,
                              );
                              return;
                            }
                            priceCtrl.text = auto.toStringAsFixed(1);
                            TopSnackBar.show(
                              context,
                              "تم تحديث السعر تلقائياً",
                              backgroundColor: Colors.green,
                              textColor: Colors.white,
                              icon: Icons.check_circle,
                            );
                          },
                    icon: const Icon(Icons.refresh),
                    label: const Text("تحديث السعر من التكلفة"),
                  ),
                  if (doc != null)
                    TextButton(
                      onPressed: saving
                          ? null
                          : () async {
                              setDialogState(() => saving = true);
                              try {
                                await doc.reference.delete();
                                if (ctx.mounted) Navigator.pop(ctx);
                                TopSnackBar.show(
                                  context,
                                  "تم حذف الشريحة",
                                  backgroundColor: Colors.green,
                                  textColor: Colors.white,
                                  icon: Icons.check_circle,
                                );
                              } catch (_) {
                                setDialogState(() => saving = false);
                                TopSnackBar.show(
                                  context,
                                  "تعذر الحذف",
                                  backgroundColor: Colors.red,
                                  textColor: Colors.white,
                                  icon: Icons.error,
                                );
                              }
                            },
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text("حذف"),
                    ),
                  TextButton(
                    onPressed: saving ? null : () => Navigator.pop(ctx),
                    child: const Text("إلغاء"),
                  ),
                  ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            final min = int.tryParse(minCtrl.text.trim());
                            final max = int.tryParse(maxCtrl.text.trim());
                            final price = _parsePositive(priceCtrl.text);
                            final allowEqualForTop =
                                min != null &&
                                max != null &&
                                min == 100000 &&
                                max == 100000;
                            if (min == null ||
                                max == null ||
                                min < 150 ||
                                max > 100000 ||
                                (!allowEqualForTop && min >= max) ||
                                price == null) {
                              TopSnackBar.show(
                                context,
                                "المدى المسموح 150 إلى 100000 والسعر موجب",
                                backgroundColor: Colors.red,
                                textColor: Colors.white,
                                icon: Icons.error,
                              );
                              return;
                            }

                            setDialogState(() => saving = true);
                            setState(() => _isEditing = true);

                            try {
                              // منع التداخل مع شرائح أخرى
                              final snap = await FirebaseFirestore.instance
                                  .collection('prices')
                                  .orderBy('min')
                                  .get();
                              final overlaps = snap.docs.where((d) {
                                if (doc != null && d.id == doc.id) return false;
                                final dMin = (d['min'] as num?)?.toInt() ?? 0;
                                final dMax = (d['max'] as num?)?.toInt() ?? 0;
                                final separated = max < dMin || min > dMax;
                                return !separated;
                              });
                              if (overlaps.isNotEmpty) {
                                TopSnackBar.show(
                                  context,
                                  "الشريحة تتداخل مع شريحة أخرى، عدل الحدود.",
                                  backgroundColor: Colors.red,
                                  textColor: Colors.white,
                                  icon: Icons.error,
                                );
                                setDialogState(() => saving = false);
                                setState(() => _isEditing = false);
                                return;
                              }

                              final dataToSave = {
                                'min': min,
                                'max': max,
                                'pricePer1000': _roundPrice(price),
                              };

                              if (doc == null) {
                                await FirebaseFirestore.instance
                                    .collection('prices')
                                    .add(dataToSave);
                              } else {
                                await doc.reference.update(dataToSave);
                              }

                              if (!mounted) return;
                              TopSnackBar.show(
                                context,
                                "تم الحفظ ✅",
                                backgroundColor: Colors.green,
                                textColor: Colors.white,
                                icon: Icons.check_circle,
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                            } catch (_) {
                              TopSnackBar.show(
                                context,
                                "تعذر الحفظ",
                                backgroundColor: Colors.red,
                                textColor: Colors.white,
                                icon: Icons.error,
                              );
                            } finally {
                              if (mounted) setState(() => _isEditing = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(ctx).colorScheme.primary,
                      foregroundColor: Theme.of(ctx).colorScheme.onPrimary,
                    ),
                    child: saving
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(ctx).colorScheme.onPrimary,
                            ),
                          )
                        : const Text("حفظ"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: GlassAppBar(
        title: const Text("تعديل الأسعار"),
        actions: [
          IconButton(
            icon: _loadingUsd
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.currency_exchange),
            tooltip: "تحديث سعر الدولار",
            onPressed: _loadingUsd
                ? null
                : () => _loadUsdRate(fromServer: true),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: "إضافة شريحة",
            onPressed: _isEditing ? null : () => _editRange(null),
          ),
          IconButton(
            icon: const Icon(Icons.local_offer),
            tooltip: "عروض الأسعار",
            onPressed: () {
              AppNavigator.pushNamed(context, '/admin/offers');
            },
          ),
          IconButton(
            icon: const Icon(Icons.calculate),
            tooltip: "حاسبة التكلفة اليدوية",
            onPressed: () {
              AppNavigator.pushNamed(context, '/admin/cost-calculator');
            },
          ),
          IconButton(
            icon: const Icon(Icons.copy_all),
            tooltip: "نسخ الأسعار JSON",
            onPressed: _copyPricesAsJson,
          ),
          IconButton(
            icon: _loadingUsd
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.currency_bitcoin),
            tooltip: "تطبيق سعر الدولار على كل الشرائح",
            onPressed: _loadingUsd ? null : _repriceAllFromUsd,
          ),
          IconButton(
            icon: _loadingUsd
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.percent),
            tooltip: "تسعير تلقائي بالنسب الافتراضية",
            onPressed: _loadingUsd ? null : _repriceAllWithDefaultMargins,
          ),
        ],
      ),
      body: Stack(
        children: [
          const SnowBackground(),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: GlassCard(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              "التكلفة والربح الافتراضي",
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _loadingUsd
                                ? null
                                : () => _loadUsdRate(fromServer: true),
                            tooltip: "تحديث من سعر الدولار",
                            icon: _loadingUsd
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                      if (_usdRate != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            "سعر الدولار (Firestore): ${_usdRate!.toStringAsFixed(3)} ج.م",
                            style: const TextStyle(fontFamily: 'Cairo'),
                          ),
                        ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _usdRateCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: "سعر الدولار (ج.م)",
                              ),
                              onChanged: (_) {
                                _baseCostAutoFilled = true;
                                _syncBaseCostFromUsd();
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _usdCostCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: "التكلفة بالدولار لكل 1000",
                              ),
                              onChanged: (_) {
                                _baseCostAutoFilled = true;
                                _syncBaseCostFromUsd();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _baseCostCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: "سعر التكلفة لكل 1000 (ج.م)",
                              ),
                              onChanged: (_) {
                                _baseCostAutoFilled = false;
                                setState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                      if (_usdRate != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            "تقدير تلقائي للتكلفة = 10.41\$ × ${_usdRate!.toStringAsFixed(3)} ج.م",
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('prices')
                      .orderBy('min')
                      .snapshots(),
                  builder: (c, s) {
                    if (!s.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (s.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("لا توجد أسعار مسجلة"),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _isEditing
                                  ? null
                                  : () => _editRange(null),
                              icon: const Icon(Icons.add),
                              label: const Text("إضافة شريحة"),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        ...s.data!.docs.map((doc) {
                          final data = doc.data();
                          final int min = (data['min'] as num?)?.toInt() ?? 0;
                          final int max = (data['max'] as num?)?.toInt() ?? 0;
                          final double price =
                              (data['pricePer1000'] as num?)?.toDouble() ?? 0;
                          final margin = _computeMargin(price);

                          return GlassCard(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "المدى: $min - $max",
                                        style: TextStyle(
                                          color: colorScheme.onSurface,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        "سعر كل 1000: ${_formatPrice(price)} ج.م",
                                        style: TextStyle(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      if (margin != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                          ),
                                          child: Text(
                                            "هامش: ${margin.toStringAsFixed(1)}٪",
                                            style: TextStyle(
                                              color: margin >= 0
                                                  ? Colors.green
                                                  : Colors.red,
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
                                  label: const Text("تعديل"),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
