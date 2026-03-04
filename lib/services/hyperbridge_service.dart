// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/tt_colors.dart';
import '../widgets/top_snackbar.dart';

class HyperBridgeService {
  HyperBridgeService._();

  static const MethodChannel _channel = MethodChannel('tt_android_info');

  static Future<void> applyTheme(
    BuildContext context, {
    String assetName = 'assets/hyperbridge/hrmstore_dynamic_island.hbr',
  }) async {
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    if (!isAndroid) {
      TopSnackBar.show(
        context,
        'هذه الميزة متاحة لأندرويد فقط',
        backgroundColor: Colors.orange,
        icon: Icons.warning_amber_rounded,
      );
      return;
    }

    try {
      final bool? ok = await _channel.invokeMethod<bool>(
        'applyHyperBridgeTheme',
        {'assetName': assetName},
      );

      if (ok == true) {
        TopSnackBar.show(
          context,
          'تم فتح HyperBridge لتطبيق الثيم',
          backgroundColor: Colors.green,
          icon: Icons.check_circle,
        );
      } else {
        TopSnackBar.show(
          context,
          'تعذر تطبيق الثيم',
          backgroundColor: Colors.red,
          icon: Icons.error,
        );
      }
    } on PlatformException catch (e) {
      String msg;
      Color bg = Colors.red;
      IconData icon = Icons.error;

      switch (e.code) {
        case 'HYPERBRIDGE_NOT_FOUND':
          msg = 'HyperBridge غير مثبت، يرجى تثبيته أولاً';
          bg = Colors.orange;
          icon = Icons.warning_amber_rounded;
          break;
        case 'ASSET_NOT_FOUND':
          msg = 'ملف الثيم غير موجود';
          break;
        case 'NO_ASSET':
          msg = 'اسم ملف الثيم غير صالح';
          break;
        default:
          msg = 'حدث خطأ أثناء تطبيق الثيم';
      }

      TopSnackBar.show(
        context,
        msg,
        backgroundColor: bg,
        icon: icon,
      );
    } catch (_) {
      TopSnackBar.show(
        context,
        'حدث خطأ غير متوقع أثناء التطبيق',
        backgroundColor: TTColors.primaryCyan,
        icon: Icons.error,
      );
    }
  }
}
