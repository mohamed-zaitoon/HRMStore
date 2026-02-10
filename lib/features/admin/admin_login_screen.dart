// Open-source code. Copyright Mohamed Zaitoon 2025-2026.
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/device_service.dart';
import '../../services/notification_service.dart';
import '../../services/onesignal_service.dart';
import '../../core/tt_colors.dart';
import '../../core/app_info.dart';
import '../../widgets/snow_background.dart';
import '../../widgets/glass_card.dart';
import '../../utils/html_meta.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _userCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  final TextEditingController _whatsappCtrl = TextEditingController();

  bool _loading = false;
  bool _checkingSession = true; // 👈 بنستخدمه علشان نعرض لودينج أول ما الأكتيفيتي تفتح
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
        'لوحة تحكم الأدمن لإدارة طلبات شحن نقاط تيك توك، مراجعة إيصالات الدفع، واعتماد أكواد رمضان.',
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
    final prefs = await SharedPreferences.getInstance();

    final String? adminId = prefs.getString('admin_id');
    final String? expiryStr = prefs.getString('admin_expiry');

    // لو مفيش بيانات محفوظة -> نعرض فورم اللوجين عادي
    if (adminId == null || expiryStr == null) {
      setState(() => _checkingSession = false);
      return;
    }

    final DateTime? expiryDate = DateTime.tryParse(expiryStr);

    // لو التاريخ مش مفهوم أو منتهي -> نمسح الداتا ونرجّع للفورم
    if (expiryDate == null || DateTime.now().isAfter(expiryDate)) {
      await prefs.remove('admin_id');
      await prefs.remove('admin_expiry');
      await prefs.remove('admin_username');
      await prefs.remove('admin_whatsapp');

      setState(() => _checkingSession = false);
      return;
    }

    // ✅ في حالة جلسة صالحة: نشغّل لستَنر الإشعارات ونخش على لوحة الأدمن
    NotificationService.listenToAdminOrders();
    NotificationService.listenToAdminRamadanCodes();
    final savedWhatsapp = prefs.getString('admin_whatsapp') ?? '';
    if (savedWhatsapp.isNotEmpty) {
      await OneSignalService.registerUser(
        whatsapp: savedWhatsapp,
        isAdmin: true,
        requestPermission: true,
      );
    }

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/admin/orders');
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
      final whatsappInput =
          _whatsappCtrl.text.replaceAll(RegExp(r'[^0-9+]'), '').trim();

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

      final storedPassword = (data['password'] ?? '').toString().trim();
      final storedWhatsapp = (data['whatsapp'] ?? '')
          .toString()
          .replaceAll(RegExp(r'[^0-9+]'), '')
          .trim();

      if (storedPassword != password) {
        setState(() => _error = "بيانات الدخول غير صحيحة");
        return;
      }

      if (storedWhatsapp.isNotEmpty && storedWhatsapp != whatsappInput) {
        setState(() => _error = "بيانات الدخول غير صحيحة");
        return;
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
      final DateTime expiryDate =
      DateTime.now().add(Duration(days: _days));

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

      // 6️⃣ حفظ بيانات الجلسة محلياً في SharedPreferences
      final savedWhatsapp =
          whatsappInput.isNotEmpty ? whatsappInput : storedWhatsapp;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('admin_id', adminId);
      await prefs.setString('admin_username', username);
      await prefs.setString('admin_whatsapp', savedWhatsapp);
      await prefs.setString('admin_expiry', expiryDate.toIso8601String());

      // 7️⃣ تشغيل لستَنر الطلبات والأكواد (local notifications)
      NotificationService.listenToAdminOrders();
      NotificationService.listenToAdminRamadanCodes();
      await OneSignalService.registerUser(
        whatsapp: savedWhatsapp,
        isAdmin: true,
        requestPermission: true,
      );
      await OneSignalService.requestPermission();

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
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: TTColors.goldAccent),
        ),
      );
    }

    return Scaffold(
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
                    tint: TTColors.cardBg.withValues(alpha: 0.9),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.admin_panel_settings,
                            size: 64,
                            color: TTColors.goldAccent,
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
                              color: TTColors.textGray,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'إدارة الطلبات والأسعار والإشعارات بنفس تجربة المستخدم لكن بصلاحيات أدمن كاملة.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: TTColors.textGray,
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
                            validator: (v) =>
                                v == null || v.length < 4
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
                            validator: (v) =>
                                v == null || v.length < 8
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
                            dropdownColor: TTColors.cardBg,
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
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ),

                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: TTColors.goldAccent,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Colors.black,
                                      ),
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
