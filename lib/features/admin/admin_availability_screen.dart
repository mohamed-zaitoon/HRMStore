// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../widgets/glass_app_bar.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/snow_background.dart';
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
  bool _webEnabled = true;
  bool _androidReleaseEnabled = true;
  final TextEditingController _platformPauseCtrl = TextEditingController(
    text: "الخدمة متوقفة مؤقتاً حالياً (ليست صيانة).",
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _platformPauseCtrl.dispose();
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
        final hasWebKey = data.containsKey('web_enabled');
        final hasAndroidReleaseKey = data.containsKey('android_release_enabled');
        final legacyEnabled =
            data['enabled'] == null ? true : data['enabled'] == true;
        _webEnabled = hasWebKey
            ? data['web_enabled'] == true
            : legacyEnabled;
        _androidReleaseEnabled = hasAndroidReleaseKey
            ? data['android_release_enabled'] == true
            : legacyEnabled;
        _platformPauseCtrl.text =
            (data['platform_pause_message'] ??
                    data['maintenance_message'] ??
                    "الخدمة متوقفة مؤقتاً حالياً (ليست صيانة).")
                .toString();
      }
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final pauseMessage = _platformPauseCtrl.text.trim();
      final fallbackMessage = pauseMessage.isEmpty
          ? "الخدمة متوقفة مؤقتاً حالياً (ليست صيانة)."
          : pauseMessage;
      final legacyEnabled = _webEnabled && _androidReleaseEnabled;

      await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('availability')
          .set({
            'web_enabled': _webEnabled,
            'android_release_enabled': _androidReleaseEnabled,
            'platform_pause_message': fallbackMessage,
            'web_pause_message': fallbackMessage,
            'android_release_pause_message': fallbackMessage,
            // توافق خلفي: النسخ القديمة تقرأ enabled/maintenance_message فقط.
            'enabled': legacyEnabled,
            'maintenance_message': fallbackMessage,
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
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: const GlassAppBar(title: Text("إدارة التوافر")),
      body: Stack(
        children: [
          const SnowBackground(),
          _loading
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
                            value: _webEnabled,
                            onChanged: (v) => setState(() => _webEnabled = v),
                            title: const Text(
                              "تشغيل موقع الويب",
                              style: TextStyle(fontFamily: 'Cairo'),
                            ),
                          ),
                          SwitchListTile(
                            value: _androidReleaseEnabled,
                            onChanged: (v) =>
                                setState(() => _androidReleaseEnabled = v),
                            title: const Text(
                              "تشغيل أندرويد Release",
                              style: TextStyle(fontFamily: 'Cairo'),
                            ),
                            subtitle: const Text(
                              "وضع Debug غير متأثر بهذا الإيقاف.",
                              style: TextStyle(fontFamily: 'Cairo'),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "الإيقاف يطبّق فقط على الويب وAndroid Release، ونسخة Debug غير متأثرة.",
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _platformPauseCtrl,
                            decoration: const InputDecoration(
                              labelText: "سبب الإيقاف (تعديل يدوي)",
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
                            : const Icon(Icons.save),
                        label: Text(
                          _saving ? "جاري الحفظ..." : "حفظ الإعدادات",
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
        ],
      ),
    );
  }
}
