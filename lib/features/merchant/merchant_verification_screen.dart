// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_info.dart';
import '../../core/app_navigator.dart';
import '../../services/receipt_storage_service.dart';
import '../../widgets/glass_app_bar.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/modal_utils.dart';
import '../../widgets/snow_background.dart';
import '../../widgets/top_snackbar.dart';
import '../../utils/whatsapp_utils.dart';

enum _MerchantIdImageSide { front, back }

enum _MerchantIdImageSourceOption { camera, files }

class MerchantVerificationScreen extends StatefulWidget {
  const MerchantVerificationScreen({super.key});

  @override
  State<MerchantVerificationScreen> createState() =>
      _MerchantVerificationScreenState();
}

class _MerchantVerificationScreenState
    extends State<MerchantVerificationScreen> {
  final TextEditingController _fullNameCtrl = TextEditingController();
  final TextEditingController _cardContactWhatsappCtrl =
      TextEditingController();
  final TextEditingController _cardRequirementNoteCtrl =
      TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  DocumentReference<Map<String, dynamic>>? _userRef;

  bool _loading = true;
  bool _submitting = false;
  bool _nameEdited = false;
  String _whatsapp = '';

  String _verificationStatus = 'not_submitted';
  String _verificationNote = '';
  bool? _hasCryptoCard;
  bool _consentDataCollection = false;

  Uint8List? _frontBytes;
  Uint8List? _backBytes;
  String _frontUrl = '';
  String _backUrl = '';

  bool get _cameraCaptureSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void initState() {
    super.initState();
    _fullNameCtrl.addListener(() {
      _nameEdited = true;
    });
    unawaited(_loadCurrentUser());
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _fullNameCtrl.dispose();
    _cardContactWhatsappCtrl.dispose();
    _cardRequirementNoteCtrl.dispose();
    super.dispose();
  }

  String _normalizedVerificationStatus(dynamic raw) {
    final status = (raw ?? '').toString().trim().toLowerCase();
    if (status == 'approved') return 'approved';
    if (status == 'pending') return 'pending';
    if (status == 'rejected') return 'rejected';
    return 'not_submitted';
  }

  bool _isMerchantVerified(Map<String, dynamic> data) {
    final status = _normalizedVerificationStatus(
      data['merchant_verification_status'],
    );
    return data['merchant_verified'] == true || status == 'approved';
  }

  String _normalizeWhatsapp(String value) {
    return WhatsappUtils.normalizeEgyptianWhatsapp(value);
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = (prefs.getString('user_uid') ?? '').trim();
    final email = (prefs.getString('user_email') ?? '').trim().toLowerCase();
    final wa = _normalizeWhatsapp(prefs.getString('user_whatsapp') ?? '');
    _whatsapp = wa;

    final users = FirebaseFirestore.instance.collection('users');
    DocumentReference<Map<String, dynamic>>? ref;

    if (uid.isNotEmpty) {
      final uidRef = users.doc(uid);
      final uidSnap = await uidRef.get();
      if (uidSnap.exists) {
        ref = uidRef;
      } else {
        final byUid = await users.where('uid', isEqualTo: uid).limit(1).get();
        if (byUid.docs.isNotEmpty) {
          ref = byUid.docs.first.reference;
        }
      }
    }

    if (ref == null && email.isNotEmpty) {
      final byEmail = await users
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (byEmail.docs.isNotEmpty) {
        ref = byEmail.docs.first.reference;
      }
    }

    if (ref == null && wa.isNotEmpty) {
      final byWa = await users.where('whatsapp', isEqualTo: wa).limit(1).get();
      if (byWa.docs.isNotEmpty) {
        ref = byWa.docs.first.reference;
      } else {
        final waRef = users.doc(wa);
        final waSnap = await waRef.get();
        if (waSnap.exists) {
          ref = waRef;
        }
      }
    }

    if (ref == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    _userRef = ref;
    _userSub?.cancel();
    _userSub = ref.snapshots().listen(_applyUserSnapshot);
    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _applyUserSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? <String, dynamic>{};
    final resolvedName = (data['merchant_id_full_name'] ?? data['name'] ?? '')
        .toString()
        .trim();
    final status = _isMerchantVerified(data)
        ? 'approved'
        : _normalizedVerificationStatus(data['merchant_verification_status']);

    if (!mounted) return;
    setState(() {
      _verificationStatus = status;
      _verificationNote = (data['merchant_verification_note'] ?? '')
          .toString()
          .trim();
      _frontUrl = (data['merchant_id_front_url'] ?? '').toString().trim();
      _backUrl = (data['merchant_id_back_url'] ?? '').toString().trim();
      _whatsapp = _normalizeWhatsapp(
        (data['whatsapp'] ?? _whatsapp).toString().trim(),
      );
      final hasCard = data['merchant_has_crypto_card'];
      _hasCryptoCard = hasCard is bool ? hasCard : _hasCryptoCard;
      _consentDataCollection = data['merchant_data_collection_consent'] == true;
      if (_cardContactWhatsappCtrl.text.trim().isEmpty) {
        _cardContactWhatsappCtrl.text = _normalizeWhatsapp(
          (data['merchant_card_contact_whatsapp'] ?? '').toString(),
        );
      }
      if (_cardRequirementNoteCtrl.text.trim().isEmpty) {
        _cardRequirementNoteCtrl.text =
            (data['merchant_card_requirement_note'] ?? '').toString().trim();
      }
      if (!_nameEdited && resolvedName.isNotEmpty) {
        _fullNameCtrl.text = resolvedName;
      }
    });
  }

  Future<_MerchantIdImageSourceOption?> _promptImageSource({
    required String title,
  }) {
    if (!_cameraCaptureSupported) {
      return Future.value(_MerchantIdImageSourceOption.files);
    }
    return showLockedDialog<_MerchantIdImageSourceOption>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('التقاط بالكاميرا'),
              onTap: () =>
                  Navigator.pop(ctx, _MerchantIdImageSourceOption.camera),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_rounded),
              title: const Text('اختيار من الملفات'),
              onTap: () =>
                  Navigator.pop(ctx, _MerchantIdImageSourceOption.files),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(_MerchantIdImageSide side) async {
    final source = await _promptImageSource(
      title: side == _MerchantIdImageSide.front
          ? 'صورة البطاقة (الوجه)'
          : 'صورة البطاقة (الظهر)',
    );
    if (source == null || !mounted) return;

    Uint8List? bytes;
    if (source == _MerchantIdImageSourceOption.camera) {
      final cameraAllowed = await _ensureCameraPermission();
      if (!cameraAllowed || !mounted) return;
      try {
        final picked = await _imagePicker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.rear,
          imageQuality: 92,
          maxWidth: 2200,
        );
        if (picked != null) {
          bytes = await picked.readAsBytes();
        }
      } catch (_) {
        if (mounted) {
          TopSnackBar.show(
            context,
            'تعذر تشغيل الكاميرا حالياً',
            icon: Icons.error_outline,
            backgroundColor: Colors.red,
          );
        }
        return;
      }
    } else {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp', 'heic'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      bytes = result.files.first.bytes;
    }

    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      TopSnackBar.show(
        context,
        'تعذر قراءة الصورة المختارة',
        icon: Icons.error,
        backgroundColor: Colors.red,
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      if (side == _MerchantIdImageSide.front) {
        _frontBytes = bytes;
      } else {
        _backBytes = bytes;
      }
    });
  }

  Future<bool> _ensureCameraPermission() async {
    if (kIsWeb || !_cameraCaptureSupported) return true;
    final status = await Permission.camera.request();
    if (status.isGranted) return true;
    if (!mounted) return false;
    TopSnackBar.show(
      context,
      status.isPermanentlyDenied
          ? 'اسمح بإذن الكاميرا من إعدادات الجهاز'
          : 'يلزم إذن الكاميرا لالتقاط صورة البطاقة',
      icon: Icons.camera_alt_outlined,
      backgroundColor: Colors.orange,
    );
    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
    return false;
  }

  Future<void> _openInAppSubscriptionSupport() async {
    if (!WhatsappUtils.isValidEgyptianWhatsapp(_whatsapp)) {
      TopSnackBar.show(
        context,
        'أكمل رقم الواتساب الصحيح أولاً قبل فتح دعم الاشتراك.',
        icon: Icons.info_outline,
        backgroundColor: Colors.orange,
      );
      return;
    }

    final fallbackName = _fullNameCtrl.text.trim().isNotEmpty
        ? _fullNameCtrl.text.trim()
        : 'تاجر';
    if (!mounted) return;
    AppNavigator.pushNamed(
      context,
      '/support_inquiry',
      arguments: <String, dynamic>{
        'name': fallbackName,
        'whatsapp': _whatsapp,
        'merchant_support': true,
      },
    );
  }

  Future<ReceiptUploadResult?> _uploadIdImage({
    required Uint8List bytes,
    required _MerchantIdImageSide side,
  }) async {
    final suffix = side == _MerchantIdImageSide.front ? 'front' : 'back';
    final upload = await ReceiptStorageService.uploadWithPath(
      bytes: bytes,
      whatsapp: _whatsapp,
      orderId: 'merchant_id_${suffix}_${DateTime.now().millisecondsSinceEpoch}',
    );
    return upload;
  }

  String _statusTitle() {
    switch (_verificationStatus) {
      case 'approved':
        return 'حساب التاجر موثق ✅';
      case 'pending':
        return 'طلب التوثيق قيد المراجعة ⏳';
      case 'rejected':
        return 'تم رفض التوثيق ❌';
      default:
        return 'توثيق التاجر مطلوب';
    }
  }

  String _statusDescription() {
    switch (_verificationStatus) {
      case 'approved':
        return 'يمكنك استخدام واجهة التاجر بشكل كامل.';
      case 'pending':
        return 'مدة المراجعة من ساعة إلى 24 ساعة. سيتم تفعيل الحساب بعد موافقة الأدمن.';
      case 'rejected':
        if (_verificationNote.isNotEmpty) {
          return 'سبب الرفض: $_verificationNote';
        }
        return 'عدّل البيانات وارفع صور البطاقة مرة أخرى.';
      default:
        return 'اكتب اسمك بالكامل كما في البطاقة وارفع صورة الوجه والظهر، ثم أكمل أسئلة التفعيل.';
    }
  }

  Color _statusColor(BuildContext context) {
    switch (_verificationStatus) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Theme.of(context).colorScheme.error;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  bool get _canEditVerification {
    return _verificationStatus == 'not_submitted' ||
        _verificationStatus == 'rejected';
  }

  Future<void> _submitVerification() async {
    final ref = _userRef;
    if (ref == null) {
      TopSnackBar.show(
        context,
        'تعذر العثور على حسابك، أعد تسجيل الدخول.',
        icon: Icons.error,
        backgroundColor: Colors.red,
      );
      return;
    }

    final fullName = _fullNameCtrl.text.trim();
    if (fullName.length < 8 || !fullName.contains(' ')) {
      TopSnackBar.show(
        context,
        'اكتب الاسم بالكامل كما في البطاقة (اسمين على الأقل).',
        icon: Icons.info_outline,
        backgroundColor: Colors.orange,
      );
      return;
    }

    final hasFront = _frontBytes != null || _frontUrl.trim().isNotEmpty;
    final hasBack = _backBytes != null || _backUrl.trim().isNotEmpty;
    if (!hasFront || !hasBack) {
      TopSnackBar.show(
        context,
        'ارفع صورة البطاقة (وش + ظهر) قبل الإرسال.',
        icon: Icons.badge_outlined,
        backgroundColor: Colors.orange,
      );
      return;
    }

    if (_hasCryptoCard == null) {
      TopSnackBar.show(
        context,
        'حدد هل تملك بطاقة RedotPay أو بطاقة تعمل بالعملات الرقمية.',
        icon: Icons.info_outline,
        backgroundColor: Colors.orange,
      );
      return;
    }

    if (!_consentDataCollection) {
      TopSnackBar.show(
        context,
        'يجب الموافقة على جمع البيانات لضمان حقوق المستخدمين.',
        icon: Icons.privacy_tip_outlined,
        backgroundColor: Colors.orange,
      );
      return;
    }

    if (!WhatsappUtils.isValidEgyptianWhatsapp(_whatsapp)) {
      TopSnackBar.show(
        context,
        'رقم الواتساب غير صحيح. يجب أن يكون 11 رقم ويبدأ بـ 01.',
        icon: Icons.phone_outlined,
        backgroundColor: Colors.orange,
      );
      return;
    }

    final merchantCardContact = _normalizeWhatsapp(
      _cardContactWhatsappCtrl.text,
    );
    final merchantCardNote = _cardRequirementNoteCtrl.text.trim();
    if (_hasCryptoCard == false) {
      if (merchantCardContact.isEmpty) {
        TopSnackBar.show(
          context,
          'اكتب رقم واتساب للتواصل بخصوص متطلبات الفيزا.',
          icon: Icons.chat_outlined,
          backgroundColor: Colors.orange,
        );
        return;
      }
      if (!WhatsappUtils.isValidEgyptianWhatsapp(merchantCardContact)) {
        TopSnackBar.show(
          context,
          'رقم واتساب التواصل يجب أن يكون 11 رقم ويبدأ بـ 01.',
          icon: Icons.phone_outlined,
          backgroundColor: Colors.orange,
        );
        return;
      }
      if (merchantCardNote.length < 8) {
        TopSnackBar.show(
          context,
          'اكتب شرح المطلوب في خانة المتابعة (8 أحرف على الأقل).',
          icon: Icons.edit_note_outlined,
          backgroundColor: Colors.orange,
        );
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      ReceiptUploadResult? frontUpload;
      ReceiptUploadResult? backUpload;
      if (_frontBytes != null) {
        frontUpload = await _uploadIdImage(
          bytes: _frontBytes!,
          side: _MerchantIdImageSide.front,
        );
      }
      if (_backBytes != null) {
        backUpload = await _uploadIdImage(
          bytes: _backBytes!,
          side: _MerchantIdImageSide.back,
        );
      }

      if (_frontBytes != null && frontUpload == null) {
        throw StateError('front-upload-failed');
      }
      if (_backBytes != null && backUpload == null) {
        throw StateError('back-upload-failed');
      }

      final update = <String, dynamic>{
        'is_merchant': true,
        'merchant_whatsapp': _whatsapp,
        'merchant_active': false,
        'merchant_billing_mode': 'monthly_fixed',
        'merchant_monthly_fee': 750,
        'merchant_revenue_percent': FieldValue.delete(),
        'merchant_verification_status': 'pending',
        'merchant_verified': false,
        'merchant_verification_note': '',
        'merchant_verification_submitted_at': FieldValue.serverTimestamp(),
        'merchant_verification_reviewed_at': FieldValue.delete(),
        'merchant_verification_rejected_at': FieldValue.delete(),
        'merchant_verified_at': FieldValue.delete(),
        'merchant_id_full_name': fullName,
        'merchant_trial_bonus_usd': FieldValue.delete(),
        'merchant_trial_bonus_note': FieldValue.delete(),
        'merchant_has_crypto_card': _hasCryptoCard,
        'merchant_card_contact_whatsapp': _hasCryptoCard == false
            ? merchantCardContact
            : FieldValue.delete(),
        'merchant_card_requirement_note': _hasCryptoCard == false
            ? merchantCardNote
            : FieldValue.delete(),
        'merchant_data_collection_consent': _consentDataCollection,
        'merchant_subscription_payment_channel': 'in_app_support_chat',
        'merchant_support_whatsapp': FieldValue.delete(),
        'merchant_payment_proof_in_app': true,
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (frontUpload != null) {
        update['merchant_id_front_url'] = frontUpload.url;
        update['merchant_id_front_path'] = frontUpload.path;
      } else {
        update['merchant_id_front_url'] = _frontUrl;
      }

      if (backUpload != null) {
        update['merchant_id_back_url'] = backUpload.url;
        update['merchant_id_back_path'] = backUpload.path;
      } else {
        update['merchant_id_back_url'] = _backUrl;
      }

      await ref.set(update, SetOptions(merge: true));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_merchant', false);
      AppInfo.isMerchantApp = false;

      if (!mounted) return;
      setState(() {
        _verificationStatus = 'pending';
        _frontBytes = null;
        _backBytes = null;
      });
      TopSnackBar.show(
        context,
        'تم إرسال طلب التوثيق. المراجعة من ساعة إلى 24 ساعة. سداد الاشتراك يتم عبر دعم التطبيق الداخلي.',
        icon: Icons.check_circle,
        backgroundColor: Colors.green,
      );
    } catch (e) {
      if (!mounted) return;
      TopSnackBar.show(
        context,
        'تعذر إرسال طلب التوثيق حالياً',
        icon: Icons.error_outline,
        backgroundColor: Colors.red,
      );
      debugPrint('merchant verification submit failed: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _buildImageCard({
    required String title,
    required _MerchantIdImageSide side,
    required Uint8List? localBytes,
    required String remoteUrl,
  }) {
    final hasRemote = remoteUrl.trim().isNotEmpty;
    final hasImage = localBytes != null || hasRemote;
    final imageWidget = localBytes != null
        ? Image.memory(localBytes, fit: BoxFit.cover)
        : hasRemote
        ? Image.network(remoteUrl, fit: BoxFit.cover)
        : const Icon(Icons.badge_outlined, size: 50);

    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: double.infinity,
              height: 170,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.black.withAlpha(20)),
                child: hasImage
                    ? imageWidget
                    : const Center(child: Icon(Icons.image_not_supported)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _submitting ? null : () => _pickImage(side),
              icon: const Icon(Icons.upload_file),
              label: Text(
                hasImage ? 'تحديث الصورة' : 'رفع الصورة',
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(context);
    return Scaffold(
      appBar: const GlassAppBar(title: Text('توثيق حساب التاجر')),
      body: Stack(
        children: [
          const SnowBackground(),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            ListView(
              padding: const EdgeInsets.all(14),
              children: [
                GlassCard(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.all(14),
                  borderColor: statusColor.withAlpha(130),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.verified_user, color: statusColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _statusTitle(),
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _statusDescription(),
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextButton.icon(
                        onPressed: _openInAppSubscriptionSupport,
                        icon: const Icon(Icons.support_agent),
                        label: const Text('التواصل مع دعم الاشتراك'),
                      ),
                    ],
                  ),
                ),
                if (_verificationStatus == 'pending') ...[
                  const SizedBox(height: 12),
                  const GlassCard(
                    margin: EdgeInsets.zero,
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'تم إرسال الطلب بنجاح. حالياً لا تحتاج لإعادة رفع البيانات حتى انتهاء المراجعة.',
                      style: TextStyle(fontFamily: 'Cairo', height: 1.4),
                    ),
                  ),
                ] else if (_canEditVerification) ...[
                  const SizedBox(height: 12),
                  GlassCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'الاسم الكامل كما في البطاقة',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _fullNameCtrl,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            hintText: 'الاسم الرباعي كما في البطاقة',
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'مهم: أي اختلاف في الاسم أو الصور قد يؤدي إلى رفض التوثيق.',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '1) هل تملك RedotPay أو أي فيزا تعمل بالعملات الرقمية؟',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('نعم'),
                              selected: _hasCryptoCard == true,
                              onSelected: (_) {
                                setState(() => _hasCryptoCard = true);
                              },
                            ),
                            ChoiceChip(
                              label: const Text('لا'),
                              selected: _hasCryptoCard == false,
                              onSelected: (_) {
                                setState(() => _hasCryptoCard = false);
                              },
                            ),
                          ],
                        ),
                        if (_hasCryptoCard == false) ...[
                          const SizedBox(height: 8),
                          Text(
                            'سيتم التواصل معك لتوضيح المطلوب.',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _cardContactWhatsappCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'رقم واتساب للتواصل',
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _cardRequirementNoteCtrl,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'اشرح المطلوب أو تفاصيل حالتك',
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        CheckboxListTile(
                          value: _consentDataCollection,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (value) {
                            setState(() {
                              _consentDataCollection = value == true;
                            });
                          },
                          title: const Text(
                            '2) أوافق على جمع بياناتي لضمان حقوق المستخدمين',
                            style: TextStyle(fontFamily: 'Cairo'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildImageCard(
                    title: 'صورة البطاقة (الوش)',
                    side: _MerchantIdImageSide.front,
                    localBytes: _frontBytes,
                    remoteUrl: _frontUrl,
                  ),
                  const SizedBox(height: 10),
                  _buildImageCard(
                    title: 'صورة البطاقة (الظهر)',
                    side: _MerchantIdImageSide.back,
                    localBytes: _backBytes,
                    remoteUrl: _backUrl,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : _submitVerification,
                      icon: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        _submitting ? 'جارٍ الإرسال...' : 'إرسال طلب التوثيق',
                        style: const TextStyle(fontFamily: 'Cairo'),
                      ),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}
