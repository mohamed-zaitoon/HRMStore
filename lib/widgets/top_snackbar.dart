// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/tt_colors.dart';

class TopSnackBar {
  // EN: Shows a top snack bar overlay.
  // AR: تعرض إشعارًا علويًا فوق الواجهة.
  static void show(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    Color? textColor,
    IconData? icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final brightness = Theme.of(context).brightness;
    final Color bg =
        backgroundColor ??
        (brightness == Brightness.dark
            ? const Color(0xFF121212)
            : const Color(0xFF111111));
    final Color fg = textColor ?? Colors.white;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _TopSnackBarEntry(
        message: message,
        backgroundColor: bg,
        textColor: fg,
        icon: icon,
        duration: duration,
        onClose: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );

    overlay.insert(entry);
  }
}

class _TopSnackBarEntry extends StatefulWidget {
  final String message;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;
  final Duration duration;
  final VoidCallback onClose;

  // EN: Creates TopSnackBarEntry.
  // AR: ينشئ TopSnackBarEntry.
  const _TopSnackBarEntry({
    required this.message,
    required this.backgroundColor,
    required this.textColor,
    required this.duration,
    required this.onClose,
    this.icon,
  });

  // EN: Creates state object.
  // AR: تنشئ كائن الحالة.
  @override
  State<_TopSnackBarEntry> createState() => _TopSnackBarEntryState();
}

class _TopSnackBarEntryState extends State<_TopSnackBarEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  bool _closed = false;

  // EN: Initializes animation state.
  // AR: تهيّئ حالة التحريك.
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();

    final dismissAfter = widget.duration - const Duration(milliseconds: 240);
    Future.delayed(dismissAfter.isNegative ? Duration.zero : dismissAfter, () {
      if (!mounted || _closed) return;
      _controller.reverse().whenComplete(_close);
    });
  }

  // EN: Disposes animation resources.
  // AR: تنهي موارد التحريك.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // EN: Closes the overlay entry.
  // AR: تغلق طبقة الإشعار.
  void _close() {
    if (_closed) return;
    _closed = true;
    widget.onClose();
  }

  // EN: Builds the top snack bar UI.
  // AR: تبني واجهة الإشعار العلوي.
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 16,
      right: 16,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SlideTransition(
            position: _slide,
            child: FadeTransition(
              opacity: _fade,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: widget.backgroundColor.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.transparent,
                            width: 0,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black45,
                              blurRadius: 12,
                              offset: Offset(0, 6),
                            ),
                          ],
                            gradient: LinearGradient(
                              colors: [
                              widget.backgroundColor.withValues(alpha: 0.78),
                              widget.backgroundColor.withValues(alpha: 0.58),
                              ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.icon != null) ...[
                                Icon(
                                  widget.icon,
                                  color: widget.textColor,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                              ],
                              Flexible(
                                child: Text(
                                  widget.message,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: widget.textColor,
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
