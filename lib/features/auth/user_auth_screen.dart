// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_login/flutter_login.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_info.dart';
import '../../core/app_navigator.dart';
import '../../core/tt_colors.dart';
import '../../services/notification_service.dart';
import '../../utils/html_meta.dart';
import '../../widgets/theme_mode_sheet.dart';

class _UserLookup {
  const _UserLookup(this.docId, this.data);

  final String docId;
  final Map<String, dynamic> data;

  String get email => (data['email'] ?? '').toString().trim().toLowerCase();
  String get whatsapp => (data['whatsapp'] ?? '').toString().trim();
  String get uid => (data['uid'] ?? '').toString().trim();
  String get passwordHash => (data['password_hash'] ?? '').toString();
}

class UserAuthScreen extends StatefulWidget {
  const UserAuthScreen({super.key});

  @override
  State<UserAuthScreen> createState() => _UserAuthScreenState();
}

class _UserAuthScreenState extends State<UserAuthScreen> {
  bool _checkingSession = true;

  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      setPageTitle(AppInfo.appName);
      setMetaDescription(
        'إنشاء حساب أو تسجيل الدخول إلى ${AppInfo.appName}. منصة موثوقة لشحن خدمات تيك توك والألعاب ومتابعة الطلبات بسهولة.',
      );
    }

    _checkExistingSession();
  }

  String _normalizeWhatsapp(String input) {
    return input.replaceAll(RegExp(r'[^0-9+]'), '').trim();
  }

  String _normalizeDisplayName(String input) {
    return input.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _normalizeTiktokHandle(String input) {
    var out = input.trim();
    if (out.isEmpty) return '';
    if (out.startsWith('http://') || out.startsWith('https://')) {
      final uri = Uri.tryParse(out);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        out = uri.pathSegments.last;
      }
    }
    out = out.replaceFirst(RegExp(r'^@+'), '');
    out = out.replaceAll(RegExp(r'[^a-zA-Z0-9._]'), '');
    return out.trim();
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  bool _isValidEmail(String input) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(input);
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'الحساب غير موجود';
      case 'wrong-password':
        return 'كلمة السر غير صحيحة';
      case 'invalid-email':
        return 'بريد غير صالح';
      case 'operation-not-allowed':
        return 'تم تعطيل تسجيل الدخول بالبريد من لوحة Firebase';
      case 'unauthorized-domain':
        return 'النطاق غير مصرح به في Firebase Auth';
      case 'too-many-requests':
        return 'عدد محاولات كبير، حاول لاحقًا';
      default:
        return 'حدث خطأ أثناء تسجيل الدخول';
    }
  }

  String _deriveDisplayName({
    required String email,
    required String whatsapp,
    String? fallback,
  }) {
    final preferred = (fallback ?? '').trim();
    if (preferred.length >= 3) return preferred;

    final localPart = email.split('@').first.trim();
    final sanitizedLocalPart = localPart.replaceAll(
      RegExp(r'[^a-zA-Z0-9_\-.\u0600-\u06FF]'),
      '',
    );
    if (sanitizedLocalPart.length >= 3) {
      return sanitizedLocalPart;
    }

    final digits = whatsapp.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 4) {
      return 'user_${digits.substring(digits.length - 4)}';
    }
    return 'مستخدم';
  }

  Future<void> _checkExistingSession() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name') ?? '';
    final whatsapp = prefs.getString('user_whatsapp') ?? '';
    final tiktok = prefs.getString('user_tiktok') ?? '';

    if (name.isNotEmpty && whatsapp.isNotEmpty && mounted) {
      AppNavigator.pushReplacementNamed(
        context,
        '/home',
        arguments: {'name': name, 'whatsapp': whatsapp, 'tiktok': tiktok},
      );
      return;
    }

    if (mounted) {
      setState(() => _checkingSession = false);
    }
  }

  Future<void> _saveUserPrefs(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = (data['username'] ?? '').toString().trim();
    final savedTiktok = (data['tiktok'] ?? savedUsername).toString().trim();
    final normalizedHandle = _normalizeTiktokHandle(
      savedTiktok.isNotEmpty ? savedTiktok : savedUsername,
    );
    await prefs.setBool('is_admin', false);
    await prefs.setString('user_uid', (data['uid'] ?? '').toString());
    await prefs.setString('user_name', (data['name'] ?? '').toString());
    await prefs.setString('user_email', (data['email'] ?? '').toString());
    await prefs.setString('user_username', normalizedHandle);
    await prefs.setString('user_tiktok', normalizedHandle);
    await prefs.setString(
      'user_whatsapp',
      _normalizeWhatsapp((data['whatsapp'] ?? '').toString()),
    );
  }

  Future<_UserLookup?> _findByField(String field, String value) async {
    if (value.trim().isEmpty) return null;
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where(field, isEqualTo: value)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return _UserLookup(snap.docs.first.id, snap.docs.first.data());
  }

  Future<_UserLookup?> _getUserByUidOrEmail({
    String? uid,
    String? email,
  }) async {
    final users = FirebaseFirestore.instance.collection('users');

    if (uid != null && uid.trim().isNotEmpty) {
      final snap = await users
          .where('uid', isEqualTo: uid.trim())
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        final doc = snap.docs.first;
        return _UserLookup(doc.id, doc.data());
      }
    }

    if (email != null && email.trim().isNotEmpty) {
      return _findByField('email', email.trim().toLowerCase());
    }

    return null;
  }

  Future<void> _persistAndNavigate(Map<String, dynamic> data) async {
    data = Map<String, dynamic>.from(data);
    if (!data.containsKey('uid')) {
      data['uid'] = FirebaseAuth.instance.currentUser?.uid ?? '';
    }
    final normalizedHandle = _normalizeTiktokHandle(
      (data['tiktok'] ?? data['username'] ?? '').toString(),
    );
    data['username'] = normalizedHandle.isNotEmpty
        ? normalizedHandle
        : (data['username'] ?? '');
    data['tiktok'] = normalizedHandle.isNotEmpty
        ? normalizedHandle
        : (data['tiktok'] ?? data['username'] ?? '');
    data['name'] = _normalizeDisplayName((data['name'] ?? '').toString());
    await _saveUserPrefs(data);

    final whatsapp = _normalizeWhatsapp((data['whatsapp'] ?? '').toString());
    if (whatsapp.isNotEmpty) {
      await NotificationService.initUserNotifications(
        whatsapp,
        requestPermission: true,
      );
    }

    if (!mounted) return;
    AppNavigator.pushReplacementNamed(context, '/home');
  }

  Future<String?> _handleAuthSuccess(
    User? user, {
    String? fallbackEmail,
  }) async {
    if (user == null) return 'فشل تسجيل الدخول';

    final email = (user.email ?? fallbackEmail ?? '').toLowerCase();
    final users = FirebaseFirestore.instance.collection('users');
    final existing = await _getUserByUidOrEmail(uid: user.uid, email: email);

    if (existing != null) {
      final normalizedHandle = _normalizeTiktokHandle(
        (existing.data['tiktok'] ?? existing.data['username'] ?? '').toString(),
      );
      final normalizedName = _normalizeDisplayName(
        (existing.data['name'] ?? '').toString(),
      );

      final updates = <String, dynamic>{};

      if (existing.uid.isEmpty && user.uid.isNotEmpty) {
        updates['uid'] = user.uid;
      }
      if (normalizedHandle.isNotEmpty &&
          (existing.data['tiktok'] ?? '') != normalizedHandle) {
        updates['tiktok'] = normalizedHandle;
      }
      if (normalizedHandle.isNotEmpty &&
          (existing.data['username'] ?? '') != normalizedHandle) {
        updates['username'] = normalizedHandle;
      }
      if (normalizedName.isNotEmpty &&
          (existing.data['name'] ?? '') != normalizedName) {
        updates['name'] = normalizedName;
      }

      if (updates.isNotEmpty) {
        updates['updated_at'] = FieldValue.serverTimestamp();
        await users.doc(existing.docId).set(updates, SetOptions(merge: true));
      }

      final mergedData = {...existing.data, ...updates};
      await _persistAndNavigate(mergedData);
      return null;
    }

    final minimal = {
      'name': user.displayName ?? '',
      'email': email,
      'username': '',
      'whatsapp': '',
      'uid': user.uid,
    };
    await users.doc(user.uid).set({
      ...minimal,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _persistAndNavigate(minimal);
    return null;
  }

  Future<bool> _migrateLegacyUser(String email, String password) async {
    final legacy = await _findByField('email', email.toLowerCase());
    if (legacy == null) return false;

    final hash = legacy.passwordHash;
    final plain = (legacy.data['password'] ?? '').toString();
    final hashMatches = hash.isNotEmpty && hash == _hashPassword(password);
    final plainMatches = plain.isNotEmpty && plain == password;

    if (!hashMatches && !plainMatches) {
      return false;
    }

    try {
      final authCred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      final uid = authCred.user?.uid ?? '';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(legacy.docId)
          .set({
            'uid': uid,
            'email': email.toLowerCase(),
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      final mergedData = Map<String, dynamic>.from(legacy.data);
      mergedData['uid'] = uid;
      await _persistAndNavigate(mergedData);
      return true;
    } on FirebaseAuthException {
      return false;
    }
  }

  String _temporaryRecoveryPassword() {
    const letters =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    final buffer = StringBuffer('Tmp@');
    for (var i = 0; i < 14; i++) {
      buffer.write(letters[random.nextInt(letters.length)]);
    }
    buffer.write('9!');
    return buffer.toString();
  }

  Future<bool> _bootstrapLegacyAuthForRecovery(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    final legacy = await _findByField('email', normalizedEmail);
    if (legacy == null) return false;

    UserCredential? credential;
    try {
      credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: _temporaryRecoveryPassword(),
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        // حساب التوثيق موجود بالفعل، يكفي إرسال رابط إعادة التعيين.
        return true;
      }
      rethrow;
    }

    final uid = credential.user?.uid ?? '';
    if (uid.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(legacy.docId)
          .set({
            'uid': uid,
            'email': normalizedEmail,
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    }

    await FirebaseAuth.instance.signOut();
    return true;
  }

  Future<String?> _login(LoginData data) async {
    final identifier = data.name.trim();
    final password = data.password;

    if (!_isValidEmail(identifier)) {
      return 'أدخل بريدًا إلكترونيًا صحيحًا';
    }

    try {
      final email = identifier.toLowerCase();
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return _handleAuthSuccess(credential.user, fallbackEmail: email);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        final migrated = await _migrateLegacyUser(identifier, password);
        if (migrated) return null;
        return 'بيانات الدخول غير صحيحة';
      }
      if (e.code == 'wrong-password') {
        return 'بيانات الدخول غير صحيحة';
      }
      return _mapAuthError(e);
    } catch (_) {
      return 'حدث خطأ أثناء تسجيل الدخول';
    }
  }

  Future<String?> _register(SignupData data) async {
    final email = (data.name ?? '').trim().toLowerCase();
    final password = data.password ?? '';
    final additional = data.additionalSignupData ?? const <String, String>{};
    final inputDisplayName = _normalizeDisplayName(
      (additional['display_name'] ?? '').toString(),
    );
    final inputTiktok = _normalizeTiktokHandle(
      (additional['tiktok_username'] ?? '').toString(),
    );
    final whatsapp = _normalizeWhatsapp(additional['whatsapp'] ?? '');
    final passwordHash = _hashPassword(password);

    if (!_isValidEmail(email)) return 'بريد إلكتروني غير صحيح';
    if (inputDisplayName.length < 3) return 'الاسم قصير جدا';
    if (inputTiktok.isEmpty) return 'يوزر تيك توك مطلوب';
    if (whatsapp.isEmpty) return 'رقم الواتساب مطلوب';
    if (password.length < 6) return 'كلمة السر لا تقل عن 6 أحرف';

    try {
      final users = FirebaseFirestore.instance.collection('users');

      final emailDoc = await _findByField('email', email);
      final whatsappDoc = await _findByField('whatsapp', whatsapp);

      if (whatsappDoc != null &&
          (emailDoc == null || whatsappDoc.docId != emailDoc.docId)) {
        if (whatsappDoc.uid.isNotEmpty) {
          return 'هذا الحساب مسجل بالفعل';
        }
        return 'رقم الواتساب مستخدم بالفعل';
      }

      if (emailDoc != null) {
        if (emailDoc.uid.isNotEmpty) {
          return 'البريد الإلكتروني مستخدم بالفعل';
        }
        if (emailDoc.whatsapp.isNotEmpty && emailDoc.whatsapp != whatsapp) {
          return 'البريد مرتبط برقم واتساب آخر';
        }
      }

      final name = inputDisplayName;
      final username = inputTiktok;

      final authCred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final uid = authCred.user?.uid ?? '';

      Future<void> persistInDoc({
        required String docId,
        required dynamic createdAt,
      }) async {
        await users.doc(docId).set({
          'name': name,
          'email': email,
          'whatsapp': whatsapp,
          'username': username,
          'tiktok': username,
          'uid': uid,
          'password': password,
          'password_hash': passwordHash,
          'created_at': createdAt ?? FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (emailDoc != null) {
        await persistInDoc(
          docId: emailDoc.docId,
          createdAt: emailDoc.data['created_at'],
        );
        await _persistAndNavigate({
          'name': name,
          'email': email,
          'whatsapp': whatsapp,
          'username': username,
          'tiktok': username,
          'uid': uid,
        });
        return null;
      }

      if (whatsappDoc != null && whatsappDoc.uid.isEmpty) {
        if (whatsappDoc.email.isNotEmpty && whatsappDoc.email != email) {
          return 'رقم الواتساب مرتبط ببريد آخر';
        }

        await persistInDoc(
          docId: whatsappDoc.docId,
          createdAt: whatsappDoc.data['created_at'],
        );
        await _persistAndNavigate({
          'name': name,
          'email': email,
          'whatsapp': whatsapp,
          'username': username,
          'tiktok': username,
          'uid': uid,
        });
        return null;
      }

      final docId =
          emailDoc?.docId ??
          whatsappDoc?.docId ??
          (uid.isNotEmpty ? uid : whatsapp);

      await persistInDoc(docId: docId, createdAt: null);
      await _persistAndNavigate({
        'name': name,
        'email': email,
        'whatsapp': whatsapp,
        'username': username,
        'tiktok': username,
        'uid': uid,
      });
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        return 'البريد الإلكتروني مستخدم بالفعل';
      }
      if (e.code == 'weak-password') {
        return 'كلمة السر ضعيفة';
      }
      return _mapAuthError(e);
    } catch (_) {
      return 'حدث خطأ أثناء إنشاء الحساب';
    }
  }

  Future<String?> _recoverPassword(String emailInput) async {
    final email = emailInput.trim().toLowerCase();
    if (!_isValidEmail(email)) {
      return "أدخل بريدًا إلكترونيًا صحيحًا";
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        try {
          final restored = await _bootstrapLegacyAuthForRecovery(email);
          if (!restored) {
            return "لم يتم العثور على الحساب";
          }
          await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
          return null;
        } on FirebaseAuthException catch (legacyError) {
          if (legacyError.code == 'operation-not-allowed') {
            return "تم تعطيل إعادة التعيين عبر البريد من Firebase";
          }
          return "تعذّر تجهيز حسابك القديم، حاول لاحقًا";
        } catch (_) {
          return "تعذّر تجهيز حسابك القديم، حاول لاحقًا";
        }
      }
      return "تعذّر إرسال رابط التعيين، حاول لاحقًا";
    } catch (_) {
      return "تعذّر إرسال رابط التعيين، حاول لاحقًا";
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

  LoginMessages _buildLoginMessages() {
    return LoginMessages(
      userHint: 'البريد الإلكتروني',
      passwordHint: 'كلمة السر',
      confirmPasswordHint: 'تأكيد كلمة السر',
      loginButton: 'دخول',
      signupButton: 'إنشاء حساب',
      forgotPasswordButton: 'نسيت كلمة السر؟',
      recoverPasswordButton: 'إرسال رابط التعيين',
      recoverPasswordIntro: 'إعادة تعيين كلمة السر',
      recoverPasswordDescription:
          'اكتب بريدك الإلكتروني لإرسال رابط إعادة التعيين.',
      goBackButton: 'رجوع',
      confirmPasswordError: 'كلمتا السر غير متطابقتين',
      recoverPasswordSuccess: 'تم إرسال رابط إعادة التعيين',
      flushbarTitleError: 'خطأ',
      flushbarTitleSuccess: 'نجاح',
      signUpSuccess: 'تم إنشاء الحساب بنجاح',
      providersTitleFirst: '',
      providersTitleSecond: '',
      additionalSignUpFormDescription:
          'أدخل الاسم ويوزر تيك توك ورقم الواتساب لإكمال إنشاء الحساب',
      additionalSignUpSubmitButton: 'تأكيد البيانات',
    );
  }

  String? _emailValidator(String? input) {
    final value = (input ?? '').trim();
    if (!_isValidEmail(value)) return 'أدخل بريدًا إلكترونيًا صحيحًا';
    return null;
  }

  String? _passwordValidator(String? input) {
    final value = input ?? '';
    if (value.length < 6) return 'كلمة السر لا تقل عن 6 أحرف';
    return null;
  }

  List<UserFormField> _buildSignupFields() {
    return const [
      UserFormField(
        keyName: 'display_name',
        displayName: 'الاسم بالكامل',
        userType: LoginUserType.name,
        fieldValidator: _validateSignupName,
      ),
      UserFormField(
        keyName: 'tiktok_username',
        displayName: 'يوزر تيك توك',
        userType: LoginUserType.name,
        fieldValidator: _validateSignupTiktok,
      ),
      UserFormField(
        keyName: 'whatsapp',
        displayName: 'رقم الواتساب',
        userType: LoginUserType.phone,
        fieldValidator: _validateSignupWhatsapp,
      ),
    ];
  }

  static String? _validateSignupName(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.length < 3) return 'الاسم قصير جدا';
    return null;
  }

  static String? _validateSignupTiktok(String? value) {
    final normalized = value?.trim().replaceFirst(RegExp(r'^@+'), '') ?? '';
    if (normalized.isEmpty) return 'يوزر تيك توك مطلوب';
    return null;
  }

  static String? _validateSignupWhatsapp(String? value) {
    final normalized = (value ?? '').replaceAll(RegExp(r'[^0-9+]'), '').trim();
    if (normalized.isEmpty) return 'رقم الواتساب مطلوب';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSession) {
      return Scaffold(
        backgroundColor: TTColors.cardBg,
        body: const Center(
          child: CircularProgressIndicator(color: TTColors.primaryCyan),
        ),
      );
    }

    final brightness = Theme.of(context).brightness;

    return FlutterLogin(
      title: AppInfo.appName,
      userType: LoginUserType.email,
      onLogin: _login,
      onSignup: _register,
      onRecoverPassword: _recoverPassword,
      userValidator: _emailValidator,
      passwordValidator: _passwordValidator,
      theme: _buildLoginTheme(brightness),
      messages: _buildLoginMessages(),
      additionalSignupFields: _buildSignupFields(),
      hideProvidersTitle: true,
      scrollable: true,
      children: [
        PositionedDirectional(
          top: MediaQuery.paddingOf(context).top + 10,
          end: 10,
          child: Material(
            color: Colors.transparent,
            child: IconButton(
              tooltip: 'تغيير الثيم',
              onPressed: () => showThemeModeSheet(context),
              icon: Icon(
                Theme.of(context).brightness == Brightness.dark
                    ? Icons.nightlight_round
                    : Icons.wb_sunny_rounded,
                color: TTColors.textWhite,
              ),
            ),
          ),
        ),
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
