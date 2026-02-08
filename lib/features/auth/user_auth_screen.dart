// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

import '../../core/app_info.dart';
import '../../core/tt_colors.dart';
import '../../services/onesignal_service.dart';
import '../../widgets/top_snackbar.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/snow_background.dart';
import '../../utils/html_meta.dart';

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
  final _signupKey = GlobalKey<FormState>();
  final _loginKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  final _loginIdCtrl = TextEditingController();
  final _loginPassCtrl = TextEditingController();

  bool _isLogin = false;
  bool _loading = false;
  bool _checkingSession = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      setPageTitle( '${AppInfo.appName}');
      setMetaDescription(
        'إنشاء حساب أو تسجيل الدخول إلى ${AppInfo.appName}. منصة موثوقة لشحن خدمات تيك توك والألعاب ومتابعة الطلبات بسهولة.',
      );
    }

    _checkExistingSession();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _whatsappCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _loginIdCtrl.dispose();
    _loginPassCtrl.dispose();
    super.dispose();
  }

  String _normalizeWhatsapp(String input) {
    return input.replaceAll(RegExp(r'[^0-9+]'), '').trim();
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

  void _showMessage(String msg, {Color color = TTColors.primaryCyan}) {
    if (!mounted) return;
    TopSnackBar.show(
      context,
      msg,
      backgroundColor: color,
      icon: Icons.info_outline,
    );
  }

  Future<void> _checkExistingSession() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name') ?? '';
    final whatsapp = prefs.getString('user_whatsapp') ?? '';
    final tiktok = prefs.getString('user_tiktok') ?? '';

    if (name.isNotEmpty && whatsapp.isNotEmpty && mounted) {
      Navigator.pushReplacementNamed(
        context,
        '/home',
        arguments: {
          'name': name,
          'whatsapp': whatsapp,
          'tiktok': tiktok,
        },
      );
      return;
    }

    if (mounted) setState(() => _checkingSession = false);
  }

  Future<void> _saveUserPrefs(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_admin', false);
    await prefs.setString('user_uid', (data['uid'] ?? '').toString());
    await prefs.setString('user_name', (data['name'] ?? '').toString());
    await prefs.setString('user_email', (data['email'] ?? '').toString());
    await prefs.setString('user_username', (data['username'] ?? '').toString());
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

  Future<_UserLookup?> _findUserByIdentifier(String identifier) async {
    final trimmed = identifier.trim();
    if (trimmed.isEmpty) return null;

    if (_isValidEmail(trimmed)) {
      return _findByField('email', trimmed.toLowerCase());
    }

    final usernameSnap = await _findByField('username', trimmed);
    if (usernameSnap != null) return usernameSnap;

    final normalized = _normalizeWhatsapp(trimmed);
    if (normalized.isEmpty) return null;
    return _findByField('whatsapp', normalized);
  }

  Future<_UserLookup?> _getUserByUidOrEmail({
    String? uid,
    String? email,
  }) async {
    final users = FirebaseFirestore.instance.collection('users');

    if (uid != null && uid.trim().isNotEmpty) {
      final snap =
          await users.where('uid', isEqualTo: uid.trim()).limit(1).get();
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
    // تأكد من وجود uid في البيانات المحفوظة للتفضيلات
    if (!data.containsKey('uid')) {
      data = Map<String, dynamic>.from(data);
      data['uid'] = FirebaseAuth.instance.currentUser?.uid ?? '';
    }
    await _saveUserPrefs(data);

    final whatsapp =
        _normalizeWhatsapp((data['whatsapp'] ?? '').toString());
    if (whatsapp.isNotEmpty) {
      await OneSignalService.registerUser(
        whatsapp: whatsapp,
        isAdmin: false,
        requestPermission: true,
      );
    }

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home');
  }

  Future<void> _handleAuthSuccess(User? user, {String? fallbackEmail}) async {
    if (user == null) {
      setState(() => _error = 'فشل تسجيل الدخول');
      return;
    }

    final email = (user.email ?? fallbackEmail ?? '').toLowerCase();
    final users = FirebaseFirestore.instance.collection('users');
    final existing = await _getUserByUidOrEmail(
      uid: user.uid,
      email: email,
    );

    if (existing != null) {
      if (existing.uid.isEmpty && user.uid.isNotEmpty) {
        await users.doc(existing.docId).set({
          'uid': user.uid,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await _persistAndNavigate(existing.data);
      return;
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
  }

  Future<bool> _migrateLegacyUser(String email, String password) async {
    final legacy = await _findByField('email', email.toLowerCase());
    if (legacy == null) return false;

    final hash = legacy.passwordHash;
    if (hash.isEmpty || hash != _hashPassword(password)) {
      return false;
    }

    try {
      final authCred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      final uid = authCred.user?.uid ?? '';

      await FirebaseFirestore.instance.collection('users').doc(legacy.docId).set({
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

  Future<String?> _promptLinkEmail() async {
    if (!mounted) return null;
    final controller = TextEditingController();
    String? result;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TTColors.cardBg,
        title: const Text('ربط البريد الإلكتروني'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'البريد الإلكتروني',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final email = controller.text.trim().toLowerCase();
              if (!_isValidEmail(email)) {
                _showMessage('بريد إلكتروني غير صحيح', color: Colors.orange);
                return;
              }
              result = email;
              Navigator.pop(ctx);
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );

    return result;
  }

  Future<void> _register() async {
    if (!_signupKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim().toLowerCase();
    final whatsapp = _normalizeWhatsapp(_whatsappCtrl.text);
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;
    final passwordHash = _hashPassword(password);

    try {
      final users = FirebaseFirestore.instance.collection('users');

      final emailDoc = await _findByField('email', email);
      final usernameDoc = await _findByField('username', username);
      final whatsappDoc = await _findByField('whatsapp', whatsapp);

      if (usernameDoc != null &&
          (emailDoc == null || usernameDoc.docId != emailDoc.docId)) {
        setState(() {
          _error = 'اليوزر مستخدم بالفعل';
          _loading = false;
        });
        return;
      }

      if (whatsappDoc != null &&
          (emailDoc == null || whatsappDoc.docId != emailDoc.docId)) {
        if (whatsappDoc.uid.isNotEmpty) {
          setState(() {
            _error = 'هذا الحساب مسجل بالفعل';
            _loading = false;
          });
        } else {
          setState(() {
            _error = 'رقم الواتساب مستخدم بالفعل';
            _loading = false;
          });
        }
        return;
      }

      if (emailDoc != null) {
        if (emailDoc.uid.isNotEmpty) {
          setState(() {
            _error = 'البريد الإلكتروني مستخدم بالفعل';
            _loading = false;
          });
          return;
        }
        if (emailDoc.whatsapp.isNotEmpty && emailDoc.whatsapp != whatsapp) {
          setState(() {
            _error = 'البريد مرتبط برقم واتساب آخر';
            _loading = false;
          });
          return;
        }
      }

      // إنشاء مستخدم في Firebase Auth
      final authCred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      final uid = authCred.user?.uid ?? '';

      if (emailDoc != null) {
        await users.doc(emailDoc.docId).set({
          'name': name,
          'email': email,
          'whatsapp': whatsapp,
          'username': username,
          'uid': uid,
          'password_hash': passwordHash,
          'created_at': emailDoc.data['created_at'] ?? FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await _saveUserPrefs({
          'name': name,
          'email': email,
          'whatsapp': whatsapp,
          'username': username,
        });

        await OneSignalService.registerUser(
          whatsapp: whatsapp,
          isAdmin: false,
          requestPermission: true,
        );

        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home');
        return;
      }

      if (whatsappDoc != null && whatsappDoc.uid.isEmpty) {
        if (whatsappDoc.email.isNotEmpty && whatsappDoc.email != email) {
          setState(() {
            _error = 'رقم الواتساب مرتبط ببريد آخر';
            _loading = false;
          });
          return;
        }

        await users.doc(whatsappDoc.docId).set({
          'name': name,
          'email': email,
          'whatsapp': whatsapp,
          'username': username,
          'uid': uid,
          'password_hash': passwordHash,
          'created_at':
              whatsappDoc.data['created_at'] ?? FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await _saveUserPrefs({
          'name': name,
          'email': email,
          'whatsapp': whatsapp,
          'username': username,
        });

        await OneSignalService.registerUser(
          whatsapp: whatsapp,
          isAdmin: false,
          requestPermission: true,
        );

        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home');
        return;
      }

      if (usernameDoc != null && usernameDoc.uid.isEmpty) {
        if (usernameDoc.email.isNotEmpty && usernameDoc.email != email) {
          setState(() {
            _error = 'اليوزر مرتبط ببريد آخر';
            _loading = false;
          });
          return;
        }

        await users.doc(usernameDoc.docId).set({
          'name': name,
          'email': email,
          'whatsapp': whatsapp,
          'username': username,
          'uid': uid,
          'password_hash': passwordHash,
          'created_at':
              usernameDoc.data['created_at'] ?? FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await _saveUserPrefs({
          'name': name,
          'email': email,
          'whatsapp': whatsapp,
          'username': username,
        });

        await OneSignalService.registerUser(
          whatsapp: whatsapp,
          isAdmin: false,
          requestPermission: true,
        );

        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home');
        return;
      }

      final String docId = emailDoc?.docId ??
          whatsappDoc?.docId ??
          usernameDoc?.docId ??
          (uid.isNotEmpty ? uid : whatsapp);

      await users.doc(docId).set({
        'name': name,
        'email': email,
        'whatsapp': whatsapp,
        'username': username,
        'uid': uid,
        'password_hash': passwordHash,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _saveUserPrefs({
        'name': name,
        'email': email,
        'whatsapp': whatsapp,
        'username': username,
      });

      await OneSignalService.registerUser(
        whatsapp: whatsapp,
        isAdmin: false,
        requestPermission: true,
      );

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } on FirebaseAuthException catch (e) {
      String msg = 'فشل إنشاء الحساب';
      if (e.code == 'email-already-in-use') {
        msg = 'البريد الإلكتروني مستخدم بالفعل';
      } else if (e.code == 'weak-password') {
        msg = 'كلمة السر ضعيفة';
      } else {
        msg = _mapAuthError(e);
      }
      setState(() => _error = msg);
    } catch (_) {
      setState(() => _error = 'حدث خطأ أثناء إنشاء الحساب');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _login() async {
    if (!_loginKey.currentState!.validate()) return;

    final identifier = _loginIdCtrl.text.trim();
    final password = _loginPassCtrl.text;

    if (!_isValidEmail(identifier)) {
      setState(() => _error = 'أدخل بريدًا إلكترونيًا صحيحًا');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final email = identifier.toLowerCase();
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      await _handleAuthSuccess(credential.user, fallbackEmail: email);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        final migrated = await _migrateLegacyUser(identifier, password);
        if (!migrated) {
          setState(() => _error = 'بيانات الدخول غير صحيحة');
        }
      } else if (e.code == 'wrong-password') {
        setState(() => _error = 'بيانات الدخول غير صحيحة');
      } else {
        setState(() => _error = _mapAuthError(e));
      }
    } catch (_) {
      setState(() => _error = 'حدث خطأ أثناء تسجيل الدخول');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _loginIdCtrl.text.trim().toLowerCase();
    if (!_isValidEmail(email)) {
      _showMessage("أدخل بريدًا إلكترونيًا صحيحًا", color: Colors.orange);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showMessage("تم إرسال رابط إعادة التعيين إلى بريدك");
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        _showMessage(
          "لم يتم العثور على الحساب في النظام الجديد. سجّل الدخول مرة ليتم ترحيل حسابك ثم أعد المحاولة.",
          color: Colors.orange,
        );
      } else {
        _showMessage("تعذّر إرسال رابط التعيين، حاول لاحقًا", color: Colors.orange);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildToggle() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _loading
                ? null
                : () => setState(() => _isLogin = false),
            child: const Text('إنشاء حساب'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: _loading ? null : () => setState(() => _isLogin = true),
            child: const Text('تسجيل الدخول'),
          ),
        ),
      ],
    );
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
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.person,
                          size: 56,
                          color: TTColors.primaryCyan,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          AppInfo.appName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isLogin ? 'تسجيل الدخول' : 'إنشاء حساب جديد',
                          style: TextStyle(
                            color: TTColors.textGray,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildToggle(),
                        const SizedBox(height: 16),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ),
                        if (_isLogin)
                          Form(
                            key: _loginKey,
                            child: Column(
                              children: [
        TextFormField(
          controller: _loginIdCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'البريد الإلكتروني',
          ),
          validator: (v) {
            if (v == null || !_isValidEmail(v.trim())) {
              return 'أدخل بريدًا إلكترونيًا صحيحًا';
            }
            return null;
          },
        ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _loginPassCtrl,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                    labelText: 'كلمة السر',
                                  ),
                                  validator: (v) {
                                    if (v == null || v.length < 6) {
                                      return 'كلمة السر غير صحيحة';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),
                                ElevatedButton(
                                  onPressed: _loading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: TTColors.primaryCyan,
                                    foregroundColor: Colors.black,
                                    minimumSize:
                                        const Size(double.infinity, 48),
                                  ),
                                  child: Text(
                                    _loading ? 'جاري الدخول...' : 'دخول',
                                    style:
                                        const TextStyle(fontFamily: 'Cairo'),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed:
                                      _loading ? null : _sendPasswordReset,
                                  child: const Text("نسيت كلمة السر؟"),
                                ),
                              ],
                            ),
                          )
                        else
                          Form(
                            key: _signupKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _nameCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'الاسم بالكامل',
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().length < 3) {
                                      return 'الاسم مطلوب';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    labelText: 'البريد الإلكتروني',
                                  ),
                                  validator: (v) {
                                    if (v == null || !_isValidEmail(v.trim())) {
                                      return 'بريد إلكتروني غير صحيح';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _whatsappCtrl,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                    labelText: 'رقم الواتساب',
                                  ),
                                  validator: (v) {
                                    if (v == null ||
                                        _normalizeWhatsapp(v).isEmpty) {
                                      return 'رقم الواتساب مطلوب';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _usernameCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'اليوزر',
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().length < 3) {
                                      return 'اليوزر مطلوب';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _passwordCtrl,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                    labelText: 'كلمة السر',
                                  ),
                                  validator: (v) {
                                    if (v == null || v.length < 6) {
                                      return 'كلمة السر لا تقل عن 6 أحرف';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),
                                ElevatedButton(
                                  onPressed: _loading ? null : _register,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: TTColors.primaryPink,
                                    minimumSize:
                                        const Size(double.infinity, 48),
                                  ),
                                  child: Text(
                                    _loading
                                        ? 'جاري إنشاء الحساب...'
                                        : 'إنشاء حساب',
                                    style:
                                        const TextStyle(fontFamily: 'Cairo'),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'تسجيل الحساب يتم مرة واحدة فقط',
                                  style: TextStyle(
                                    color: TTColors.textGray,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/privacy'),
                          child: const Text('سياسة الخصوصية'),
                        ),
                      ],
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
