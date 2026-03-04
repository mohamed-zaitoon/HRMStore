// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:flutter/material.dart';

import '../../widgets/glass_app_bar.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/snow_background.dart';
import '../../widgets/top_snackbar.dart';

class AdminCostCalculatorScreen extends StatefulWidget {
  const AdminCostCalculatorScreen({super.key});

  @override
  State<AdminCostCalculatorScreen> createState() =>
      _AdminCostCalculatorScreenState();
}

class _AdminCostCalculatorScreenState extends State<AdminCostCalculatorScreen> {
  final TextEditingController _basePricePer1000Ctrl = TextEditingController();
  final TextEditingController _coinsCountCtrl = TextEditingController();
  double? _manualCalculatedCost;

  @override
  void dispose() {
    _basePricePer1000Ctrl.dispose();
    _coinsCountCtrl.dispose();
    super.dispose();
  }

  double? _parsePositive(String raw) {
    final value = double.tryParse(raw.trim().replaceAll(',', '.'));
    if (value == null || value <= 0) return null;
    return value;
  }

  void _calculateManualCost() {
    final basePrice = _parsePositive(_basePricePer1000Ctrl.text);
    if (basePrice == null) {
      TopSnackBar.show(
        context,
        "أدخل سعر 1000 بدون مكسب بشكل صحيح",
        backgroundColor: Colors.red,
        textColor: Colors.white,
        icon: Icons.error,
      );
      return;
    }

    final coins = _parsePositive(_coinsCountCtrl.text);
    if (coins == null) {
      TopSnackBar.show(
        context,
        "أدخل عدد العملات بشكل صحيح",
        backgroundColor: Colors.red,
        textColor: Colors.white,
        icon: Icons.error,
      );
      return;
    }

    final totalCost = double.parse(
      ((coins / 1000) * basePrice).toStringAsFixed(2),
    );

    setState(() {
      _manualCalculatedCost = totalCost;
    });

    TopSnackBar.show(
      context,
      "تم حساب التكلفة اليدوية ✅",
      backgroundColor: Colors.green,
      textColor: Colors.white,
      icon: Icons.check_circle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: const GlassAppBar(title: Text("حاسبة التكلفة اليدوية")),
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
                      "حاسبة مستقلة",
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _basePricePer1000Ctrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: "سعر 1000 بدون مكسب",
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
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _calculateManualCost,
                        icon: const Icon(Icons.calculate),
                        label: const Text("احسب التكلفة"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    if (_manualCalculatedCost != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        "التكلفة: ${_manualCalculatedCost!.toStringAsFixed(2)} ج.م",
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
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
