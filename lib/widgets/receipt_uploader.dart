// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../core/tt_colors.dart';
import '../utils/url_sanitizer.dart';
import '../services/receipt_storage_service.dart';
import '../widgets/top_snackbar.dart';

class ReceiptUploader extends StatefulWidget {
  // EN: Creates Function.
  // AR: ينشئ Function.
  final void Function(String url) onUploaded;
  final String? whatsapp;

  // EN: Creates ReceiptUploader.
  // AR: ينشئ ReceiptUploader.
  const ReceiptUploader({
    super.key,
    required this.onUploaded,
    this.whatsapp,
  });

  // EN: Creates state object.
  // AR: تنشئ كائن الحالة.
  @override
  State<ReceiptUploader> createState() => _ReceiptUploaderState();
}

class _ReceiptUploaderState extends State<ReceiptUploader> {
  bool _uploading = false;
  String? _uploadedUrl;

  // EN: Handles pick And Upload.
  // AR: تتعامل مع pick And Upload.
  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp', 'heic'],
      withData: true,
      dialogTitle: 'اختر صورة من الملفات',
    );

    if (result == null || result.files.single.bytes == null) return;

    final Uint8List bytes = result.files.single.bytes!;

    setState(() => _uploading = true);

    final url = await ReceiptStorageService.upload(
      bytes: bytes,
      whatsapp: widget.whatsapp ?? '',
    );
    if (url != null) {
      setState(() => _uploadedUrl = url);
      widget.onUploaded(url);
      _showMsg('تم رفع الإيصال بنجاح');
    } else {
      _showMsg('فشل رفع الصورة');
    }

    setState(() => _uploading = false);
  }

  // EN: Builds widget UI.
  // AR: تبني واجهة الودجت.
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'إيصال الدفع',
          style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
        ),

        const SizedBox(height: 8),

        if (_uploadedUrl != null)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: TTColors.primaryCyan),
              image: DecorationImage(
                image: NetworkImage(ensureHttps(_uploadedUrl!)),
                fit: BoxFit.cover,
              ),
            ),
          ),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _uploading ? null : _pickAndUpload,
            icon: _uploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload),
            label: Text(
              _uploadedUrl == null ? 'رفع صورة الإيصال' : 'إعادة رفع صورة',
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        ),
      ],
    );
  }

  // EN: Shows Msg.
  // AR: تعرض Msg.
  void _showMsg(String msg) {
    if (!mounted) return;
    TopSnackBar.show(
      context,
      msg,
      backgroundColor: TTColors.cardBg,
      textColor: TTColors.textWhite,
      icon: Icons.info,
    );
  }
}
