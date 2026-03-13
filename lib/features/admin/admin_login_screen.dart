// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_login/flutter_login.dart';

import '../../core/app_info.dart';
import '../../core/app_navigator.dart';
import '../../core/tt_colors.dart';
import '../../services/admin_session_service.dart';
import '../../services/device_service.dart';
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

  bool _checkingSession = true;
  int _rememberDays = 7;

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    try {
      final session = await AdminSessionService.getLocalSession();
      final valid = await AdminSessionService.validateCurrentSession();
      if (valid && session != null && mounted) {
        AppNavigator.pushReplacementNamed(context, '/admin/users');
        return;
      }
      await AdminSessionService.clearLocalSession();
    } catch (_) {}
    if (mounted) setState(() => _checkingSession = false);
  }

  String _normalizeWhatsapp(String value) {
    return WhatsappUtils.normalizeEgyptianWhatsapp(value);
  }

  bool _isValidEmail(String input) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(input.trim());
  }

  String _hashPassword(String password) {
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

  Future<void> _persistSession({
    required String adminId,
    required String email,
    required String whatsapp,
  }) async {
    final deviceId = await DeviceService.getDeviceId();
    final expiryDate = DateTime.now().add(Duration(days: _rememberDays));

    await FirebaseFirestore.instance
        .collection('admins')
        .doc(adminId)
        .collection('sessions')
        .doc(deviceId)
        .set({
          'device_id': deviceId,
          'device_type': 'windows',
          'expiry_at': Timestamp.fromDate(expiryDate),
          'last_login': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    await AdminSessionService.saveLocalSession(
      adminId: adminId,
      username: email,
      whatsapp: whatsapp,
      expiryAt: expiryDate,
    );
  }

  Future<String?> _loginAdmin(String email, String password) async {
    try {
      final admins = FirebaseFirestore.instance.collection('admins');
      QuerySnapshot<Map<String, dynamic>> snap = await admins
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) {
        snap = await admins.where('username', isEqualTo: email).limit(1).get();
      }
      if (snap.docs.isEmpty) {
        return 'حساب الأدمن غير موجود';
      }

      final doc = snap.docs.first;
      final data = doc.data();
      final storedHash = (data['password_hash'] ?? '').toString().trim();
      final storedPassword = (data['password'] ?? '').toString().trim();
      final inputHash = _hashPassword(password);
      final passwordValid = storedPassword.isNotEmpty
          ? _secureEquals(storedPassword, password)
          : storedHash.isNotEmpty
          ? _secureEquals(storedHash.toLowerCase(), inputHash.toLowerCase())
          : false;
      if (!passwordValid) return 'بيانات الدخول غير صحيحة';

      final storedWhatsapp = _normalizeWhatsapp(
        (data['whatsapp'] ?? '').toString(),
      );

      await _persistSession(
        adminId: doc.id,
        email: email,
        whatsapp: storedWhatsapp,
      );

      if (!mounted) return null;
      AppNavigator.pushReplacementNamed(context, '/admin/users');
      return null;
    } catch (e) {
      return 'حدث خطأ أثناء تسجيل الدخول';
    }
  }

  Future<String?> _registerAdmin(
    String email,
    String password,
    String whatsapp,
  ) async {
    try {
      final admins = FirebaseFirestore.instance.collection('admins');
      final exists = await admins
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (exists.docs.isNotEmpty) {
        return 'الحساب موجود بالفعل';
      }

      final adminRef = await admins.add({
        'email': email,
        'username': email,
        'whatsapp': whatsapp,
        'password': password,
        'password_hash': null,
        'role': 'admin',
        'created_at': FieldValue.serverTimestamp(),
      });

      await _persistSession(
        adminId: adminRef.id,
        email: email,
        whatsapp: whatsapp,
      );

      if (!mounted) return null;
      AppNavigator.pushReplacementNamed(context, '/admin/users');
      return null;
    } catch (e) {
      return 'تعذر إنشاء حساب الأدمن';
    }
  }

  LoginTheme _buildLoginTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return LoginTheme(
      pageColorLight: TTColors.backgroundFor(brightness),
      pageColorDark: TTColors.backgroundFor(brightness),
      primaryColor: TTColors.cardBgFor(brightness),
      accentColor: TTColors.primaryCyan,
      errorColor: const Color(0xFFDC2626),
      cardTheme: CardTheme(
        color: TTColors.cardBgFor(brightness),
        elevation: isDark ? 8 : 4,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      inputTheme: InputDecorationTheme(
        filled: true,
        fillColor: TTColors.cardBgFor(brightness),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      titleStyle: TextStyle(
        fontFamily: 'Cairo',
        fontWeight: FontWeight.w700,
        fontSize: 32,
        color: TTColors.textFor(brightness),
      ),
      textFieldStyle: TextStyle(
        fontFamily: 'Cairo',
        color: TTColors.textFor(brightness),
      ),
      bodyStyle: TextStyle(
        fontFamily: 'Cairo',
        color: TTColors.textMutedFor(brightness),
      ),
      buttonStyle: TextStyle(
        fontFamily: 'Cairo',
        fontWeight: FontWeight.w700,
        color: TTColors.textWhite,
      ),
      switchAuthTextColor: TTColors.textFor(brightness),
      authButtonPadding: const EdgeInsets.symmetric(
        horizontal: 30,
        vertical: 10,
      ),
      buttonTheme: LoginButtonTheme(
        backgroundColor: TTColors.primaryCyan,
        iconColor: TTColors.textWhite,
        splashColor: TTColors.primaryCyan.withValues(alpha: 0.25),
        highlightColor: TTColors.primaryCyan.withValues(alpha: 0.15),
        elevation: isDark ? 6 : 4,
        highlightElevation: isDark ? 3 : 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  LoginMessages _buildMessages() {
    return LoginMessages(
      userHint: 'البريد الإلكتروني',
      passwordHint: 'كلمة السر',
      confirmPasswordHint: 'تأكيد كلمة السر',
      loginButton: 'دخول الأدمن',
      signupButton: 'إنشاء حساب أدمن',
      forgotPasswordButton: 'نسيت كلمة السر؟',
      recoverPasswordButton: 'إرسال رابط الاستعادة',
      recoverPasswordIntro: 'إعادة تعيين كلمة السر',
      recoverPasswordDescription: 'اكتب بريدك لإرسال رابط الاستعادة.',
      goBackButton: 'رجوع',
      confirmPasswordError: 'كلمتا السر غير متطابقتين',
      recoverPasswordSuccess: 'تم إرسال رابط الاستعادة',
      flushbarTitleError: 'خطأ',
      flushbarTitleSuccess: 'نجاح',
      signUpSuccess: 'تم إنشاء حساب الأدمن بنجاح',
      additionalSignUpFormDescription: 'أدخل الواتساب لتفعيل التنبيهات.',
      additionalSignUpSubmitButton: 'تأكيد البيانات',
    );
  }

  String? _emailValidator(String? value) {
    final v = (value ?? '').trim();
    if (!_isValidEmail(v)) return 'أدخل بريد إلكتروني صحيح';
    return null;
  }

  String? _passwordValidator(String? value) {
    final v = value ?? '';
    if (v.length < 4) return 'كلمة السر قصيرة';
    return null;
  }

  List<UserFormField> _signupFields() {
    return const [
      UserFormField(
        keyName: 'whatsapp',
        displayName: 'رقم الواتساب',
        userType: LoginUserType.phone,
        fieldValidator: WhatsappUtils.validateRequiredEgyptianWhatsapp,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSession) {
      return Scaffold(
        backgroundColor: TTColors.backgroundFor(Theme.of(context).brightness),
        body: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
        ),
      );
    }

    final brightness = Theme.of(context).brightness;

    return FlutterLogin(
      title: AppInfo.appName,
      userType: LoginUserType.email,
      onLogin: (data) =>
          _loginAdmin(data.name.trim().toLowerCase(), data.password),
      onSignup: (data) => _registerAdmin(
        (data.name ?? '').trim().toLowerCase(),
        data.password ?? '',
        _normalizeWhatsapp(data.additionalSignupData?['whatsapp'] ?? ''),
      ),
      onRecoverPassword: (email) async {
        return 'استرجاع كلمة السر غير مفعّل للأدمن حالياً';
      },
      userValidator: _emailValidator,
      passwordValidator: _passwordValidator,
      theme: _buildLoginTheme(brightness),
      messages: _buildMessages(),
      additionalSignupFields: _signupFields(),
      hideProvidersTitle: true,
      scrollable: true,
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 8,
          child: Center(
            child: TextButton(
              onPressed: () => AppNavigator.pushNamed(context, '/privacy'),
              child: const Text('سياسة الخصوصية'),
            ),
          ),
        ),
      ],
    );
  }
}
