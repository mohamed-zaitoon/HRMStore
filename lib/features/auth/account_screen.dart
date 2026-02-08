// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/tt_colors.dart';
import '../../widgets/top_snackbar.dart';
import '../../widgets/glass_app_bar.dart';
import '../../widgets/glass_card.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _waCtrl = TextEditingController();
  final _tiktokCtrl = TextEditingController();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  bool _dirty = false;
  bool _loading = false;
  String _uid = '';

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(() => _dirty = true);
    _emailCtrl.addListener(() => _dirty = true);
    _waCtrl.addListener(() => _dirty = true);
    _tiktokCtrl.addListener(() => _dirty = true);
    _load();
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _waCtrl.dispose();
    _tiktokCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _uid = prefs.getString('user_uid') ?? '';
      _nameCtrl.text = prefs.getString('user_name') ?? '';
      _emailCtrl.text = prefs.getString('user_email') ?? '';
      _waCtrl.text = prefs.getString('user_whatsapp') ?? '';
      _tiktokCtrl.text = prefs.getString('user_tiktok') ?? '';
      _dirty = false;
    });
    _listenToUserDoc();
  }

  void _listenToUserDoc() {
    _userSub?.cancel();
    final users = FirebaseFirestore.instance.collection('users');

    DocumentReference<Map<String, dynamic>>? ref;
    if (_uid.isNotEmpty) {
      ref = users.doc(_uid);
    } else if (_emailCtrl.text.trim().isNotEmpty) {
      users
          .where('email', isEqualTo: _emailCtrl.text.trim().toLowerCase())
          .limit(1)
          .get()
          .then((snap) {
        if (!mounted) return;
        if (snap.docs.isNotEmpty && _userSub == null) {
          _userSub = snap.docs.first.reference.snapshots().listen(_applySnapshot);
        }
      });
      return;
    } else if (_waCtrl.text.trim().isNotEmpty) {
      ref = users.doc(_waCtrl.text.trim());
    }

    if (ref == null) return;
    _userSub = ref.snapshots().listen(_applySnapshot);
  }

  void _applySnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data();
    if (data == null) return;
    if (_dirty) return; // لا نكتب فوق تعديل المستخدم الحالي

    setState(() {
      _nameCtrl.text = (data['name'] ?? _nameCtrl.text).toString();
      _emailCtrl.text = (data['email'] ?? _emailCtrl.text).toString();
      _waCtrl.text = (data['whatsapp'] ?? _waCtrl.text).toString();
      _tiktokCtrl.text =
          (data['tiktok'] ?? data['username'] ?? _tiktokCtrl.text).toString();
      _dirty = false;
    });
  }

  Future<void> _saveProfile() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _nameCtrl.text.trim());
    await prefs.setString('user_email', _emailCtrl.text.trim());
    await prefs.setString('user_whatsapp', _waCtrl.text.trim());
    await prefs.setString('user_tiktok', _tiktokCtrl.text.trim());

    final email = _emailCtrl.text.trim().toLowerCase();
    final users = FirebaseFirestore.instance.collection('users');

    DocumentReference<Map<String, dynamic>>? ref;
    if (_uid.isNotEmpty) {
      final snap = await users.where('uid', isEqualTo: _uid).limit(1).get();
      if (snap.docs.isNotEmpty) ref = snap.docs.first.reference;
    }
    if (ref == null && email.isNotEmpty) {
      final snap =
          await users.where('email', isEqualTo: email).limit(1).get();
      if (snap.docs.isNotEmpty) ref = snap.docs.first.reference;
    }

    if (ref != null) {
      await ref.set({
        'name': _nameCtrl.text.trim(),
        'whatsapp': _waCtrl.text.trim(),
        'username': _tiktokCtrl.text.trim(),
        'tiktok': _tiktokCtrl.text.trim(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    if (mounted) {
      setState(() => _loading = false);
      TopSnackBar.show(context, 'تم حفظ البيانات', icon: Icons.check_circle);
    }
  }

  Future<void> _resetPassword() async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? _emailCtrl.text.trim().toLowerCase();
    if (user == null || email.isEmpty) {
      _toast('سجّل الدخول بالبريد أولاً لتحديث كلمة السر', Colors.orange);
      return;
    }

    final currentCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تحديث كلمة السر'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('سيتطلب الأمر إعادة التوثيق للحساب $email'),
            TextField(
              controller: currentCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'كلمة السر الحالية'),
            ),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'كلمة سر جديدة'),
            ),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'تأكيد كلمة السر الجديدة'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final current = currentCtrl.text;
              final p1 = passCtrl.text;
              final p2 = confirmCtrl.text;
              if (p1.length < 6 || p1 != p2) {
                _toast('تأكد من صحة كلمة السر والتطابق', Colors.red);
                return;
              }
              try {
                final credential = EmailAuthProvider.credential(
                  email: email,
                  password: current,
                );
                await user.reauthenticateWithCredential(credential);
                await user.updatePassword(p1);
                if (ctx.mounted) Navigator.pop(ctx);
                _toast('تم تحديث كلمة السر بنجاح', Colors.green);
              } on FirebaseAuthException catch (e) {
                _toast(_mapAuthErr(e), Colors.red);
              }
            },
            child: const Text('تحديث'),
          ),
        ],
      ),
    );
  }

  String _mapAuthErr(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'كلمة السر الحالية غير صحيحة';
      case 'weak-password':
        return 'كلمة السر الجديدة ضعيفة';
      case 'requires-recent-login':
        return 'أعد تسجيل الدخول ثم حاول مرة أخرى';
      default:
        return 'تعذر تحديث كلمة السر (${e.code})';
    }
  }

  void _toast(String msg, Color color) {
    TopSnackBar.show(
      context,
      msg,
      backgroundColor: color,
      icon: Icons.info_outline,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GlassAppBar(
        title: Text('حسابي'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: GlassCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildField('الاسم', _nameCtrl),
                  _buildField('البريد الإلكتروني', _emailCtrl,
                      keyboard: TextInputType.emailAddress),
                  _buildField('رقم الواتساب', _waCtrl,
                      keyboard: TextInputType.phone),
                  _buildField('يوزر تيك توك', _tiktokCtrl),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _loading ? null : _saveProfile,
                          icon: const Icon(Icons.save),
                          label: Text(_loading ? '...يحفظ' : 'حفظ البيانات'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _resetPassword,
                        icon: const Icon(Icons.lock_reset),
                        label: const Text('إعادة تعيين كلمة السر'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller,
      {TextInputType keyboard = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
