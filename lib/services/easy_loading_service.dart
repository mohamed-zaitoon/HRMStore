// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import '../core/tt_colors.dart';

class EasyLoadingService {
  static void configure() {
    EasyLoading.instance
      ..displayDuration = const Duration(milliseconds: 1800)
      ..indicatorType = EasyLoadingIndicatorType.fadingCircle
      ..loadingStyle = EasyLoadingStyle.custom
      ..indicatorSize = 42
      ..radius = 14
      ..progressColor = TTColors.primaryCyan
      ..backgroundColor = TTColors.cardBg.withAlpha(245)
      ..indicatorColor = TTColors.primaryCyan
      ..textColor = TTColors.textWhite
      ..maskColor = Colors.black.withAlpha(120)
      ..userInteractions = false
      ..dismissOnTap = false
      ..maskType = EasyLoadingMaskType.custom;
  }

  static Future<void> show({String status = 'جاري التحميل...'}) {
    return EasyLoading.show(status: status);
  }

  static Future<void> dismiss() {
    return EasyLoading.dismiss();
  }

  static Future<void> success(String status) {
    return EasyLoading.showSuccess(status);
  }

  static Future<void> error(String status) {
    return EasyLoading.showError(status);
  }
}
