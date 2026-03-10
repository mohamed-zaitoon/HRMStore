// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/tt_colors.dart';
import '../../services/cloudflare_notify_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/glass_app_bar.dart';
import '../../widgets/snow_background.dart';
import '../../widgets/top_snackbar.dart';

class SupportInquiryScreen extends StatefulWidget {
  final String name;
  final String whatsapp;

  // EN: Creates support inquiry chat screen.
  // AR: ينشئ شاشة شات الاستفسارات.
  const SupportInquiryScreen({
    super.key,
    required this.name,
    required this.whatsapp,
  });

  @override
  State<SupportInquiryScreen> createState() => _SupportInquiryScreenState();
}

class _SupportInquiryScreenState extends State<SupportInquiryScreen> {
  final TextEditingController _messageCtrl = TextEditingController();
  bool _isSending = false;

  String get _conversationId {
    final digits = widget.whatsapp.replaceAll(RegExp(r'[^0-9]'), '').trim();
    if (digits.isNotEmpty) return digits;
    return widget.whatsapp.trim();
  }

  DocumentReference<Map<String, dynamic>> get _conversationRef {
    return FirebaseFirestore.instance
        .collection('support_conversations')
        .doc(_conversationId);
  }

  CollectionReference<Map<String, dynamic>> get _messagesRef {
    return _conversationRef.collection('messages');
  }

  @override
  void initState() {
    super.initState();
    NotificationService.listenToUserOrders(widget.whatsapp);
    unawaited(_ensureConversation());
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _ensureConversation() async {
    final now = FieldValue.serverTimestamp();
    final name = widget.name.trim();
    await _conversationRef.set({
      'user_name': name,
      'user_whatsapp': widget.whatsapp.trim(),
      'is_open': true,
      'kind': 'inquiry',
      'created_at': now,
      'updated_at': now,
      'last_sender_role': 'system',
      'last_message': 'تم فتح شات استفسار جديد.',
    }, SetOptions(merge: true));
  }

  Future<void> _sendMessage() async {
    if (_isSending) return;
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    try {
      await _messagesRef.add({
        'text': text,
        'sender_role': 'user',
        'sender_name': widget.name.trim().isEmpty
            ? 'المستخدم'
            : widget.name.trim(),
        'created_at': FieldValue.serverTimestamp(),
        'created_at_client': Timestamp.fromDate(DateTime.now()),
      });
      await _conversationRef.set({
        'updated_at': FieldValue.serverTimestamp(),
        'last_sender_role': 'user',
        'last_message': text,
        'is_open': true,
        'user_name': widget.name.trim(),
        'user_whatsapp': widget.whatsapp.trim(),
      }, SetOptions(merge: true));
      await _notifyInquiryAdminsWithRetry();
      if (!mounted) return;
      _messageCtrl.clear();
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
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _notifyInquiryAdminsWithRetry() async {
    const maxAttempts = 3;
    for (var i = 0; i < maxAttempts; i++) {
      final success =
          await CloudflareNotifyService.notifyAdminsSupportInquiryMessage(
            conversationId: _conversationId,
            userName: widget.name.trim(),
          ).timeout(const Duration(seconds: 10), onTimeout: () => false);
      if (success) return;
      if (i < maxAttempts - 1) {
        await Future<void>.delayed(Duration(milliseconds: 500 * (i + 1)));
      }
    }
  }

  String _senderLabel(Map<String, dynamic> data) {
    final role = (data['sender_role'] ?? '').toString().trim();
    if (role == 'admin') return 'الدعم';
    if (role == 'system') return '(رسالة آليه)';
    return 'أنت';
  }

  bool _isMine(Map<String, dynamic> data) {
    final role = (data['sender_role'] ?? '').toString().trim();
    return role == 'user';
  }

  String _formatTime(Map<String, dynamic> data) {
    final ts = data['created_at'] ?? data['created_at_client'];
    if (ts is! Timestamp) return '';
    final dt = ts.toDate().toLocal();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Widget _buildMessageTile(Map<String, dynamic> data) {
    final text = (data['text'] ?? '').toString().trim();
    if (text.isEmpty) return const SizedBox.shrink();
    final isMine = _isMine(data);
    final sender = _senderLabel(data);
    final time = _formatTime(data);
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseContent = Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _messagesRef
                .orderBy('created_at_client', descending: true)
                .limit(60)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'تعذر تحميل المحادثة',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontFamily: 'Cairo',
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const SizedBox.shrink();
              }
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: docs.length,
                itemBuilder: (context, index) =>
                    _buildMessageTile(docs[index].data()),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageCtrl,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: const InputDecoration(
                      hintText: 'اكتب رسالة',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'إرسال',
                  onPressed: _isSending ? null : _sendMessage,
                  icon: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.send_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    Widget content = baseContent;
    if (kIsWeb) {
      content = LayoutBuilder(
        builder: (context, constraints) {
          final targetWidth = constraints.maxWidth > 680
              ? 620.0
              : constraints.maxWidth;
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: targetWidth,
              height: constraints.maxHeight,
              child: baseContent,
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: const GlassAppBar(
        title: Text('تواصل مع الدعم'),
        centerTitle: true,
      ),
      body: Stack(children: [const SnowBackground(), content]),
    );
  }
}
