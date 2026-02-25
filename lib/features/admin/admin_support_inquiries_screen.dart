// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/tt_colors.dart';
import '../../services/cloudflare_notify_service.dart';
import '../../widgets/glass_app_bar.dart';
import '../../widgets/snow_background.dart';
import '../../widgets/top_snackbar.dart';

class AdminSupportInquiriesScreen extends StatefulWidget {
  final String? initialConversationId;

  const AdminSupportInquiriesScreen({super.key, this.initialConversationId});

  @override
  State<AdminSupportInquiriesScreen> createState() =>
      _AdminSupportInquiriesScreenState();
}

class _AdminSupportInquiriesScreenState
    extends State<AdminSupportInquiriesScreen> {
  final TextEditingController _messageCtrl = TextEditingController();
  bool _isSending = false;
  String? _selectedConversationId;

  CollectionReference<Map<String, dynamic>> get _conversationsRef {
    return FirebaseFirestore.instance.collection('support_conversations');
  }

  @override
  void initState() {
    super.initState();
    final seeded = (widget.initialConversationId ?? '').trim();
    if (seeded.isNotEmpty) {
      _selectedConversationId = seeded;
    }
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _notifyUserWithRetry({
    required String conversationId,
    required String whatsapp,
  }) async {
    const maxAttempts = 3;
    for (var i = 0; i < maxAttempts; i++) {
      final success =
          await CloudflareNotifyService.notifyUserSupportInquiryMessage(
            conversationId: conversationId,
            userWhatsapp: whatsapp,
          ).timeout(const Duration(seconds: 10), onTimeout: () => false);
      if (success) return;
      if (i < maxAttempts - 1) {
        await Future<void>.delayed(Duration(milliseconds: 500 * (i + 1)));
      }
    }
  }

  Future<void> _sendMessage({
    required String conversationId,
    required String userWhatsapp,
  }) async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      final messagesRef = _conversationsRef
          .doc(conversationId)
          .collection('messages');
      await messagesRef.add({
        'text': text,
        'sender_role': 'admin',
        'sender_name': '',
        'created_at': FieldValue.serverTimestamp(),
        'created_at_client': Timestamp.fromDate(DateTime.now()),
      });

      await _conversationsRef.doc(conversationId).set({
        'updated_at': FieldValue.serverTimestamp(),
        'last_sender_role': 'admin',
        'last_message': text,
        'is_open': true,
      }, SetOptions(merge: true));

      if (userWhatsapp.trim().isNotEmpty) {
        await _notifyUserWithRetry(
          conversationId: conversationId,
          whatsapp: userWhatsapp,
        );
      }

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

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate().toLocal();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _conversationTitle(Map<String, dynamic> data) {
    final name = (data['user_name'] ?? '').toString().trim();
    final whatsapp = (data['user_whatsapp'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;
    if (whatsapp.isNotEmpty) return whatsapp;
    return 'مستخدم';
  }

  Widget _buildConversationTile({
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final data = doc.data();
    final title = _conversationTitle(data);
    final subtitle = (data['last_message'] ?? '').toString().trim();
    final updatedAt = data['updated_at'];
    final ts = updatedAt is Timestamp ? updatedAt : null;
    final timeText = _formatTime(ts);

    return ListTile(
      selected: selected,
      selectedTileColor: Theme.of(context).colorScheme.primary.withAlpha(28),
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primary.withAlpha(38),
        child: const Icon(Icons.support_agent),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle.isEmpty ? 'بدون رسائل بعد' : subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontFamily: 'Cairo'),
      ),
      trailing: Text(
        timeText,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 11,
          fontFamily: 'Cairo',
        ),
      ),
    );
  }

  String _senderLabel(Map<String, dynamic> data, String userName) {
    final role = (data['sender_role'] ?? '').toString().trim();
    if (role == 'admin') return 'أنت';
    if (role == 'system') return '(رسالة آليه)';
    return userName.isNotEmpty ? userName : 'المستخدم';
  }

  bool _isMine(Map<String, dynamic> data) {
    final role = (data['sender_role'] ?? '').toString().trim();
    return role == 'admin';
  }

  Widget _buildMessageTile(Map<String, dynamic> data, String userName) {
    final text = (data['text'] ?? '').toString().trim();
    if (text.isEmpty) return const SizedBox.shrink();
    final isMine = _isMine(data);
    final colorScheme = Theme.of(context).colorScheme;
    final ts = data['created_at'] ?? data['created_at_client'];
    final timeText = ts is Timestamp ? _formatTime(ts) : '';

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isMine
                ? colorScheme.primary.withAlpha(46)
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
                _senderLabel(data, userName),
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
              if (timeText.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  timeText,
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
    );
  }

  Widget _buildChatPane({
    required String conversationId,
    required Map<String, dynamic> conversationData,
  }) {
    final userName = (conversationData['user_name'] ?? '').toString().trim();
    final userWhatsapp = (conversationData['user_whatsapp'] ?? '')
        .toString()
        .trim();
    final messagesRef = _conversationsRef
        .doc(conversationId)
        .collection('messages');

    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: TTColors.cardBg.withAlpha(170),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _conversationTitle(conversationData),
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (userWhatsapp.isNotEmpty)
                Text(
                  userWhatsapp,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontFamily: 'Cairo',
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: messagesRef
                .orderBy('created_at_client', descending: true)
                .limit(120)
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
                return const Center(
                  child: Text(
                    'لا توجد رسائل بعد',
                    style: TextStyle(fontFamily: 'Cairo'),
                  ),
                );
              }

              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: docs.length,
                itemBuilder: (context, index) =>
                    _buildMessageTile(docs[index].data(), userName),
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
                    onSubmitted: (_) => _sendMessage(
                      conversationId: conversationId,
                      userWhatsapp: userWhatsapp,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'اكتب رسالة',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'إرسال',
                  onPressed: _isSending
                      ? null
                      : () => _sendMessage(
                          conversationId: conversationId,
                          userWhatsapp: userWhatsapp,
                        ),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GlassAppBar(
        title: Text('شات الاستفسارات'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          const SnowBackground(),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _conversationsRef
                .orderBy('updated_at', descending: true)
                .limit(200)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'تعذر تحميل شات الاستفسارات',
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
                return const Center(
                  child: Text(
                    'لا توجد استفسارات حالياً',
                    style: TextStyle(fontFamily: 'Cairo'),
                  ),
                );
              }

              final hasSelection = docs.any(
                (d) => d.id == _selectedConversationId,
              );
              final activeId = hasSelection
                  ? _selectedConversationId!
                  : docs.first.id;
              final activeDoc = docs.firstWhere((d) => d.id == activeId);
              if (!hasSelection && _selectedConversationId != activeId) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(() => _selectedConversationId = activeId);
                });
              }

              final isWide = MediaQuery.of(context).size.width >= 980;
              if (isWide) {
                return Row(
                  children: [
                    SizedBox(
                      width: 340,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          return _buildConversationTile(
                            doc: doc,
                            selected: doc.id == activeId,
                            onTap: () {
                              setState(() => _selectedConversationId = doc.id);
                            },
                          );
                        },
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: _buildChatPane(
                        conversationId: activeId,
                        conversationData: activeDoc.data(),
                      ),
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: DropdownButtonFormField<String>(
                      initialValue: activeId,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        labelText: 'اختر المحادثة',
                      ),
                      items: docs
                          .map(
                            (doc) => DropdownMenuItem<String>(
                              value: doc.id,
                              child: Text(
                                _conversationTitle(doc.data()),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontFamily: 'Cairo'),
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedConversationId = value);
                      },
                    ),
                  ),
                  Expanded(
                    child: _buildChatPane(
                      conversationId: activeId,
                      conversationData: activeDoc.data(),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
