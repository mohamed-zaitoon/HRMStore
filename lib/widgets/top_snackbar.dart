// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:async';

import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class TopSnackBar {
  static OverlayEntry? _activeEntry;
  static Timer? _dismissTimer;
  static String _lastSignature = '';
  static DateTime _lastShownAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _dedupeWindow = Duration(milliseconds: 900);
  static final Map<String, DateTime> _keyedDedupeUntil = <String, DateTime>{};

  // EN: Shows a top snack bar using awesome_snackbar_content.
  // AR: تعرض إشعارًا علويًا باستخدام awesome_snackbar_content.
  static void show(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    Color? textColor,
    IconData? icon,
    Duration? duration = const Duration(seconds: 3),
    String? dedupeKey,
    Duration dedupeDuration = const Duration(minutes: 10),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);

    final contentType = _resolveContentType(
      backgroundColor: backgroundColor,
      icon: icon,
    );
    final title = _resolveTitle(contentType);
    final signature = '${contentType.toString()}|${message.trim()}';
    final now = DateTime.now();
    if (_lastSignature == signature &&
        now.difference(_lastShownAt) < _dedupeWindow) {
      return;
    }
    final trimmedDedupeKey = (dedupeKey ?? '').trim();
    if (trimmedDedupeKey.isNotEmpty) {
      _purgeExpiredKeyedDedupe(now);
      final until = _keyedDedupeUntil[trimmedDedupeKey];
      if (until != null && now.isBefore(until)) {
        return;
      }
      _keyedDedupeUntil[trimmedDedupeKey] = now.add(dedupeDuration);
    }
    _lastSignature = signature;
    _lastShownAt = now;

    if (overlay == null) {
      _showFallbackSnackBar(
        context,
        message,
        contentType: contentType,
        duration: duration,
        backgroundColor: backgroundColor,
        textColor: textColor,
        icon: icon,
      );
      return;
    }

    _dismissTimer?.cancel();
    _activeEntry?.remove();

    _activeEntry = OverlayEntry(
      builder: (overlayContext) {
        final media = MediaQuery.maybeOf(overlayContext);
        final top = (media?.padding.top ?? 0) + 8;
        return Positioned(
          top: top,
          left: 12,
          right: 12,
          child: Material(
            color: Colors.transparent,
            child: SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: GestureDetector(
                    onTap: dismiss,
                    child: kIsWeb
                        ? _buildWebTopToast(
                            message: message,
                            contentType: contentType,
                            icon: icon,
                            backgroundColor: backgroundColor,
                            textColor: textColor,
                          )
                        : AwesomeSnackbarContent(
                            title: title,
                            message: message,
                            contentType: contentType,
                            inMaterialBanner: false,
                            titleTextStyle: TextStyle(
                              color: textColor ?? Colors.white,
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                            messageTextStyle: TextStyle(
                              color: textColor ?? Colors.white,
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_activeEntry!);

    if (duration != null) {
      _dismissTimer = Timer(duration, dismiss);
    }
  }

  static Widget _buildWebTopToast({
    required String message,
    required ContentType contentType,
    required IconData? icon,
    required Color? backgroundColor,
    required Color? textColor,
  }) {
    final fg = textColor ?? Colors.white;
    final bg = backgroundColor ?? _resolveBgColor(contentType);
    final effectiveIcon = icon ?? _resolveIcon(contentType);

    return Container(
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Icon(effectiveIcon, color: fg, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: fg,
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _showFallbackSnackBar(
    BuildContext context,
    String message, {
    required ContentType contentType,
    required Duration? duration,
    required Color? backgroundColor,
    required Color? textColor,
    required IconData? icon,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final fg = textColor ?? Colors.white;
    final bg = (backgroundColor ?? _resolveBgColor(contentType)).withValues(
      alpha: 0.96,
    );
    final effectiveIcon = icon ?? _resolveIcon(contentType);

    messenger.hideCurrentSnackBar(reason: SnackBarClosedReason.hide);
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: bg,
        duration: duration ?? const Duration(seconds: 3),
        content: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            children: [
              Icon(effectiveIcon, color: fg),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: fg,
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _resolveBgColor(ContentType contentType) {
    switch (contentType) {
      case ContentType.success:
        return const Color(0xFF148F58);
      case ContentType.failure:
        return const Color(0xFFC0392B);
      case ContentType.warning:
        return const Color(0xFFD68910);
      case ContentType.help:
        return const Color(0xFF265D97);
    }
    return const Color(0xFF265D97);
  }

  static IconData _resolveIcon(ContentType contentType) {
    switch (contentType) {
      case ContentType.success:
        return Icons.check_circle_rounded;
      case ContentType.failure:
        return Icons.error_rounded;
      case ContentType.warning:
        return Icons.warning_amber_rounded;
      case ContentType.help:
        return Icons.notifications_rounded;
    }
    return Icons.notifications_rounded;
  }

  // EN: Dismisses current top snack bar if visible.
  // AR: تغلق الإشعار العلوي الحالي إن كان ظاهرًا.
  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _activeEntry?.remove();
    _activeEntry = null;
  }

  static void _purgeExpiredKeyedDedupe(DateTime now) {
    if (_keyedDedupeUntil.isEmpty) return;
    final expired = <String>[];
    _keyedDedupeUntil.forEach((key, until) {
      if (!now.isBefore(until)) {
        expired.add(key);
      }
    });
    for (final key in expired) {
      _keyedDedupeUntil.remove(key);
    }
  }

  static ContentType _resolveContentType({
    required Color? backgroundColor,
    required IconData? icon,
  }) {
    if (backgroundColor != null) {
      final hsl = HSLColor.fromColor(backgroundColor);
      final hue = hsl.hue;
      final saturation = hsl.saturation;
      if (saturation < 0.15) {
        return ContentType.help;
      }
      if (hue <= 25 || hue >= 330) {
        return ContentType.failure;
      }
      if (hue >= 35 && hue <= 75) {
        return ContentType.warning;
      }
      if (hue >= 76 && hue <= 170) {
        return ContentType.success;
      }
      return ContentType.help;
    }

    if (icon != null) {
      if (icon == Icons.check_circle ||
          icon == Icons.task_alt ||
          icon == Icons.done_all) {
        return ContentType.success;
      }
      if (icon == Icons.warning_amber_rounded ||
          icon == Icons.warning ||
          icon == Icons.info_outline) {
        return ContentType.warning;
      }
      if (icon == Icons.error_outline ||
          icon == Icons.cancel ||
          icon == Icons.block) {
        return ContentType.failure;
      }
    }

    return ContentType.help;
  }

  static String _resolveTitle(ContentType contentType) {
    return '';
  }
}
