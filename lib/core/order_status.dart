// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:flutter/material.dart';

class OrderStatusHelper {
  // EN: Handles label.
  // AR: تتعامل مع label.
  static String label(String status) {
    switch (status) {
      case 'pending_review':
        return '⏳ جاري المراجعة';
      case 'processing':
        return '⚙️ قيد التنفيذ';
      case 'completed':
        return '✅ مكتمل';
      case 'rejected':
        return '❌ مرفوض';
      case 'cancelled':
        return '🚫 ملغي';
      default:
        return '⏳ جاري المراجعة';
    }
  }

  // EN: Handles color.
  // AR: تتعامل مع color.
  static Color color(String status) {
    switch (status) {
      case 'pending_review':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }
}
