// Open-source code. Copyright Mohamed Zaitoon 2025-2026.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:crypto/crypto.dart';

import '../../services/device_service.dart';
import '../../services/admin_session_service.dart';
import '../../core/app_info.dart';
import '../../core/app_navigator.dart';
import '../../widgets/glass_app_bar.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/snow_background.dart';
import '../../widgets/theme_mode_sheet.dart';
import '../../utils/html_meta.dart';
import '../../utils/whatsapp_utils.dart';

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
  bool _isRegisterMode = false;

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
        'لوحة تحكم الأدمن لإدارة المستخدمين والتجار والأسعار والأكواد والدعم.',
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

      if (!mounted) return;
      AppNavigator.pushReplacementNamed(context, '/admin/users');
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
    return WhatsappUtils.normalizeEgyptianWhatsapp(value);
  }

  Future<void> _persistSessionAndLogin({
    required String adminId,
    required String username,
    required String whatsappInput,
  }) async {
    final String deviceId = await DeviceService.getDeviceId();

    final DateTime expiryDate = DateTime.now().add(Duration(days: _days));

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

    await AdminSessionService.saveLocalSession(
      adminId: adminId,
      username: username,
      whatsapp: whatsappInput,
      expiryAt: expiryDate,
    );

    if (mounted) {
      AppNavigator.pushReplacementNamed(context, '/admin/users');
    }
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

      final bool passwordValid = storedPassword.isNotEmpty
          ? _secureEquals(storedPassword, password)
          : storedHash.isNotEmpty
          ? _secureEquals(storedHash.toLowerCase(), inputHash.toLowerCase())
          : false;

      final storedWhatsapp = _normalizeWhatsapp(
        (data['whatsapp'] ?? '').toString(),
      );

      if (!passwordValid ||
          (storedWhatsapp.isNotEmpty && storedWhatsapp != whatsappInput)) {
        setState(() => _error = "بيانات الدخول غير صحيحة");
        return;
      }

      // ترحيل فوري لاستخدام كلمة السر النصية فقط دون تشفير.
      await doc.reference.set({
        'password': password,
        'password_hash': null,
        'password_migrated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // إذا كان الأدمن ليس لديه رقم واتساب مسجل، وادخل رقم جديد، نحفظه له
      if (storedWhatsapp.isEmpty && whatsappInput.isNotEmpty) {
        await doc.reference.update({'whatsapp': whatsappInput});
      }

      final String adminId = doc.id;

      await _persistSessionAndLogin(
        adminId: adminId,
        username: username,
        whatsappInput: whatsappInput,
      );
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

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final username = _userCtrl.text.trim();
      final password = _passCtrl.text.trim();
      final whatsappInput = _normalizeWhatsapp(_whatsappCtrl.text);

      final exists = await FirebaseFirestore.instance
          .collection('admins')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();
      if (exists.docs.isNotEmpty) {
        setState(() => _error = "اسم المستخدم مستخدم بالفعل");
        return;
      }

      final adminRef = await FirebaseFirestore.instance
          .collection('admins')
          .add({
            'username': username,
            'whatsapp': whatsappInput,
            'password': password,
            'password_hash': null,
            'role': 'admin',
            'created_at': FieldValue.serverTimestamp(),
          });

      await _persistSessionAndLogin(
        adminId: adminRef.id,
        username: username,
        whatsappInput: whatsappInput,
      );
    } catch (e) {
      String message = "تعذر إنشاء حساب الأدمن";
      if (e is FirebaseException && e.message != null) {
        message = "$message (${e.message})";
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
                  ? Icons.nightlight_round
                  : Icons.wb_sunny_rounded,
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
                            _isRegisterMode
                                ? 'إنشاء حساب أدمن جديد'
                                : 'تسجيل دخول الأدمن',
                            key: ValueKey(_isRegisterMode),
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _isRegisterMode
                                ? 'أنشئ حساب أدمن جديد ثم سيتسجل الدخول تلقائياً.'
                                : 'إدارة المستخدمين والتجار والأسعار والأكواد والدعم بصلاحيات أدمن كاملة.',
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
                            validator:
                                WhatsappUtils.validateRequiredEgyptianWhatsapp,
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
                              onPressed: _loading
                                  ? null
                                  : (_isRegisterMode ? _register : _login),
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
                                        Text(
                                          _isRegisterMode
                                              ? 'جاري إنشاء الحساب...'
                                              : 'جاري تسجيل الدخول...',
                                          style: const TextStyle(
                                            fontFamily: 'Cairo',
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      _isRegisterMode
                                          ? 'إنشاء حساب أدمن'
                                          : 'تسجيل الدخول',
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Cairo',
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () {
                                    setState(() {
                                      _isRegisterMode = !_isRegisterMode;
                                      _error = null;
                                    });
                                  },
                            child: Text(
                              _isRegisterMode
                                  ? 'لديك حساب؟ تسجيل الدخول'
                                  : 'إنشاء حساب أدمن جديد',
                              style: const TextStyle(fontFamily: 'Cairo'),
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
