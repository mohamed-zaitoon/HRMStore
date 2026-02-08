// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/tt_colors.dart';
import '../../widgets/glass_app_bar.dart';
import '../../widgets/glass_card.dart';

class AdminDevicesScreen extends StatelessWidget {
  final String adminId;

  // EN: Creates AdminDevicesScreen.
  // AR: ينشئ AdminDevicesScreen.
  const AdminDevicesScreen({super.key, required this.adminId});

  // EN: Builds widget UI.
  // AR: تبني واجهة الودجت.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GlassAppBar(title: Text("الأجهزة المسجّل منها")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('admins')
            .doc(adminId)
            .collection('sessions')
            .orderBy('last_login', descending: true)
            .snapshots(),
        builder: (c, s) {
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (s.data!.docs.isEmpty) {
            return const Center(child: Text("لا توجد أجهزة"));
          }

          return ListView(
            children: s.data!.docs.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              return GlassCard(
                margin: const EdgeInsets.only(bottom: 10),
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: Icon(
                    d['device_type'] == 'web'
                        ? Icons.language
                        : Icons.phone_android,
                    color: TTColors.primaryCyan,
                  ),
                  title: Text(
                    "Device: ${d['device_type']}",
                    style: TextStyle(color: TTColors.textWhite),
                  ),
                  subtitle: Text(
                    "آخر دخول: ${d['last_login']?.toDate()}",
                    style: TextStyle(color: TTColors.textGray),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('admins')
                          .doc(adminId)
                          .collection('sessions')
                          .doc(doc.id)
                          .delete();
                    },
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
