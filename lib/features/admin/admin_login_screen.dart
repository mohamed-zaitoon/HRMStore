// Open-source code. Copyright Mohamed Zaitoon 2025-2026.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:crypto/crypto.dart';

import '../../services/device_service.dart';
import '../../services/notification_service.dart';
import '../../services/admin_session_service.dart';
import '../../core/app_info.dart';
import '../../widgets/glass_app_bar.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/snow_background.dart';
import '../../widgets/theme_mode_sheet.dart';
import '../../utils/html_meta.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  static const String _adminPasswordPepper = String.fromEnvironment(
    'ADMIN_PASSWORD_PEPPER',
    defaultValue: '',
  );

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _userCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  final TextEditingController _whatsappCtrl = TextEditingController();

  bool _loading = false;
  bool _checkingSession =
      true; // 👈 بنستخدمه علشان نعرض لودينج أول ما الأكتيفيتي تفتح
  String? _error;
  int _days = 1;

  final Map<int, String> _durations = {
    1: 'يوم',
    3: '3 أيام',
    7: 'أسبوع',
    30: 'شهر',
  };

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      setPageTitle(AppInfo.appName);
      setMetaDescription(
        'لوحة تحكم الأدمن لإدارة طلبات شحن نقاط تيك توك، مراجعة إيصالات الدفع، واعتماد أكواد الخصم.',
      );
    }
    _checkExistingSession(); // 👈 أول ما الشاشة تفتح: نحاول نعمل auto-login
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _whatsappCtrl.dispose();
    super.dispose();
  }

  // =========================================================
  // 🔍 التحقق من وجود جلسة محفوظة للأدمن (تذكرني)
  // =========================================================
  Future<void> _checkExistingSession() async {
    try {
      final session = await AdminSessionService.getLocalSession();
      final sessionValid = await AdminSessionService.validateCurrentSession();
      if (!sessionValid || session == null) {
        await AdminSessionService.clearLocalSession();
        if (mounted) {
          setState(() => _checkingSession = false);
        }
        return;
      }

      NotificationService.listenToAdminOrders();
      NotificationService.listenToAdminRamadanCodes();
      if (session.whatsapp.isNotEmpty) {
        await NotificationService.initAdminNotifications(
          session.whatsapp,
          requestPermission: true,
        );
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/admin/orders');
    } catch (_) {
      await AdminSessionService.clearLocalSession();
      if (mounted) {
        setState(() => _checkingSession = false);
      }
    }
  }

  String _hashAdminPassword(String password) {
    final normalized = _adminPasswordPepper.isEmpty
        ? password
        : '$password::$_adminPasswordPepper';
    return sha256.convert(utf8.encode(normalized)).toString();
  }

  bool _secureEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  String _normalizeWhatsapp(String value) {
    return value.replaceAll(RegExp(r'[^0-9+]'), '').trim();
  }

  Future<void> _migrateLegacyPasswordIfNeeded({
    required DocumentReference<Map<String, dynamic>> adminRef,
    required String storedHash,
    required String inputHash,
  }) async {
    if (storedHash.isNotEmpty) return;
    await adminRef.set({
      'password_hash': inputHash,
      'password': FieldValue.delete(),
      'password_migrated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // =========================================================
  // 🔐 تسجيل الدخول + حفظ الجلسة
  // =========================================================
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final username = _userCtrl.text.trim();
      final password = _passCtrl.text.trim();
      final whatsappInput = _normalizeWhatsapp(_whatsappCtrl.text);

      // 1️⃣ التحقق من بيانات الأدمن (بأقل استعلام لتجنب مشاكل الفهرسة)
      final snap = await FirebaseFirestore.instance
          .collection('admins')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        setState(() => _error = "بيانات الدخول غير صحيحة");
        return;
      }

      final doc = snap.docs.first;
      final data = doc.data();

      final storedHash = (data['password_hash'] ?? '').toString().trim();
      final storedPassword = (data['password'] ?? '').toString().trim();
      final inputHash = _hashAdminPassword(password);

      final bool passwordValid = storedHash.isNotEmpty
          ? _secureEquals(storedHash.toLowerCase(), inputHash.toLowerCase())
          : _secureEquals(storedPassword, password);

      final storedWhatsapp = _normalizeWhatsapp(
        (data['whatsapp'] ?? '').toString(),
      );

      if (!passwordValid ||
          (storedWhatsapp.isNotEmpty && storedWhatsapp != whatsappInput)) {
        setState(() => _error = "بيانات الدخول غير صحيحة");
        return;
      }

      // ترحيل فوري من password النصي إلى password_hash.
      await _migrateLegacyPasswordIfNeeded(
        adminRef: doc.reference,
        storedHash: storedHash,
        inputHash: inputHash,
      );

      // إذا كان الأدمن ليس لديه رقم واتساب مسجل، وادخل رقم جديد، نحفظه له
      if (storedWhatsapp.isEmpty && whatsappInput.isNotEmpty) {
        await doc.reference.update({'whatsapp': whatsappInput});
      }

      final String adminId = doc.id;

      // 2️⃣ تحديد الجهاز الحالي
      final String deviceId = await DeviceService.getDeviceId();

      // 3️⃣ حفظ FCM token في admins/{adminId}
      await NotificationService.saveUserToken(
        collection: 'admins',
        docId: adminId,
      );

      // 4️⃣ تحديد تاريخ انتهاء الجلسة (حسب اختيار الأدمن)
      final DateTime expiryDate = DateTime.now().add(Duration(days: _days));

      // 5️⃣ حفظ Session كـ Sub-collection في فايرستور
      await FirebaseFirestore.instance
          .collection('admins')
          .doc(adminId)
          .collection('sessions')
          .doc(deviceId)
          .set({
            'device_id': deviceId,
            'device_type': kIsWeb ? 'web' : 'android',
            'expiry_at': Timestamp.fromDate(expiryDate),
            'last_login': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // 6️⃣ حفظ بيانات الجلسة محلياً بتخزين آمن
      await AdminSessionService.saveLocalSession(
        adminId: adminId,
        username: username,
        whatsapp: whatsappInput,
        expiryAt: expiryDate,
      );

      // 7️⃣ تشغيل لستَنر الطلبات والأكواد (local notifications)
      NotificationService.listenToAdminOrders();
      NotificationService.listenToAdminRamadanCodes();
      await NotificationService.initAdminNotifications(
        whatsappInput,
        requestPermission: true,
      );

      // 8️⃣ الانتقال للوحة الأدمن
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/admin/orders');
      }
    } catch (e) {
      String message = "حدث خطأ أثناء تسجيل الدخول";
      if (e is FirebaseException) {
        switch (e.code) {
          case 'permission-denied':
            message = "لا توجد صلاحية للوصول إلى قاعدة البيانات";
            break;
          case 'failed-precondition':
            message = "يلزم إنشاء فهرس (Index) في Firestore";
            break;
          case 'unavailable':
            message = "تحقق من اتصال الإنترنت";
            break;
          case 'unauthenticated':
            message = "لم يتم التحقق من هوية الدخول";
            break;
        }
        if (kDebugMode && e.message != null) {
          message = "$message (${e.message})";
        }
      }
      setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // أثناء فحص الجلسة: نعرض شاشة لودينج بسيطة
    if (_checkingSession) {
      return Scaffold(
        body: Stack(
          children: [
            const SnowBackground(),
            Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: GlassAppBar(
        title: const Text('تسجيل دخول الأدمن'),
        actions: [
          IconButton(
            tooltip: 'تغيير الثيم',
            onPressed: _loading ? null : () => showThemeModeSheet(context),
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.wb_sunny_rounded
                  : Icons.nightlight_round,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          const SnowBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: GlassCard(
                    padding: const EdgeInsets.all(24),
                    margin: EdgeInsets.zero,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.admin_panel_settings,
                            size: 64,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            AppInfo.appName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'تسجيل دخول الأدمن',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'إدارة الطلبات والأسعار والإشعارات بنفس تجربة المستخدم لكن بصلاحيات أدمن كاملة.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontFamily: 'Cairo',
                              height: 1.4,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // اسم المستخدم
                          TextFormField(
                            controller: _userCtrl,
                            decoration: const InputDecoration(
                              labelText: 'اسم المستخدم',
                              prefixIcon: Icon(Icons.person),
                            ),
                            validator: (v) =>
                                v == null || v.isEmpty ? 'مطلوب' : null,
                          ),
                          const SizedBox(height: 12),

                          // كلمة المرور
                          TextFormField(
                            controller: _passCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'كلمة المرور',
                              prefixIcon: Icon(Icons.lock),
                            ),
                            validator: (v) => v == null || v.length < 4
                                ? 'كلمة المرور قصيرة'
                                : null,
                          ),
                          const SizedBox(height: 12),

                          // رقم الواتساب
                          TextFormField(
                            controller: _whatsappCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'رقم الواتساب',
                              prefixIcon: Icon(Icons.phone),
                            ),
                            validator: (v) => v == null || v.length < 8
                                ? 'رقم غير صحيح'
                                : null,
                          ),
                          const SizedBox(height: 14),

                          // مدة التذكر
                          DropdownButtonFormField<int>(
                            initialValue: _days,
                            decoration: const InputDecoration(
                              labelText: 'تذكرني لمدة',
                              prefixIcon: Icon(Icons.timer),
                            ),
                            items: _durations.entries
                                .map(
                                  (e) => DropdownMenuItem<int>(
                                    value: e.key,
                                    child: Text(e.value),
                                  ),
                                )
                                .toList(),
                            onChanged: _loading
                                ? null
                                : (v) => setState(() => _days = v ?? 1),
                          ),
                          const SizedBox(height: 16),

                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: colorScheme.error,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ),

                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _login,
                              child: _loading
                                  ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onPrimary,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Text(
                                          'جاري تسجيل الدخول...',
                                          style: TextStyle(fontFamily: 'Cairo'),
                                        ),
                                      ],
                                    )
                                  : const Text(
                                      'تسجيل الدخول',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Cairo',
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
