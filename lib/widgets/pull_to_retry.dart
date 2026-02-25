// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:async';

import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';

class PullToRetry extends StatelessWidget {
  final Widget child;
  final Future<void> Function()? onRefresh;

  const PullToRetry({super.key, required this.child, this.onRefresh});

  Future<void> _defaultRefresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 320));
  }

  @override
  Widget build(BuildContext context) {
    return CustomMaterialIndicator(
      onRefresh: onRefresh ?? _defaultRefresh,
      child: child,
    );
  }
}
