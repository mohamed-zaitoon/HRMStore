// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/tt_colors.dart';
import '../services/order_chat_service.dart';
import '../services/receipt_storage_service.dart';
import '../utils/url_sanitizer.dart';
import 'top_snackbar.dart';

enum _AttachmentAction { image, link }

class OrderChatPanel extends StatefulWidget {
  final String orderId;
  final bool isAdmin;
  final bool isMerchant;
  final String userDisplayName;
  final String adminDisplayName;
  final double maxHeight;
  final bool fullScreen;
  final bool chatEnabled;
  final String? disabledHint;
  final String userWhatsapp;

  // EN: Creates OrderChatPanel.
  // AR: ينشئ لوحة محادثة الطلب.
  const OrderChatPanel({
    super.key,
    required this.orderId,
    required this.isAdmin,
    this.isMerchant = false,
    required this.userDisplayName,
    this.adminDisplayName = '',
    this.maxHeight = 220,
    this.fullScreen = false,
    this.chatEnabled = true,
    this.disabledHint,
    this.userWhatsapp = '',
  });

  @override
  State<OrderChatPanel> createState() => _OrderChatPanelState();
}

class _OrderChatPanelState extends State<OrderChatPanel> {
  final TextEditingController _messageCtrl = TextEditingController();
  bool _isSending = false;
  bool _isUploadingAttachment = false;
  Timer? _attachmentExpiryTicker;

  CollectionReference<Map<String, dynamic>> get _messagesRef {
    return FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .collection('chat_messages');
  }

  @override
  void initState() {
    super.initState();
    _attachmentExpiryTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _attachmentExpiryTicker?.cancel();
    _messageCtrl.dispose();
    super.dispose();
  }

  bool _isMine(Map<String, dynamic> data) {
    final role = (data['sender_role'] ?? '').toString().trim();
    if (widget.isAdmin) return role == 'admin';
    if (widget.isMerchant) return role == 'merchant';
    return role == 'user';
  }

  String _senderLabel(Map<String, dynamic> data) {
    final role = (data['sender_role'] ?? '').toString().trim();
    final senderName = (data['sender_name'] ?? '').toString().trim();

    if (role == 'system') return '(رسالة آليه)';

    if (widget.isAdmin) {
      if (role == 'user') {
        final userName = widget.userDisplayName.trim();
        if (userName.isNotEmpty) return userName;
        if (senderName.isNotEmpty) return senderName;
        return 'المستخدم';
      }
      return 'أنت';
    }

    if (widget.isMerchant) {
      if (role == 'user') {
        final userName = widget.userDisplayName.trim();
        if (userName.isNotEmpty) return userName;
        if (senderName.isNotEmpty) return senderName;
        return 'المستخدم';
      }
      if (role == 'merchant') return 'أنت';
      if (role == 'admin') return 'الدعم';
    }

    if (role == 'merchant') return 'التاجر';
    if (role == 'admin') return 'الدعم';
    return 'أنت';
  }

  Timestamp? _timestampFrom(Map<String, dynamic> data) {
    final direct = data['created_at'];
    if (direct is Timestamp) return direct;
    final fallback = data['created_at_client'];
    if (fallback is Timestamp) return fallback;
    return null;
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate().toLocal();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _normalizeArabicDigits(String value) {
    if (value.isEmpty) return '';
    final normalized = StringBuffer();
    for (final rune in value.runes) {
      if (rune >= 0x0660 && rune <= 0x0669) {
        normalized.writeCharCode(0x30 + (rune - 0x0660));
        continue;
      }
      if (rune >= 0x06F0 && rune <= 0x06F9) {
        normalized.writeCharCode(0x30 + (rune - 0x06F0));
        continue;
      }
      normalized.writeCharCode(rune);
    }
    return normalized.toString();
  }

  List<String> _extractCopyableNumbers(String input) {
    if (input.trim().isEmpty) return const <String>[];
    final numberPattern = RegExp(
      r'(?:(?:\+)?[0-9٠-٩][0-9٠-٩\-\s]{4,}[0-9٠-٩])',
    );
    final seen = <String>{};
    final numbers = <String>[];
    for (final match in numberPattern.allMatches(input)) {
      var candidate = _normalizeArabicDigits(match.group(0) ?? '');
      candidate = candidate.replaceAll(RegExp(r'[\u200E\u200F\s\-]'), '');
      if (candidate.isEmpty) continue;
      if (candidate.startsWith('+')) {
        candidate =
            '+${candidate.substring(1).replaceAll(RegExp(r'[^0-9]'), '')}';
      } else {
        candidate = candidate.replaceAll(RegExp(r'[^0-9]'), '');
      }
      final digitsOnly = candidate.replaceAll('+', '');
      if (digitsOnly.length < 6) continue;
      if (!seen.add(candidate)) continue;
      numbers.add(candidate);
      if (numbers.length >= 5) break;
    }
    return numbers;
  }

  String? _extractFirstUrl(String input) {
    if (input.trim().isEmpty) return null;
    final patterns = [
      RegExp(r'(https?:\/\/\S+)', caseSensitive: false),
      RegExp(r'instapay\.me\/\S+', caseSensitive: false),
      RegExp(r'\b[\w\.\-]+@instapay\b', caseSensitive: false),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(input);
      if (match != null) {
        final url = match.group(0);
        if (url != null && url.trim().isNotEmpty) return url;
      }
    }
    return null;
  }

  Future<void> _copyNumber(String number) async {
    final value = number.trim();
    if (value.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    TopSnackBar.show(
      context,
      'نسخ الرقم: $value',
      backgroundColor: TTColors.cardBg,
      textColor: TTColors.textWhite,
      icon: Icons.copy_rounded,
    );
  }

  Future<void> _sendMessage({
    String text = '',
    String attachmentType = '',
    String attachmentUrl = '',
    String attachmentPath = '',
    String attachmentLabel = '',
    Duration? attachmentExpiresIn,
    bool clearInput = false,
  }) async {
    if (!widget.chatEnabled) return;
    final message = text.trim();
    final safeAttachmentType = attachmentType.trim();
    final safeAttachmentUrl = attachmentUrl.trim();
    final safeAttachmentPath = attachmentPath.trim();
    final safeAttachmentLabel = attachmentLabel.trim();
    if ((message.isEmpty && safeAttachmentUrl.isEmpty) || _isSending) return;

    setState(() => _isSending = true);
    try {
      String senderRole;
      String senderName;
      if (widget.isAdmin) {
        senderRole = 'admin';
        senderName = '';
      } else if (widget.isMerchant) {
        senderRole = 'merchant';
        senderName = widget.adminDisplayName.trim().isEmpty
            ? 'التاجر'
            : widget.adminDisplayName.trim();
      } else {
        senderRole = 'user';
        senderName = widget.userDisplayName.trim().isEmpty
            ? 'المستخدم'
            : widget.userDisplayName.trim();
      }

      final expiresAt = attachmentExpiresIn == null
          ? null
          : Timestamp.fromDate(DateTime.now().add(attachmentExpiresIn));

      await OrderChatService.addMessage(
        orderId: widget.orderId,
        senderRole: senderRole,
        senderName: senderName,
        text: message,
        attachmentType: safeAttachmentType,
        attachmentUrl: safeAttachmentUrl,
        attachmentPath: safeAttachmentPath,
        attachmentLabel: safeAttachmentLabel,
        attachmentExpiresAt: expiresAt,
        recipientUserWhatsapp: widget.userWhatsapp,
      );

      if (clearInput) _messageCtrl.clear();
    } catch (_) {
      if (!mounted) return;
      TopSnackBar.show(
        context,
        'تعذر إرسال الرسالة الآن',
        backgroundColor: Colors.red,
        textColor: Colors.white,
        icon: Icons.error_outline,
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendTextMessage() async {
    final message = _messageCtrl.text.trim();
    await _sendMessage(text: message, clearInput: true);
  }

  Future<void> _promptAndSendLinkAttachment() async {
    if (!widget.isAdmin && !widget.isMerchant) return;
    if (!widget.chatEnabled || _isUploadingAttachment) return;
    final linkCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Theme.of(ctx).colorScheme.surface,
          title: const Text(
            'إرسال رابط',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: linkCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'الرابط',
                  hintText: 'https://...',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteCtrl,
                textInputAction: TextInputAction.done,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'ملاحظة (اختياري)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                final link = linkCtrl.text.trim();
                if (link.isEmpty) return;
                Navigator.pop(ctx, (link, noteCtrl.text.trim()));
              },
              child: const Text('إرسال'),
            ),
          ],
        );
      },
    );

    if (!mounted || result == null) return;
    final link = ensureHttps(result.$1);
    final note = result.$2;
    await _sendMessage(
      text: note,
      attachmentType: 'link',
      attachmentUrl: link,
      attachmentLabel: 'رابط',
    );
  }

  Future<void> _pickAndSendImageAttachment() async {
    if (!widget.chatEnabled || _isUploadingAttachment) return;

    setState(() => _isUploadingAttachment = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp', 'heic'],
        withData: true,
        dialogTitle: 'اختر صورة للإرسال',
      );
      if (!mounted || picked == null || picked.files.isEmpty) return;

      final Uint8List? bytes = picked.files.first.bytes;
      if (bytes == null || bytes.isEmpty) {
        if (!mounted) return;
        TopSnackBar.show(
          context,
          'تعذر قراءة الصورة',
          backgroundColor: Colors.red,
          textColor: Colors.white,
          icon: Icons.error_outline,
        );
        return;
      }

      if (!mounted) return;
      TopSnackBar.show(
        context,
        'جاري رفع الصورة...',
        backgroundColor: TTColors.cardBg,
        textColor: TTColors.textWhite,
        icon: Icons.cloud_upload,
        duration: null,
      );

      final upload = await ReceiptStorageService.uploadWithPath(
        bytes: bytes,
        whatsapp: widget.userWhatsapp,
        orderId:
            'chat_${widget.orderId}_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (!mounted) return;
      TopSnackBar.dismiss();
      if (upload == null) {
        TopSnackBar.show(
          context,
          'فشل رفع الصورة',
          backgroundColor: Colors.red,
          textColor: Colors.white,
          icon: Icons.error_outline,
        );
        return;
      }

      await _sendMessage(
        attachmentType: 'image',
        attachmentUrl: upload.url,
        attachmentPath: upload.path,
        attachmentLabel: 'صورة',
      );
    } catch (_) {
      if (!mounted) return;
      TopSnackBar.dismiss();
      TopSnackBar.show(
        context,
        'تعذر إرسال الصورة الآن',
        backgroundColor: Colors.red,
        textColor: Colors.white,
        icon: Icons.error_outline,
      );
    } finally {
      if (mounted) setState(() => _isUploadingAttachment = false);
    }
  }

  Future<void> _openLink(String raw) async {
    final url = ensureHttps(raw.trim());
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      TopSnackBar.show(
        context,
        'تعذر فتح الرابط',
        backgroundColor: Colors.red,
        textColor: Colors.white,
        icon: Icons.error_outline,
      );
    }
  }

  Future<void> _showImagePreview(String url, {String? title}) async {
    if (!mounted) return;
    final safeUrl = ensureHttps(url.trim());
    await showDialog(
      context: context,
      builder: (ctx) {
        final size = MediaQuery.of(ctx).size;
        final colorScheme = Theme.of(ctx).colorScheme;
        return Dialog(
          backgroundColor: colorScheme.surface,
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 640,
              maxHeight: size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.image, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title?.trim().isNotEmpty == true
                              ? title!.trim()
                              : 'صورة مرفقة',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                        tooltip: "إغلاق",
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          safeUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: progress.expectedTotalBytes == null
                                    ? null
                                    : progress.cumulativeBytesLoaded /
                                          progress.expectedTotalBytes!,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Text(
                                'تعذر تحميل الصورة',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isAttachmentExpired(Map<String, dynamic> data) {
    final expires = data['attachment_expires_at'];
    if (expires is! Timestamp) return false;
    return !DateTime.now().isBefore(expires.toDate());
  }

  int? _attachmentRemainingSeconds(Map<String, dynamic> data) {
    final expires = data['attachment_expires_at'];
    if (expires is! Timestamp) return null;
    final remaining = expires.toDate().difference(DateTime.now()).inSeconds;
    if (remaining <= 0) return 0;
    return remaining;
  }

  Widget _buildMessageTile(
    BuildContext context,
    Map<String, dynamic> data, {
    required bool isMine,
  }) {
    final text = (data['text'] ?? '').toString().trim();
    final attachmentType = (data['attachment_type'] ?? '').toString().trim();
    final attachmentUrl = (data['attachment_url'] ?? '').toString().trim();
    final attachmentLabel = (data['attachment_label'] ?? '').toString().trim();
    final hasAttachment = attachmentUrl.isNotEmpty;
    final attachmentExpired = hasAttachment && _isAttachmentExpired(data);
    final attachmentRemaining = hasAttachment && !attachmentExpired
        ? _attachmentRemainingSeconds(data)
        : null;
    final inlineLink =
        attachmentType == 'link' ? null : _extractFirstUrl(text);
    final sender = _senderLabel(data);
    final time = _formatTime(_timestampFrom(data));
    final colorScheme = Theme.of(context).colorScheme;
    final copySource = StringBuffer(text);
    if (hasAttachment && attachmentType == 'link') {
      if (copySource.isNotEmpty) copySource.write('\n');
      copySource.write(attachmentUrl);
    }
    final copyableNumbers = _extractCopyableNumbers(copySource.toString());
    final primaryCopyableNumber = copyableNumbers.isNotEmpty
        ? copyableNumbers.first
        : null;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: GestureDetector(
          onLongPress: copyableNumbers.isEmpty
              ? null
              : () => _copyNumber(copyableNumbers.first),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isMine
                  ? colorScheme.primary.withAlpha(48)
                  : TTColors.cardBg.withAlpha(190),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isMine
                    ? colorScheme.primary.withAlpha(110)
                    : colorScheme.outline.withAlpha(80),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sender,
                  style: TextStyle(
                    color: isMine
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 13,
                    fontFamily: 'Cairo',
                  ),
                ),
                if (inlineLink != null) ...[
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: () => _openLink(inlineLink),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text(
                      'فتح الرابط',
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                  ),
                ],
                if (primaryCopyableNumber != null) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () => _copyNumber(primaryCopyableNumber),
                      icon: const Icon(Icons.copy_rounded, size: 14),
                      label: const Text(
                        'نسخ الرقم',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 0,
                        ),
                        minimumSize: const Size(0, 28),
                      ),
                    ),
                  ),
                ],
                if (text.isNotEmpty && hasAttachment) const SizedBox(height: 6),
                if (hasAttachment && attachmentExpired) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.withAlpha(90)),
                    ),
                    child: Text(
                      'انتهت صلاحية هذا المرفق.',
                      style: TextStyle(
                        color: Colors.orange.shade300,
                        fontSize: 12,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                ],
                if (hasAttachment &&
                    !attachmentExpired &&
                    attachmentRemaining != null) ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: colorScheme.primary.withAlpha(70),
                      ),
                    ),
                    child: Text(
                      'متبقي ${attachmentRemaining.toString()} ثانية',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontSize: 12,
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                if (hasAttachment &&
                    !attachmentExpired &&
                    attachmentType == 'image')
                  InkWell(
                    onTap: () => _showImagePreview(
                      attachmentUrl,
                      title: attachmentLabel.isEmpty ? null : attachmentLabel,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxHeight: 220,
                          minWidth: 120,
                        ),
                        child: Image.network(
                          ensureHttps(attachmentUrl),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'تعذر تحميل الصورة',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                if (hasAttachment &&
                    !attachmentExpired &&
                    attachmentType == 'link')
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: OutlinedButton.icon(
                      onPressed: () => _openLink(attachmentUrl),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: Text(
                        attachmentLabel.isEmpty
                            ? 'فتح الرابط'
                            : attachmentLabel,
                        style: const TextStyle(fontFamily: 'Cairo'),
                      ),
                    ),
                  ),
                if (hasAttachment &&
                    !attachmentExpired &&
                    attachmentType.isNotEmpty &&
                    attachmentType != 'link' &&
                    attachmentType != 'image')
                  SelectableText(
                    attachmentUrl,
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 12,
                      fontFamily: 'Cairo',
                    ),
                  ),
                if (time.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    time,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant.withAlpha(180),
                      fontSize: 10,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final messagesList = StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _messagesRef
          .orderBy('created_at_client', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'تعذر تحميل المحادثة',
              style: TextStyle(color: colorScheme.error, fontFamily: 'Cairo'),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Text(
              'ابدأ المحادثة الآن',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontFamily: 'Cairo',
              ),
            ),
          );
        }

        return ListView.builder(
          reverse: true,
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final text = (data['text'] ?? '').toString().trim();
            final attachmentUrl = (data['attachment_url'] ?? '')
                .toString()
                .trim();
            if (text.isEmpty && attachmentUrl.isEmpty) {
              return const SizedBox.shrink();
            }
            return _buildMessageTile(context, data, isMine: _isMine(data));
          },
        );
      },
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: TTColors.cardBg.withAlpha(120),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.fullScreen)
            Expanded(child: messagesList)
          else
            SizedBox(height: widget.maxHeight, child: messagesList),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageCtrl,
                  enabled: widget.chatEnabled,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendTextMessage(),
                  decoration: const InputDecoration(
                    hintText: 'اكتب رسالتك...',
                    isDense: true,
                  ),
                ),
              ),
              PopupMenuButton<_AttachmentAction>(
                tooltip: 'إرفاق',
                icon: Icon(Icons.attach_file, color: colorScheme.primary),
                enabled: widget.chatEnabled && !_isUploadingAttachment,
                onSelected: (action) {
                  if (action == _AttachmentAction.image) {
                    _pickAndSendImageAttachment();
                    return;
                  }
                  if (widget.isAdmin || widget.isMerchant) {
                    _promptAndSendLinkAttachment();
                  }
                },
                itemBuilder: (context) {
                  final items = <PopupMenuEntry<_AttachmentAction>>[
                    const PopupMenuItem<_AttachmentAction>(
                      value: _AttachmentAction.image,
                      child: Text(
                        'إرسال صورة',
                        style: TextStyle(fontFamily: 'Cairo'),
                      ),
                    ),
                  ];
                  if (widget.isAdmin || widget.isMerchant) {
                    items.add(
                      const PopupMenuItem<_AttachmentAction>(
                        value: _AttachmentAction.link,
                        child: Text(
                          'إرسال رابط',
                          style: TextStyle(fontFamily: 'Cairo'),
                        ),
                      ),
                    );
                  }
                  return items;
                },
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'إرسال',
                onPressed:
                    (_isSending ||
                        _isUploadingAttachment ||
                        !widget.chatEnabled)
                    ? null
                    : _sendTextMessage,
                icon: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.send_rounded, color: colorScheme.primary),
              ),
            ],
          ),
          if (!widget.chatEnabled) ...[
            const SizedBox(height: 6),
            Text(
              (widget.disabledHint ?? 'الشات مغلق لهذا الطلب').trim(),
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontFamily: 'Cairo',
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
