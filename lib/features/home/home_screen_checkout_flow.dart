part of 'home_screen.dart';

extension _HomeScreenCheckoutFlow on _HomeScreenState {
  // EN: Starts checkout flow safely and prevents re-entry.
  // AR: يبدأ مسار إتمام الطلب بشكل آمن ويمنع التكرار المتزامن.
  Future<void> _startCheckoutFlow() async {
    if (_checkoutFlowInProgress) return;
    _checkoutFlowInProgress = true;

    try {
      if (!await _checkCancelLimit()) return;
      if (!_isInputValid && !_isGameOrder && !_isPromoOrder) return;

      if (_isGameOrder || _isPromoOrder) {
        _applyTiktokCheckoutMode(
          mode: _HomeScreenState._tiktokChargeModeLink,
          password: null,
        );
        await _refreshBalancePoints(forceServer: true);
        if (!await _ensureMerchantSelected(forcePrompt: true)) return;
        await _openPaymentDialogSafely();
        return;
      }

      if (!_ensureTiktokHandle()) return;

      final selectedMode = await _showTiktokChargeModeDialog();
      if (!mounted || selectedMode == null) return;

      if (selectedMode == _HomeScreenState._tiktokChargeModeLink ||
          selectedMode == _HomeScreenState._tiktokChargeModeQr) {
        _applyTiktokCheckoutMode(mode: selectedMode, password: null);
        await _refreshBalancePoints(forceServer: true);
        if (!await _ensureMerchantSelected(forcePrompt: true)) return;
        await _openPaymentDialogSafely();
        return;
      }

      final password = await _showTiktokPasswordDialog();
      if (!mounted || password == null) return;

      _applyTiktokCheckoutMode(
        mode: _HomeScreenState._tiktokChargeModeUserPass,
        password: password,
      );

      await _refreshBalancePoints(forceServer: true);
      if (!await _ensureMerchantSelected(forcePrompt: true)) return;
      await _openPaymentDialogSafely();
    } finally {
      _checkoutFlowInProgress = false;
    }
  }

  // EN: Waits for route transition to settle before opening payment dialog.
  // AR: ينتظر استقرار انتقالات الصفحات قبل فتح حوار الدفع.
  Future<void> _openPaymentDialogSafely() async {
    await _waitForModalRouteSettle();
    if (!mounted) return;
    if (!await _ensureSelectedMerchantOnlineForCheckout()) return;
    if (!mounted) return;
    _showPaymentDialog();
  }

  // EN: Shows TikTok charge mode selector dialog.
  // AR: يعرض حوار اختيار طريقة شحن تيك توك.
  Future<String?> _showTiktokChargeModeDialog() async {
    return _showBlurDialog<String>(
      barrierLabel: 'tiktok-charge-mode-dialog',
      builder: (ctx) {
        return _buildMaterialDialogCard(
          ctx,
          title: "اختيار طريقة الشحن",
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "اختار طريقة شحن عملات تيك توك قبل اختيار وسيلة الدفع.",
              ),
              const SizedBox(height: 8),
              Text(
                "تنبيه: في حالة اختيار يوزر + باسورد يجب أن يكون التحقق بخطوتين مغلق.",
                style: TextStyle(
                  color: Theme.of(ctx).colorScheme.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx, _HomeScreenState._tiktokChargeModeLink);
                },
                child: const Text("الشحن بلينك"),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx, _HomeScreenState._tiktokChargeModeQr);
                },
                child: const Text("الشحن بـ QR"),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () {
                  Navigator.pop(
                    ctx,
                    _HomeScreenState._tiktokChargeModeUserPass,
                  );
                },
                child: const Text("يوزر + باسورد"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("إلغاء"),
            ),
          ],
        );
      },
    );
  }

  // EN: Shows password prompt for TikTok username/password mode.
  // AR: يعرض نافذة إدخال كلمة المرور لوضع يوزر/باسورد في تيك توك.
  Future<String?> _showTiktokPasswordDialog() async {
    String typedPass = '';
    String? errorText;
    bool obscure = true;

    return _showBlurDialog<String>(
      barrierLabel: 'tiktok-password-dialog',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => _buildMaterialDialogCard(
          ctx,
          title: "ادخل باسورد تيك توك",
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "تنبيه: لازم يكون التحقق بخطوتين (2FA) مقفول على حساب تيك توك قبل المتابعة.",
                style: TextStyle(
                  color: Colors.orangeAccent,
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "تنبيه أمني: غيّر كلمة السر مباشرة بعد استلام الشحن.",
                style: TextStyle(
                  color: Colors.orangeAccent,
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                autofocus: true,
                obscureText: obscure,
                onChanged: (v) => typedPass = v,
                decoration: InputDecoration(
                  labelText: "باسورد تيك توك",
                  errorText: errorText,
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility : Icons.visibility_off,
                      size: 20,
                    ),
                    onPressed: () {
                      setDialogState(() => obscure = !obscure);
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("إلغاء"),
            ),
            ElevatedButton(
              onPressed: () {
                final pass = typedPass.trim();
                if (pass.isEmpty) {
                  setDialogState(() {
                    errorText = "اكتب الباسورد للمتابعة";
                  });
                  return;
                }
                Navigator.pop(ctx, pass);
              },
              child: const Text("متابعة"),
            ),
          ],
        ),
      ),
    );
  }

  // EN: Opens the payment selection dialog for all order types.
  // AR: يفتح حوار اختيار وسيلة الدفع لكل أنواع الطلبات.
  void _showPaymentDialog() {
    if (!_isInputValid && !_isGameOrder && !_isPromoOrder) return;
    if (!_isPromoOrder && !_ensureTiktokHandle()) {
      return;
    }

    final int totalAmount = _priceValue ?? 0;
    if (totalAmount <= 0) {
      _showCustomToast(
        "حدد قيمة صحيحة قبل اختيار وسيلة الدفع",
        color: Colors.orange,
      );
      return;
    }

    _showBlurDialog<void>(
      barrierLabel: "Pay",
      builder: (ctx) {
        final payableAmount = totalAmount;
        return _buildMaterialDialogCard(
          ctx,
          title: "وسيلة الدفع",
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "إجمالي الطلب: $totalAmount جنيه",
                  style: const TextStyle(
                    color: TTColors.goldAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_isGameOrder) ...[
                  const SizedBox(height: 8),
                  Text(
                    _gameOrderTitle(_selectedPackage!),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(ctx).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if ((_selectedGameId ?? '').isNotEmpty)
                    Text("ID: $_selectedGameId", textAlign: TextAlign.center),
                ] else if (_isPromoOrder) ...[
                  const SizedBox(height: 8),
                  Text(
                    promoOrderTitleForPlatform(_promoPlatform),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(ctx).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if ((_promoLink ?? '').trim().isNotEmpty)
                    Text(
                      (_promoLink ?? '').trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                ],
                const SizedBox(height: 18),
                _payOption(
                  "فودافون كاش / محفظة",
                  Icons.account_balance_wallet,
                  Colors.orange,
                  () => _processWalletOrder(
                    payableAmount: payableAmount,
                    paymentDialogContext: ctx,
                  ),
                  enabled: !_paymentMethodActionInProgress,
                ),
                const SizedBox(height: 10),
                _payOption(
                  "InstaPay",
                  Icons.qr_code,
                  Colors.purpleAccent,
                  () => _processInstaPay(
                    payableAmount: payableAmount,
                    paymentDialogContext: ctx,
                  ),
                  enabled: !_paymentMethodActionInProgress,
                ),
                const SizedBox(height: 10),
                _payOptionWithLeading(
                  "Binance Pay",
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.asset(
                      'assets/icon/binance_logo.png',
                      width: 22,
                      height: 22,
                      fit: BoxFit.cover,
                    ),
                  ),
                  () => _processBinancePay(
                    payableAmount: payableAmount,
                    paymentDialogContext: ctx,
                  ),
                  enabled: !_paymentMethodActionInProgress,
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: _paymentMethodActionInProgress
                  ? null
                  : () => Navigator.of(ctx).pop(),
              icon: const Icon(Icons.close),
              label: const Text("إلغاء"),
            ),
          ],
        );
      },
    );
  }

  // EN: Builds a payment option row with an icon.
  // AR: يبني سطر خيار دفع بأيقونة.
  Widget _payOption(
    String t,
    IconData i,
    Color c,
    VoidCallback tap, {
    bool enabled = true,
  }) {
    return ListTile(
      leading: Icon(i, color: c),
      title: Text(t, style: const TextStyle(fontFamily: 'Cairo')),
      onTap: enabled ? tap : null,
      tileColor: TTColors.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  // EN: Builds a payment option row with custom leading widget.
  // AR: يبني سطر خيار دفع بعنصر مخصص في اليسار.
  Widget _payOptionWithLeading(
    String t,
    Widget leading,
    VoidCallback tap, {
    bool enabled = true,
  }) {
    return ListTile(
      leading: leading,
      title: Text(t, style: const TextStyle(fontFamily: 'Cairo')),
      onTap: enabled ? tap : null,
      tileColor: TTColors.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  // EN: Marks a payment action as running and blocks duplicate taps.
  // AR: يحدد أن إجراء الدفع قيد التنفيذ ويمنع التكرار.
  bool _startPaymentMethodAction() {
    if (_paymentMethodActionInProgress) return false;
    _setPaymentActionLock(true);
    return true;
  }

  // EN: Clears payment action running state.
  // AR: ينهي حالة التنفيذ الجارية لإجراء الدفع.
  void _finishPaymentMethodAction() {
    _setPaymentActionLock(false);
  }

  // EN: Waits for UI frame boundaries so route transitions can finish.
  // AR: ينتظر حدود الإطار حتى تنتهي انتقالات المسارات.
  Future<void> _waitForModalRouteSettle() async {
    await Future<void>.delayed(Duration.zero);
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(Duration.zero);
  }

  // EN: Closes payment dialog using its local navigator context safely.
  // AR: يغلق حوار الدفع باستخدام سياق الملاح المحلي بشكل آمن.
  Future<void> _closePaymentDialogSafely(BuildContext dialogContext) async {
    if (dialogContext.mounted) {
      final navigator = Navigator.maybeOf(dialogContext);
      if (navigator != null) {
        await navigator.maybePop();
      }
    }
    await _waitForModalRouteSettle();
  }
}
