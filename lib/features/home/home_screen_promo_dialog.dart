part of 'home_screen.dart';

extension _HomeScreenPromoDialog on _HomeScreenState {
  // EN: Opens promo order dialog, validates input, then starts checkout.
  // AR: يفتح حوار طلب الترويج ويتحقق من المدخلات ثم يبدأ إتمام الطلب.
  Future<void> _openPromoDialog() async {
    if (_promoDialogFlowInProgress) return;
    _promoDialogFlowInProgress = true;

    final linkCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    try {
      if (!await _checkCancelLimit()) return;

      final selectedPlatform = await _showPromoEntryDialog(
        linkCtrl: linkCtrl,
        amountCtrl: amountCtrl,
        initialPlatform: normalizePromoPlatform(_promoPlatform),
      );

      await _waitForModalRouteSettle();

      final link = linkCtrl.text.trim();
      final rawAmount = amountCtrl.text;

      if (selectedPlatform == null || !mounted) return;

      final promoPlatform = normalizePromoPlatform(selectedPlatform);
      final amount = _normalizeMoneyAmount(
        raw: rawAmount,
        min: _HomeScreenState._promoMinAmount,
        max: _HomeScreenState._promoMaxAmount,
      );

      if (amount == null ||
          link.isEmpty ||
          !isValidPromoLinkForPlatform(promoPlatform, link)) {
        TopSnackBar.show(
          context,
          "أدخل رابط ${promoPlatformLabel(promoPlatform)} صالح ومبلغ بين ${_HomeScreenState._promoMinAmount} و ${_HomeScreenState._promoMaxAmount} جنيه",
          backgroundColor: Colors.orange,
          textColor: Colors.black,
          icon: Icons.warning_amber_rounded,
        );
        return;
      }

      _applyPromoOrderDraft(
        promoPlatform: promoPlatform,
        promoLink: link,
        amount: amount,
      );

      await _startCheckoutFlow();
    } finally {
      linkCtrl.dispose();
      amountCtrl.dispose();
      _promoDialogFlowInProgress = false;
    }
  }

  // EN: Shows promo entry dialog with guarded close lifecycle.
  // AR: يعرض حوار إدخال الترويج مع حراسة إغلاق آمنة.
  Future<String?> _showPromoEntryDialog({
    required TextEditingController linkCtrl,
    required TextEditingController amountCtrl,
    required String initialPlatform,
  }) async {
    var selectedPlatform = normalizePromoPlatform(initialPlatform);
    var isSubmitting = false;
    var isClosing = false;
    String? submitPlatform;

    await _showPromoBlurDialog<void>(
      barrierLabel: 'promo-order-dialog',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> closeDialog({required bool submit}) async {
            if (isClosing) return;

            setDialogState(() {
              isClosing = true;
              isSubmitting = submit;
            });

            if (submit) {
              submitPlatform = selectedPlatform;
            }

            final navigator = Navigator.maybeOf(ctx);
            final didPop = navigator != null && await navigator.maybePop();
            if (!didPop && ctx.mounted) {
              setDialogState(() {
                isClosing = false;
                isSubmitting = false;
              });
            }
          }

          return _buildMaterialDialogCard(
            ctx,
            title: promoEntryTitleForPlatform(selectedPlatform),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    'اختر المنصة ثم أضف الرابط والمبلغ.',
                    style: TextStyle(
                      color: TTColors.textGray,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: supportedPromoPlatforms
                      .map((platform) {
                        return ChoiceChip(
                          label: Text(promoPlatformLabel(platform)),
                          selected: selectedPlatform == platform,
                          onSelected: (selected) {
                            if (!selected || isClosing) return;
                            setDialogState(() => selectedPlatform = platform);
                          },
                        );
                      })
                      .toList(growable: false),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: linkCtrl,
                  decoration: InputDecoration(
                    labelText: promoLinkLabelForPlatform(selectedPlatform),
                    hintText: promoLinkHintForPlatform(selectedPlatform),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: "المبلغ بالجنيه",
                    hintText: "150 - 30000",
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: (isSubmitting || isClosing)
                    ? null
                    : () {
                        unawaited(closeDialog(submit: false));
                      },
                child: const Text("إلغاء"),
              ),
              ElevatedButton(
                onPressed: (isSubmitting || isClosing)
                    ? null
                    : () {
                        unawaited(closeDialog(submit: true));
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("إنشاء طلب"),
              ),
            ],
          );
        },
      ),
    );

    return submitPlatform;
  }

  // EN: Shows promo dialog with stable route child and same blur/fade style.
  // AR: يعرض حوار الترويج بطفل route ثابت مع نفس شكل blur/fade.
  Future<T?> _showPromoBlurDialog<T>({
    required WidgetBuilder builder,
    String barrierLabel = 'promo-order-dialog',
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: false,
      barrierLabel: barrierLabel,
      barrierColor: Colors.black.withAlpha(96),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, routeAnimation, secondaryAnimation) =>
          SafeArea(child: Builder(builder: builder)),
      transitionBuilder: (_, animation, routeAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final blur = Tween<double>(begin: 0, end: 8).animate(curved);

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur.value, sigmaY: blur.value),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
  }
}
