// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/tt_colors.dart';
import '../../core/app_info.dart';
import '../../services/onesignal_service.dart';
import '../../utils/html_meta.dart';
import '../../widgets/glass_card.dart';

class UserDataEntryScreen extends StatefulWidget {
  // EN: Creates UserDataEntryScreen.
  // AR: ينشئ UserDataEntryScreen.
  const UserDataEntryScreen({super.key});

  // EN: Creates state object.
  // AR: تنشئ كائن الحالة.
  @override
  State<UserDataEntryScreen> createState() => _UserDataEntryScreenState();
}

class _UserDataEntryScreenState extends State<UserDataEntryScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _name = TextEditingController();
  final TextEditingController _whatsapp = TextEditingController();
  final TextEditingController _tiktok = TextEditingController();

  bool _isCheckingLogin = true;
  bool _hasShownConsent = false;
  bool _consentShown = false;

  String? _savedName;
  String? _savedWhatsapp;
  String? _savedTiktok;

  static const String _consentShownKey = 'user_consent_shown';

  bool get _hasSavedUser =>
      (_savedName?.isNotEmpty ?? false) &&
      (_savedWhatsapp?.isNotEmpty ?? false) &&
      (_savedTiktok?.isNotEmpty ?? false);

  // EN: Initializes widget state.
  // AR: تهيّئ حالة الودجت.
  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      setPageTitle(AppInfo.appName);

      setMetaDescription(
        'سجل دخولك أو أنشئ حساب جديد في HRM Store. بيانات بسيطة: الاسم، رقم الواتساب، يوزر تيك توك.',
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        Navigator.pushReplacementNamed(context, '/android');
        return;
      }

      _bootstrap();
    });

  }

  // EN: Releases resources.
  // AR: تفرّغ الموارد.
  @override
  void dispose() {
    _name.dispose();
    _whatsapp.dispose();
    _tiktok.dispose();
    super.dispose();
  }

  // EN: Loads saved user state and continues login flow.
  // AR: تحمّل بيانات المستخدم وتكمل مسار الدخول.
  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _consentShown = prefs.getBool(_consentShownKey) ?? false;

    await _checkExistingLogin();
    if (mounted) {
      setState(() => _isCheckingLogin = false);
      if (!_hasSavedUser) {
        await _showConsentInfoDialog();
      }
    }
  }

  // EN: Checks Existing Login.
  // AR: تفحص Existing Login.
  Future<void> _checkExistingLogin() async {
    final prefs = await SharedPreferences.getInstance();
    _savedName = prefs.getString('user_name');
    _savedWhatsapp = prefs.getString('user_whatsapp');
    _savedTiktok = prefs.getString('user_tiktok');

    if (_hasSavedUser) {
      await OneSignalService.registerUser(
        whatsapp: _savedWhatsapp!,
        isAdmin: false,
        requestPermission: true,
      );

      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        '/home',
        arguments: {
          'name': _savedName!,
          'whatsapp': _savedWhatsapp!,
          'tiktok': _savedTiktok!,
        },
      );
      return;
    }
  }

  Future<void> _showConsentInfoDialog() async {
    if (_hasShownConsent || !mounted || _consentShown) return;
    _hasShownConsent = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_consentShownKey, true);
    _consentShown = true;

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: GlassCard(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.privacy_tip,
                      size: 48,
                      color: TTColors.primaryCyan,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "تنبيه الخصوصية",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        color: TTColors.textWhite,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "نحتاج رقم الواتساب للتواصل معك في حالة حدوث مشكلة،"
                      " ونحتاج يوزر التيك توك للتأكد أن العملات تصل للحساب الصحيح.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: TTColors.textGray,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              Navigator.pushNamed(
                                context,
                                '/privacy',
                              );
                            },
                            child: const Text("سياسة الخصوصية"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: TTColors.primaryPink,
                            ),
                            child: const Text("حسناً"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // EN: Saves And Enter.
  // AR: تحفظ And Enter.
  Future<void> _saveAndEnter() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _name.text.trim();
    final whatsapp = _whatsapp.text.trim();
    final tiktok = _tiktok.text.trim();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    await prefs.setString('user_whatsapp', whatsapp);
    await prefs.setString('user_tiktok', tiktok);
    await prefs.setBool('is_admin', false);
    await prefs.setString('user_uid', uid);

    final docId = uid.isNotEmpty ? uid : whatsapp;

    await FirebaseFirestore.instance.collection('users').doc(docId).set({
      'name': name,
      'whatsapp': whatsapp,
      'tiktok': tiktok,
      'uid': uid,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await OneSignalService.registerUser(
      whatsapp: whatsapp,
      isAdmin: false,
      requestPermission: true,
    );

    if (!mounted) return;

    Navigator.pushReplacementNamed(
      context,
      '/home',
      arguments: {'name': name, 'whatsapp': whatsapp, 'tiktok': tiktok},
    );
  }

  // EN: Builds widget UI.
  // AR: تبني واجهة الودجت.
  @override
  Widget build(BuildContext context) {
    if (_isCheckingLogin) {
      return Scaffold(
        backgroundColor: TTColors.cardBg,
        body: const Center(
          child: CircularProgressIndicator(color: TTColors.primaryCyan),
        ),
      );
    }
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: GlassCard(
                        margin: EdgeInsets.zero,
                        padding: const EdgeInsets.all(28),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.stars,
                                size: 60,
                                color: TTColors.primaryCyan,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                AppInfo.appName,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Cairo',
                                  color: TTColors.textWhite,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "إنشاء حساب جديد",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: TTColors.textGray,
                                ),
                              ),
                              const SizedBox(height: 25),
                              TextFormField(
                                controller: _name,
                                decoration: const InputDecoration(
                                  labelText: "الاسم بالكامل",
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r"[a-zA-Z\s\u0600-\u06FF]"),
                                  ),
                                ],
                                validator: (v) => (v == null || v.length < 3)
                                    ? "الاسم قصير جدا"
                                    : null,
                              ),
                              const SizedBox(height: 15),
                              TextFormField(
                                controller: _whatsapp,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: "رقم الواتساب",
                                  hintText: "01xxxxxxxxx",
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(11),
                                ],
                                validator: (v) => (v == null ||
                                        !v.startsWith('01') ||
                                        v.length != 11)
                                    ? "رقم غير صحيح"
                                    : null,
                              ),
                              const SizedBox(height: 15),
                              TextFormField(
                                controller: _tiktok,
                                decoration: const InputDecoration(
                                  labelText: "يوزر تيك توك",
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[a-zA-Z0-9._]'),
                                  ),
                                ],
                                validator: (v) => (v == null || v.isEmpty)
                                    ? "يرجى إدخال اليوزر"
                                    : null,
                              ),
                              const SizedBox(height: 30),
                              ElevatedButton(
                                onPressed: _saveAndEnter,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: TTColors.primaryPink,
                                  minimumSize:
                                      const Size(double.infinity, 55),
                                ),
                                child: const Text(
                                  "حفظ والدخول",
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
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
            );
          },
        ),
      ),
    );
  }
}
