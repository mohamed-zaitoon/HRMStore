part of 'home_screen.dart';

extension _HomeScreenPaymentActions on _HomeScreenState {
  // EN: Handles wallet checkout after payment method selection.
  // AR: يتعامل مع الدفع عبر المحفظة بعد اختيار وسيلة الدفع.
  Future<void> _processWalletOrder({
    required int payableAmount,
    required BuildContext paymentDialogContext,
  }) async {
    if (!_startPaymentMethodAction()) return;

    try {
      await _closePaymentDialogSafely(paymentDialogContext);
      if (!mounted) return;

      if (!await _ensureSelectedMerchantOnlineForCheckout()) return;
      if (!await _checkCancelLimit()) return;
      if (payableAmount <= 0) {
        _showCustomToast("لا يوجد مبلغ مطلوب دفعه الآن.", color: Colors.orange);
        return;
      }

      bool proceed = false;

      await _showBlurDialog<void>(
        barrierLabel: 'wallet-order-dialog',
        builder: (ctx) => _buildMaterialDialogCard(
          ctx,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info, color: Colors.orange, size: 50),
              const SizedBox(height: 10),
              Text(
                "المبلغ المطلوب دفعه الآن: $payableAmount جنيه",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: TTColors.goldAccent,
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "سيتم إرسال رقم المحفظة وتأكيدات الدفع من التاجر داخل الشات بعد إنشاء الطلب.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: TTColors.textWhite,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                proceed = false;
              },
              child: const Text("إلغاء"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                proceed = true;
              },
              child: const Text("متابعة"),
            ),
          ],
        ),
      );

      if (!proceed) return;
      if (!mounted) return;
      final createdOrderId = await _createOrderWithOptionalPoints(
        payload: _buildOrderPayload(
          method: "Wallet",
          status: 'pending_payment',
          paymentTarget: '',
          priceOverride: payableAmount,
        ),
      );
      if (createdOrderId == null || !mounted) return;

      await _openSupportChat(orderId: createdOrderId);
      if (!mounted) return;
      _resetCheckoutMeta();
    } finally {
      _finishPaymentMethodAction();
    }
  }

  // EN: Handles Binance checkout and computes USDT amount if available.
  // AR: يتعامل مع Binance Pay ويحسب قيمة USDT عند توفر السعر.
  Future<void> _processBinancePay({
    required int payableAmount,
    required BuildContext paymentDialogContext,
  }) async {
    if (!_startPaymentMethodAction()) return;

    try {
      await _closePaymentDialogSafely(paymentDialogContext);
      if (!mounted) return;

      if (!await _ensureSelectedMerchantOnlineForCheckout()) return;
      if (!await _checkCancelLimit()) return;
      if (payableAmount <= 0) {
        _showCustomToast("لا يوجد مبلغ مطلوب دفعه الآن.", color: Colors.orange);
        return;
      }

      final String binanceId = _binanceId.trim();

      await _refreshUsdtPriceFromExternal(forceRefresh: true);

      final usdtAmount = _computeOrderUsdtAmount(egpAmount: payableAmount);
      final usdtAmountText = usdtAmount == null
          ? ''
          : _formatUsdtAmount(usdtAmount);

      bool proceed = false;

      await _showBlurDialog<void>(
        barrierLabel: 'binance-order-dialog',
        builder: (ctx) => _buildMaterialDialogCard(
          ctx,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.currency_bitcoin,
                color: Color(0xFFF3BA2F),
                size: 50,
              ),
              const SizedBox(height: 10),
              Text(
                "المبلغ المطلوب: ${usdtAmountText.isEmpty ? payableAmount : '$usdtAmountText USDT'}",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: TTColors.textWhite,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "المعادِل بالجنيه: $payableAmount",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: TTColors.goldAccent,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "سيتم إرسال Binance Pay ID وتأكيدات الدفع داخل الشات من التاجر.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: TTColors.textWhite,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                proceed = false;
              },
              child: const Text("إلغاء"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                proceed = true;
              },
              child: const Text("متابعة"),
            ),
          ],
        ),
      );

      if (!proceed) return;
      if (!mounted) return;
      final createdOrderId = await _createOrderWithOptionalPoints(
        payload: _buildOrderPayload(
          method: "Binance Pay",
          status: 'pending_payment',
          paymentTarget: '',
          binanceId: binanceId.isEmpty ? null : binanceId,
          usdtAmount: usdtAmountText.isEmpty ? null : usdtAmountText,
          usdtPrice: usdtAmount == null ? null : _usdtPrice,
          priceOverride: payableAmount,
        ),
      );
      if (createdOrderId == null || !mounted) return;

      await _openSupportChat(orderId: createdOrderId);
      if (!mounted) return;
      _resetCheckoutMeta();
    } finally {
      _finishPaymentMethodAction();
    }
  }

  // EN: Handles InstaPay checkout confirmation and order creation.
  // AR: يتعامل مع تأكيد InstaPay وإنشاء الطلب.
  Future<void> _processInstaPay({
    required int payableAmount,
    required BuildContext paymentDialogContext,
  }) async {
    if (!_startPaymentMethodAction()) return;

    try {
      await _closePaymentDialogSafely(paymentDialogContext);
      if (!mounted) return;

      if (!await _ensureSelectedMerchantOnlineForCheckout()) return;
      if (!await _checkCancelLimit()) return;
      if (payableAmount <= 0) {
        _showCustomToast("لا يوجد مبلغ مطلوب دفعه الآن.", color: Colors.orange);
        return;
      }

      bool proceed = false;

      await _showBlurDialog<void>(
        barrierLabel: 'instapay-order-dialog',
        builder: (ctx) => _buildMaterialDialogCard(
          ctx,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "المبلغ المطلوب: $payableAmount جنيه",
                textAlign: TextAlign.center,
                style: TextStyle(color: TTColors.textWhite),
              ),
              const SizedBox(height: 8),
              Text(
                "سيقوم التاجر بإرسال رابط أو رقم InstaPay داخل الشات بعد إنشاء الطلب.",
                textAlign: TextAlign.center,
                style: TextStyle(color: TTColors.goldAccent),
              ),
              const SizedBox(height: 12),
              Text(
                "بعد التحويل اضغط متابعة، وأرسل أي إثبات داخل الشات.",
                textAlign: TextAlign.center,
                style: TextStyle(color: TTColors.textGray),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                proceed = false;
              },
              child: const Text("إلغاء"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                proceed = true;
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
              child: const Text("متابعة"),
            ),
          ],
        ),
      );

      if (!mounted) return;
      if (!proceed) return;
      final createdOrderId = await _createOrderWithOptionalPoints(
        payload: _buildOrderPayload(
          method: "InstaPay",
          status: 'pending_payment',
          instapayLink: null,
          paymentTarget: '',
          priceOverride: payableAmount,
        ),
      );
      if (createdOrderId == null || !mounted) return;

      _showCustomToast("تم إنشاء الطلب ✅", color: Colors.green);
      await _openSupportChat(orderId: createdOrderId);
      if (!mounted) return;
      _resetCheckoutMeta();
    } finally {
      _finishPaymentMethodAction();
    }
  }
}
