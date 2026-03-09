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
import '../../utils/whatsapp_utils.dart';
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
    return WhatsappUtils.normalizeEgyptianWhatsapp(input);
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

  Future<void> _checkExistingSession() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name') ?? '';
    final whatsapp = prefs.getString('user_whatsapp') ?? '';
    final tiktok = prefs.getString('user_tiktok') ?? '';
    final uid = (prefs.getString('user_uid') ?? '').trim();
    final email = (prefs.getString('user_email') ?? '').trim().toLowerCase();
    var isMerchant = prefs.getBool('is_merchant') ?? false;

    if (isMerchant) {
      final existing = await _getUserByUidOrEmail(uid: uid, email: email);
      final status = (existing?.data['merchant_verification_status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final verified =
          existing?.data['merchant_verified'] == true || status == 'approved';
      if (!verified) {
        isMerchant = false;
        await prefs.setBool('is_merchant', false);
      }
    }
    AppInfo.isMerchantApp = isMerchant;

    if (name.isNotEmpty && whatsapp.isNotEmpty && mounted) {
      final route = isMerchant ? '/merchant/orders' : '/home';
      AppNavigator.pushReplacementNamed(
        context,
        route,
        arguments: {'name': name, 'whatsapp': whatsapp, 'tiktok': tiktok},
      );
      return;
    }

    if (mounted) {
      setState(() => _checkingSession = false);
    }
  }

  Future<void> _saveUserPrefs(
    Map<String, dynamic> data, {
    required bool merchantMode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_merchant', merchantMode);
    AppInfo.isMerchantApp = merchantMode;
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
        .limit(20)
        .get();
    return _pickMostRestrictedLookup(snap.docs);
  }

  int _accountStatusWeight(Map<String, dynamic> data) {
    final status = _accountStatus(data);
    if (status == 'blocked') return 3;
    if (status == 'suspended') return 2;
    return 1;
  }

  String _accountStatus(Map<String, dynamic> data) {
    return (data['account_status'] ?? 'active').toString().trim().toLowerCase();
  }

  String? _restrictedAuthMessage(
    Map<String, dynamic>? data, {
    required String action,
  }) {
    if (data == null) return null;
    final status = _accountStatus(data);
    if (status == 'blocked') {
      return 'لا يمكن $action: هذه البيانات مرتبطة بحساب محظور نهائياً.';
    }
    if (status == 'suspended') {
      return 'لا يمكن $action: هذه البيانات مرتبطة بحساب موقوف حالياً.';
    }
    return null;
  }

  _UserLookup? _pickMostRestrictedLookup(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (docs.isEmpty) return null;
    _UserLookup? selected;
    var selectedWeight = -1;
    for (final doc in docs) {
      final lookup = _UserLookup(doc.id, doc.data());
      final weight = _accountStatusWeight(lookup.data);
      if (selected == null || weight > selectedWeight) {
        selected = lookup;
        selectedWeight = weight;
      }
      if (selectedWeight >= 3) break;
    }
    return selected;
  }

  Future<_UserLookup?> _getUserByUidOrEmail({
    String? uid,
    String? email,
  }) async {
    final users = FirebaseFirestore.instance.collection('users');
    _UserLookup? best;
    var bestWeight = -1;

    void consider(_UserLookup? candidate) {
      if (candidate == null) return;
      final weight = _accountStatusWeight(candidate.data);
      if (best == null || weight > bestWeight) {
        best = candidate;
        bestWeight = weight;
      }
    }

    if (email != null && email.trim().isNotEmpty) {
      final normalizedEmail = email.trim().toLowerCase();
      final byEmail = await users
          .where('email', isEqualTo: normalizedEmail)
          .limit(20)
          .get();
      consider(_pickMostRestrictedLookup(byEmail.docs));
    }

    if (uid != null && uid.trim().isNotEmpty) {
      final byUid = await users
          .where('uid', isEqualTo: uid.trim())
          .limit(20)
          .get();
      consider(_pickMostRestrictedLookup(byUid.docs));
    }

    return best;
  }

  Future<void> _persistAndNavigate(
    Map<String, dynamic> data, {
    bool? forceMerchantMode,
  }) async {
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
    final bool hasMerchantAccess = data['is_merchant'] == true;
    final bool requestedMerchantMode = forceMerchantMode ?? false;
    final verificationStatus = (data['merchant_verification_status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final bool merchantVerified =
        data['merchant_verified'] == true || verificationStatus == 'approved';
    final bool isMerchantMode =
        requestedMerchantMode && hasMerchantAccess && merchantVerified;
    final bool shouldOpenMerchantVerification =
        requestedMerchantMode && hasMerchantAccess && !merchantVerified;
    AppInfo.isMerchantApp = isMerchantMode;
    await _saveUserPrefs(data, merchantMode: isMerchantMode);

    final whatsapp = _normalizeWhatsapp((data['whatsapp'] ?? '').toString());
    if (whatsapp.isNotEmpty) {
      await NotificationService.initUserNotifications(
        whatsapp,
        requestPermission: true,
      );
    }

    if (!mounted) return;
    AppNavigator.pushReplacementNamed(
      context,
      isMerchantMode
          ? '/merchant/orders'
          : (shouldOpenMerchantVerification ? '/merchant/verify' : '/home'),
    );
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
      final restrictedMessage = _restrictedAuthMessage(
        existing.data,
        action: 'تسجيل الدخول',
      );
      if (restrictedMessage != null) {
        await FirebaseAuth.instance.signOut();
        return restrictedMessage;
      }

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
      mergedData['is_merchant'] = mergedData['is_merchant'] == true;
      await _persistAndNavigate(mergedData);
      return null;
    }

    final minimal = {
      'name': user.displayName ?? '',
      'email': email,
      'username': '',
      'whatsapp': '',
      'uid': user.uid,
      'is_merchant': false,
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
            'is_merchant': legacy.data['is_merchant'] == true,
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
      final restrictedMessage = _restrictedAuthMessage(
        (await _findByField('email', email))?.data,
        action: 'تسجيل الدخول',
      );
      if (restrictedMessage != null) {
        return restrictedMessage;
      }

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

    if (!_isValidEmail(email)) return 'بريد إلكتروني غير صحيح';
    if (inputDisplayName.length < 3) return 'الاسم قصير جدا';
    if (inputTiktok.isEmpty) return 'يوزر تيك توك مطلوب';
    if (whatsapp.isEmpty) return 'رقم الواتساب مطلوب';
    if (!WhatsappUtils.isValidEgyptianWhatsapp(whatsapp)) {
      return 'رقم الواتساب يجب أن يكون 11 رقم ويبدأ بـ 01';
    }
    if (password.length < 6) return 'كلمة السر لا تقل عن 6 أحرف';

    try {
      final users = FirebaseFirestore.instance.collection('users');

      final emailDoc = await _findByField('email', email);
      final whatsappDoc = await _findByField('whatsapp', whatsapp);
      final restrictedByEmail = _restrictedAuthMessage(
        emailDoc?.data,
        action: 'إنشاء حساب',
      );
      if (restrictedByEmail != null) return restrictedByEmail;
      final restrictedByWhatsapp = _restrictedAuthMessage(
        whatsappDoc?.data,
        action: 'إنشاء حساب',
      );
      if (restrictedByWhatsapp != null) return restrictedByWhatsapp;

      if (emailDoc != null &&
          whatsappDoc != null &&
          emailDoc.docId != whatsappDoc.docId) {
        return 'البيانات مرتبطة بحسابين مختلفين';
      }

      final existing = emailDoc ?? whatsappDoc;
      if (existing != null) {
        if (existing.email.isNotEmpty && existing.email != email) {
          return 'رقم الواتساب مرتبط ببريد آخر';
        }
        final existingWhatsapp = _normalizeWhatsapp(existing.whatsapp);
        if (existingWhatsapp.isNotEmpty && existingWhatsapp != whatsapp) {
          return 'البريد مرتبط برقم واتساب آخر';
        }
      }

      final name = inputDisplayName;
      final username = inputTiktok;
      final existingData = existing?.data ?? const <String, dynamic>{};
      final existingIsMerchant = existingData['is_merchant'] == true;
      final accountHasMerchantAccess = existingIsMerchant;
      final existingVerificationStatus =
          (existingData['merchant_verification_status'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
      final merchantVerified =
          existingData['merchant_verified'] == true ||
          existingVerificationStatus == 'approved';
      final merchantVerificationStatus = merchantVerified
          ? 'approved'
          : (accountHasMerchantAccess
                ? (existingVerificationStatus.isEmpty
                      ? 'not_submitted'
                      : existingVerificationStatus)
                : '');

      String uid = existing?.uid ?? '';
      UserCredential? authCred;

      if (existing != null && existing.uid.isNotEmpty) {
        try {
          authCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
        } on FirebaseAuthException catch (e) {
          if (e.code == 'user-not-found') {
            authCred = await FirebaseAuth.instance
                .createUserWithEmailAndPassword(
                  email: email,
                  password: password,
                );
          } else if (e.code == 'wrong-password' ||
              e.code == 'invalid-credential') {
            return 'الحساب موجود بالفعل، أدخل كلمة السر الصحيحة';
          } else {
            return _mapAuthError(e);
          }
        }
      } else {
        authCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
      uid = (authCred.user?.uid ?? uid).trim();

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
          'password_hash': null,
          'is_merchant': accountHasMerchantAccess,
          if (accountHasMerchantAccess) ...{
            'merchant_whatsapp': whatsapp,
            'merchant_active': merchantVerified
                ? (existingData['merchant_active'] != false)
                : false,
            'merchant_billing_mode': 'monthly_fixed',
            'merchant_monthly_fee': 750,
            'merchant_revenue_percent': FieldValue.delete(),
            'merchant_verification_status': merchantVerificationStatus,
            'merchant_verified': merchantVerified,
          },
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
          'is_merchant': accountHasMerchantAccess,
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
          'is_merchant': accountHasMerchantAccess,
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
        'is_merchant': accountHasMerchantAccess,
      });
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        try {
          final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
          if (cred.user == null) return 'تعذر الوصول للحساب الموجود';
          final users = FirebaseFirestore.instance.collection('users');
          final existing = await _getUserByUidOrEmail(
            uid: cred.user!.uid,
            email: email,
          );
          final restrictedMessage = _restrictedAuthMessage(
            existing?.data,
            action: 'إنشاء حساب',
          );
          if (restrictedMessage != null) {
            await FirebaseAuth.instance.signOut();
            return restrictedMessage;
          }
          final hasMerchantAccess = (existing?.data['is_merchant'] == true);
          final existingVerificationStatus =
              (existing?.data['merchant_verification_status'] ?? '')
                  .toString()
                  .trim()
                  .toLowerCase();
          final merchantVerified =
              existing?.data['merchant_verified'] == true ||
              existingVerificationStatus == 'approved';
          final merchantVerificationStatus = merchantVerified
              ? 'approved'
              : (hasMerchantAccess
                    ? (existingVerificationStatus.isEmpty
                          ? 'not_submitted'
                          : existingVerificationStatus)
                    : '');
          final payload = <String, dynamic>{
            'name': inputDisplayName,
            'email': email,
            'whatsapp': whatsapp,
            'username': inputTiktok,
            'tiktok': inputTiktok,
            'uid': cred.user!.uid,
            'password': password,
            'password_hash': null,
            'is_merchant': hasMerchantAccess,
            'updated_at': FieldValue.serverTimestamp(),
            if (hasMerchantAccess)
              'merchant_active': merchantVerified
                  ? (existing?.data['merchant_active'] != false)
                  : false,
            if (hasMerchantAccess) 'merchant_whatsapp': whatsapp,
            if (hasMerchantAccess) 'merchant_billing_mode': 'monthly_fixed',
            if (hasMerchantAccess) 'merchant_monthly_fee': 750,
            'merchant_revenue_percent': FieldValue.delete(),
            if (hasMerchantAccess)
              'merchant_verification_status': merchantVerificationStatus,
            if (hasMerchantAccess) 'merchant_verified': merchantVerified,
          };
          final docId = existing?.docId ?? cred.user!.uid;
          await users.doc(docId).set({
            ...payload,
            'created_at':
                existing?.data['created_at'] ?? FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          await _persistAndNavigate(payload);
          return null;
        } on FirebaseAuthException catch (_) {
          return 'الحساب موجود بالفعل بكلمة سر مختلفة';
        }
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
      final existing = await _findByField('email', email);
      final restrictedMessage = _restrictedAuthMessage(
        existing?.data,
        action: 'إعادة تعيين كلمة السر',
      );
      if (restrictedMessage != null) {
        return restrictedMessage;
      }

      // Firebase may suppress user-not-found here when email enumeration
      // protection is enabled, so bootstrap legacy Firestore-only accounts first.
      if (existing != null) {
        try {
          await _bootstrapLegacyAuthForRecovery(email);
        } on FirebaseAuthException catch (legacyError) {
          if (legacyError.code == 'operation-not-allowed') {
            return "تم تعطيل إعادة التعيين عبر البريد من Firebase";
          }
          return "تعذّر تجهيز حسابك القديم، حاول لاحقًا";
        }
      }

      await FirebaseAuth.instance.setLanguageCode('ar');
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return "لم يتم العثور على الحساب";
      }
      if (e.code == 'invalid-email') {
        return "أدخل بريدًا إلكترونيًا صحيحًا";
      }
      if (e.code == 'operation-not-allowed') {
        return "تم تعطيل إعادة التعيين عبر البريد من Firebase";
      }
      if (e.code == 'too-many-requests') {
        return "عدد محاولات كبير، حاول لاحقًا";
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
    return WhatsappUtils.validateRequiredEgyptianWhatsapp(value);
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
