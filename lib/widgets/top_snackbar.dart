// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:flutter/material.dart';

class TopSnackBar {
  static OverlayEntry? _activeEntry;

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

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;
    final isDark = brightness == Brightness.dark;

    final Color accent = backgroundColor ?? colorScheme.primary;
    final bool hasCustomBg = backgroundColor != null;
    final Color bg = hasCustomBg
        ? (isDark
              ? Color.alphaBlend(Colors.black.withAlpha(34), accent)
              : Color.alphaBlend(Colors.white.withAlpha(12), accent))
        : (isDark ? const Color(0xFF0F131A) : const Color(0xFFFFFFFF));
    final Brightness bgBrightness = ThemeData.estimateBrightnessForColor(bg);
    final Color fg =
        textColor ??
        (bgBrightness == Brightness.dark
            ? Colors.white
            : const Color(0xFF0F172A));

    if (_activeEntry?.mounted ?? false) {
      _activeEntry?.remove();
      _activeEntry = null;
    }

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _TopSnackBarEntry(
        message: message,
        backgroundColor: bg,
        textColor: fg,
        accentColor: accent,
        isDarkMode: isDark,
        icon: icon,
        duration: duration,
        onClose: () {
          if (_activeEntry == entry) {
            _activeEntry = null;
          }
          if (entry.mounted) entry.remove();
        },
      ),
    );

    _activeEntry = entry;
    overlay.insert(entry);
  }
}

class _TopSnackBarEntry extends StatefulWidget {
  final String message;
  final Color backgroundColor;
  final Color textColor;
  final Color accentColor;
  final bool isDarkMode;
  final IconData? icon;
  final Duration duration;
  final VoidCallback onClose;

  // EN: Creates TopSnackBarEntry.
  // AR: ينشئ TopSnackBarEntry.
  const _TopSnackBarEntry({
    required this.message,
    required this.backgroundColor,
    required this.textColor,
    required this.accentColor,
    required this.isDarkMode,
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
  late final Animation<double> _scale;
  bool _closed = false;

  // EN: Initializes animation state.
  // AR: تهيّئ حالة التحريك.
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 430),
      reverseDuration: const Duration(milliseconds: 240),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.75),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _scale = Tween<double>(
      begin: 0.88,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();

    Future.delayed(widget.duration, () {
      if (!mounted || _closed) return;
      _dismiss();
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

  Future<void> _dismiss() async {
    if (_closed) return;
    if (_controller.status != AnimationStatus.dismissed) {
      await _controller.reverse();
    }
    _close();
  }

  // EN: Builds the top snack bar UI.
  // AR: تبني واجهة الإشعار العلوي.
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 4,
      right: 4,
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
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: ScaleTransition(
                    scale: _scale,
                    child: GestureDetector(
                      onTap: _dismiss,
                      child: Material(
                        color: widget.backgroundColor,
                        borderRadius: BorderRadius.circular(30),
                        clipBehavior: Clip.antiAlias,
                        elevation: 14,
                        shadowColor: widget.isDarkMode
                            ? Colors.black.withAlpha(70)
                            : Colors.black.withAlpha(26),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                          child: SizedBox(
                            width: double.infinity,
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: widget.accentColor.withAlpha(
                                      widget.isDarkMode ? 54 : 66,
                                    ),
                                  ),
                                  child: Icon(
                                    widget.icon ?? Icons.notifications_active,
                                    color: widget.textColor,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    widget.message,
                                    textAlign: TextAlign.center,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    softWrap: true,
                                    style: TextStyle(
                                      color: widget.textColor,
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                      height: 1.25,
                                      decoration: TextDecoration.none,
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
      ),
    );
  }
}
