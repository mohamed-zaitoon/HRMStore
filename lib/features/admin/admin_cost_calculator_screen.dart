// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../widgets/glass_app_bar.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/snow_background.dart';

class AdminCostCalculatorScreen extends StatefulWidget {
  const AdminCostCalculatorScreen({super.key});

  @override
  State<AdminCostCalculatorScreen> createState() =>
      _AdminCostCalculatorScreenState();
}

class _AdminCostCalculatorScreenState extends State<AdminCostCalculatorScreen> {
  final TextEditingController _coinsCountCtrl = TextEditingController();

  double? _baseCostPer1000;
  double? _manualCalculatedCost;
  bool _isLoadingBaseCost = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _coinsCountCtrl.addListener(_handleCoinsChanged);
    _loadBaseCostPer1000();
  }

  @override
  void dispose() {
    _coinsCountCtrl.removeListener(_handleCoinsChanged);
    _coinsCountCtrl.dispose();
    super.dispose();
  }

  double? _parsePositive(dynamic raw) {
    if (raw is num) {
      final value = raw.toDouble();
      return value > 0 ? value : null;
    }

    if (raw is String) {
      final value = double.tryParse(raw.trim().replaceAll(',', '.'));
      if (value == null || value <= 0) return null;
      return value;
    }

    return null;
  }

  double _roundToTwoDecimals(double value) {
    return double.parse(value.toStringAsFixed(2));
  }

  double? _extractBaseCost(Map<String, dynamic> data) {
    final egpCost = _parsePositive(data['egp_cost_per_1000']);
    if (egpCost != null) return egpCost;

    final usdRate = _parsePositive(data['usd_rate']);
    final usdCostPer1000 = _parsePositive(data['usd_cost_per_1000']);
    if (usdRate != null && usdCostPer1000 != null) {
      return _roundToTwoDecimals(usdRate * usdCostPer1000);
    }

    return null;
  }

  Future<void> _loadBaseCostPer1000({bool fromServer = true}) async {
    if (!mounted) return;
    setState(() {
      _isLoadingBaseCost = true;
      _loadError = null;
    });

    try {
      final pricingSnap = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('pricing')
          .get(GetOptions(source: fromServer ? Source.server : Source.cache));

      final pricingData = pricingSnap.data() ?? const <String, dynamic>{};
      final baseCost = _extractBaseCost(pricingData);
      if (baseCost == null) {
        throw const FormatException('missing_base_cost');
      }

      if (!mounted) return;
      setState(() {
        _baseCostPer1000 = baseCost;
        _manualCalculatedCost = _calculateTotalCost();
      });
    } catch (_) {
      if (fromServer) {
        await _loadBaseCostPer1000(fromServer: false);
        return;
      }

      if (!mounted) return;
      setState(() {
        _baseCostPer1000 = null;
        _manualCalculatedCost = null;
        _loadError = 'تعذر تحميل سعر 1000 بدون مكسب من إعدادات التسعير';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBaseCost = false;
        });
      }
    }
  }

  double? _calculateTotalCost() {
    final baseCostPer1000 = _baseCostPer1000;
    final coins = _parsePositive(_coinsCountCtrl.text);
    if (baseCostPer1000 == null || coins == null) return null;
    return _roundToTwoDecimals((coins / 1000) * baseCostPer1000);
  }

  void _handleCoinsChanged() {
    if (!mounted) return;
    setState(() {
      _manualCalculatedCost = _calculateTotalCost();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasCoinsInput = _coinsCountCtrl.text.trim().isNotEmpty;

    return Scaffold(
      appBar: GlassAppBar(
        title: const Text("حاسبة التكلفة اليدوية"),
        actions: [
          IconButton(
            onPressed: _isLoadingBaseCost ? null : _loadBaseCostPer1000,
            icon: _isLoadingBaseCost
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'إعادة تحميل السعر الأساسي',
          ),
        ],
      ),
      body: Stack(
        children: [
          const SnowBackground(),
          ListView(
            padding: const EdgeInsets.all(16),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              GlassCard(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "حاسبة تكلفة الأدمن",
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "يتم جلب سعر 1000 بدون مكسب تلقائيًا من إعدادات التسعير. اكتب عدد العملات فقط وسيظهر السعر مباشرة.",
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 10),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: "سعر 1000 بدون مكسب",
                      ),
                      child: _isLoadingBaseCost
                          ? const LinearProgressIndicator(minHeight: 2)
                          : Text(
                              _baseCostPer1000 == null
                                  ? (_loadError ?? '--')
                                  : "${_baseCostPer1000!.toStringAsFixed(2)} ج.م",
                              style: TextStyle(
                                color: _baseCostPer1000 == null
                                    ? colorScheme.error
                                    : colorScheme.onSurface,
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _coinsCountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: "عدد العملات المراد حسابها",
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      !hasCoinsInput
                          ? "اكتب عدد العملات ليظهر السعر."
                          : _manualCalculatedCost == null
                          ? "أدخل عدد عملات صحيح مع توفر سعر 1000 الأساسي."
                          : "السعر: ${_manualCalculatedCost!.toStringAsFixed(2)} ج.م",
                      style: TextStyle(
                        color: _manualCalculatedCost == null
                            ? colorScheme.onSurfaceVariant
                            : colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    if (_loadError != null) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _isLoadingBaseCost
                            ? null
                            : _loadBaseCostPer1000,
                        icon: const Icon(Icons.refresh),
                        label: const Text("إعادة المحاولة"),
                      ),
                    ],
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
