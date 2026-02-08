// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:flutter/material.dart';

class OrderStatusHelper {
  // EN: Handles label.
  // AR: تتعامل مع label.
  static String label(String status) {
    switch (status) {
      case 'pending_payment':
        return 'بانتظار الدفع';
      case 'pending_receipt':
        return 'جاري رفع الإيصال';
      case 'pending_review':
        return 'قيد المراجعة';
      case 'processing':
        return 'قيد التنفيذ';
      case 'completed':
        return 'مكتمل';
      case 'rejected':
        return 'مرفوض';
      default:
        return 'قيد المراجعة';
    }
  }

  // EN: Handles color.
  // AR: تتعامل مع color.
  static Color color(String status) {
    switch (status) {
      case 'pending_payment':
        return Colors.orangeAccent;
      case 'pending_receipt':
        return Colors.blueGrey;
      case 'pending_review':
        return Colors.blue;
      case 'processing':
        return Colors.cyan;
      case 'completed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
}
