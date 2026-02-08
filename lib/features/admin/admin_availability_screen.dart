// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/tt_colors.dart';
import '../../widgets/glass_app_bar.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/top_snackbar.dart';

class AdminAvailabilityScreen extends StatefulWidget {
  const AdminAvailabilityScreen({super.key});

  @override
  State<AdminAvailabilityScreen> createState() =>
      _AdminAvailabilityScreenState();
}

class _AdminAvailabilityScreenState extends State<AdminAvailabilityScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _enabled = true;
  final TextEditingController _maintenanceCtrl =
      TextEditingController(text: "الشحن غير متاح حاليا");

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _maintenanceCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('availability')
          .get();

      if (doc.exists) {
        final data = doc.data() ?? {};
        _enabled = data['enabled'] == null ? true : data['enabled'] == true;
        _maintenanceCtrl.text = (data['maintenance_message'] ??
                "الشحن غير متاح حاليا ")
            .toString();
      }
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('availability')
          .set({
        'enabled': _enabled,
        'maintenance_message': _maintenanceCtrl.text.trim(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      TopSnackBar.show(
        context,
        "تم حفظ الإعدادات ✅",
        backgroundColor: Colors.green,
        textColor: Colors.white,
        icon: Icons.check_circle,
      );
    } catch (_) {
      if (!mounted) return;
      TopSnackBar.show(
        context,
        "حدث خطأ أثناء الحفظ",
        backgroundColor: Colors.red,
        textColor: Colors.white,
        icon: Icons.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GlassAppBar(title: Text("إدارة الصيانة")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GlassCard(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        value: _enabled,
                        onChanged: (v) => setState(() => _enabled = v),
                        title: const Text(
                          "تشغيل الموقع / التطبيق",
                          style: TextStyle(fontFamily: 'Cairo'),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "عند الإيقاف سيظهر للمستخدمين: صيانة",
                        style: TextStyle(color: TTColors.textGray),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _maintenanceCtrl,
                        decoration: const InputDecoration(
                          labelText: "رسالة الصيانة",
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(_saving ? "جاري الحفظ..." : "حفظ الإعدادات"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TTColors.primaryCyan,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
