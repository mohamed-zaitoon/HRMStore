// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:material_dialogs/material_dialogs.dart';
import 'package:material_dialogs/shared/types.dart';
import 'package:material_dialogs/widgets/dialogs/dialog_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/tt_colors.dart';
import '../../core/app_info.dart';
import '../../core/app_navigator.dart';
import '../../models/game_package.dart';
import '../../services/cancel_limit_service.dart';
import '../../services/cloudflare_notify_service.dart';
import '../../services/easy_loading_service.dart';
import '../../services/order_chat_service.dart';
import '../../services/remote_config_service.dart';
import '../../services/notification_service.dart';
import '../../services/theme_service.dart';
import '../../services/update_manager.dart';
import '../../services/usdt_price_service.dart';
import '../../utils/html_meta.dart';
import '../../widgets/snow_background.dart';
import '../../widgets/theme_mode_sheet.dart';
import '../../widgets/glass_app_bar.dart';
import '../../widgets/glass_card.dart';
import '../../utils/url_sanitizer.dart';
import '../../widgets/top_snackbar.dart';

enum _OutOfRange { none, belowMin, aboveMax }

class _MerchantGroupState {
  Map<String, dynamic>? profileCandidate;
  int profileScore = -1;
  DateTime? profileTimestamp;
  Map<String, dynamic>? presenceCandidate;
  DateTime? presenceTimestamp;
}

class HomeScreen extends StatefulWidget {
  final String name;
  final String whatsapp;
  final String tiktok;
  final bool forceTikTokCharge;
  final bool showRamadanPromo;
  final bool showGamesOnly;
  final int? prefillPoints;
  final bool autolaunchPayment;

  // EN: Creates HomeScreen.
  // AR: ينشئ HomeScreen.
  const HomeScreen({
    super.key,
    required this.name,
    required this.whatsapp,
    required this.tiktok,
    this.forceTikTokCharge = false,
    this.showRamadanPromo = true,
    this.showGamesOnly = false,
    this.prefillPoints,
    this.autolaunchPayment = false,
  });

  // EN: Creates state object.
  // AR: تنشئ كائن الحالة.
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isPointsMode = true;
  bool _isDiscountActive = false;
  bool _isInputValid = false;
  static const int _minPoints = 150;
  static const int _maxPoints = 100000;
  static const String _tiktokChargeModeLink = 'link';
  static const String _tiktokChargeModeQr = 'qr';
  static const String _tiktokChargeModeUserPass = 'username_password';

  String _resultText = "";
  int? _pointsValue;
  int? _priceValue;
  GamePackage? _selectedPackage;
  String? _selectedGameId;
  String? _promoLink;
  String _tiktokChargeMode = _tiktokChargeModeLink;
  String? _tiktokPasswordForOrder;

  final _inputCtrl = TextEditingController();
  final _promoCtrl = TextEditingController();
  late TextEditingController _nameCtrl;
  final _tiktokCtrl = TextEditingController();
  List<Map<String, dynamic>> _prices = [];

  String _binanceId = "";
  double _usdtPrice = 0;
  double _offerRateFor100 = 0;
  double _offerRateFor500 = 0;
  double _offerRateFor1000 = 0;
  double _offerRateFor50000 = 0;
  double _offerRateFor75000 = 0;
  bool _offersEnabled = true;
  bool _isRamadanSeason = false;
  bool _isEidSeason = false;
  String _offersTitle = '✨ عروض الخصم ✨';
  String _offersRequestCta = 'اضغط لطلب كود الخصم الخاص بك';
  int _balancePoints = 0;
  DocumentReference<Map<String, dynamic>>? _userDocRef;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _balancePointsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _balancePointsByUidSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _balancePointsByWhatsappSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _pricesSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _offersSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _orderStatusWatchSub;
  bool _isPricesLoading = true;
  bool _hasPricesError = false;
  String _pricesStatusMessage = '';
  VoidCallback? _activeTiktokDialogRefresh;
  final Map<String, String> _orderStatusById = <String, String>{};
  final Set<String> _processingOrdersOpenedForChat = <String>{};
  bool _orderStatusWatchPrimed = false;
  bool _supportChatNavigationInProgress = false;
  Map<String, dynamic>? _selectedMerchant;

  bool get _arePricesReady =>
      !_isPricesLoading && !_hasPricesError && _prices.isNotEmpty;

  bool get _isPromoOffersEnabled => _offersEnabled;

  bool get _isSeasonalPromoEnabled =>
      (_isRamadanSeason && !_isEidSeason) ||
      (_isEidSeason && !_isRamadanSeason);

  String get _seasonalPromoLabel => _isEidSeason ? 'العيد' : 'رمضان';

  bool get _showPromoCodeSection =>
      widget.showRamadanPromo &&
      _isPromoOffersEnabled &&
      _isSeasonalPromoEnabled;

  String get _promoCodesTitle => _isSeasonalPromoEnabled
      ? 'أكواد خصم $_seasonalPromoLabel'
      : 'أكواد الخصم';

  String get _offersCardTitle {
    final value = _offersTitle.trim();
    return value.isEmpty ? '✨ عروض الخصم ✨' : value;
  }

  String get _offersRequestButtonTitle {
    final value = _offersRequestCta.trim();
    return value.isEmpty ? 'اضغط لطلب كود الخصم الخاص بك' : value;
  }

  String _resolvedPricesStatusMessage() {
    if (_isPricesLoading) {
      return 'جاري تحميل الأسعار...';
    }
    final value = _pricesStatusMessage.trim();
    return value.isEmpty ? 'تعذر تحميل الأسعار حالياً' : value;
  }

  void _refreshActiveTiktokDialog() {
    _activeTiktokDialogRefresh?.call();
  }

  void _resetTiktokDialogCalculationState({bool refreshDialog = true}) {
    if (!mounted) return;
    setState(() {
      _inputCtrl.clear();
      _promoCtrl.clear();
      _resultText = '';
      _isInputValid = false;
      _pointsValue = null;
      _priceValue = null;
      _selectedPackage = null;
      _selectedGameId = null;
      _isPointsMode = true;
    });
    if (refreshDialog) {
      _refreshActiveTiktokDialog();
    }
  }

  double? _parseUsdValue(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw.trim());
    return null;
  }

  void _startOrderStatusWatcher() {
    final whatsapp = widget.whatsapp.trim();
    if (whatsapp.isEmpty) return;

    _orderStatusWatchSub?.cancel();
    _orderStatusById.clear();
    _orderStatusWatchPrimed = false;

    _orderStatusWatchSub = FirebaseFirestore.instance
        .collection('orders')
        .where('user_whatsapp', isEqualTo: whatsapp)
        .orderBy('created_at', descending: true)
        .limit(120)
        .snapshots()
        .listen((snapshot) {
          if (!_orderStatusWatchPrimed) {
            for (final doc in snapshot.docs) {
              final data = doc.data();
              _orderStatusById[doc.id] = (data['status'] ?? '')
                  .toString()
                  .trim();
            }
            _orderStatusWatchPrimed = true;
            return;
          }

          for (final change in snapshot.docChanges) {
            final docId = change.doc.id;
            if (change.type == DocumentChangeType.removed) {
              _orderStatusById.remove(docId);
              _processingOrdersOpenedForChat.remove(docId);
              continue;
            }

            final data = change.doc.data() ?? <String, dynamic>{};
            final status = (data['status'] ?? '').toString().trim();
            final previousStatus = _orderStatusById[docId] ?? '';
            _orderStatusById[docId] = status;

            if (status == 'processing' && previousStatus != 'processing') {
              _autoOpenSupportChatForProcessingOrder(docId);
            }
          }
        }, onError: (error, stackTrace) {});
  }

  void _autoOpenSupportChatForProcessingOrder(String orderId) {
    final trimmedOrderId = orderId.trim();
    if (trimmedOrderId.isEmpty || !mounted) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    if (_processingOrdersOpenedForChat.contains(trimmedOrderId)) return;
    _processingOrdersOpenedForChat.add(trimmedOrderId);
    unawaited(
      _openSupportChat(orderId: trimmedOrderId, autoOpenedByStatus: true),
    );
  }

  void _updateWebMetaDescription() {
    if (!kIsWeb) return;
    setMetaDescription(
      'احسب سعر شحن نقاط تيك توك حسب عدد النقاط أو المبلغ، مع عروض خصم حصرية لمستخدمي الموقع والتطبيق.',
    );
  }

  // EN: Initializes widget state.
  // AR: تهيّئ حالة الودجت.
  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      setPageTitle(AppInfo.appName);
      _updateWebMetaDescription();
    }

    _nameCtrl = TextEditingController(text: widget.name);
    _tiktokCtrl.text = widget.tiktok;

    if (widget.whatsapp.isNotEmpty) {
      NotificationService.listenToUserOrders(widget.whatsapp);
      NotificationService.listenToUserRamadanCodes(widget.whatsapp);
      unawaited(NotificationService.initUserNotifications(widget.whatsapp));
      _startOrderStatusWatcher();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!kIsWeb) {
        UpdateManager.check(context);
      }
    });

    _loadTiktokFromProfile();
    _initializeBalancePoints();
    _fetchData();
  }

  // EN: Releases resources.
  // AR: تفرّغ الموارد.
  @override
  void dispose() {
    _balancePointsSub?.cancel();
    _balancePointsByUidSub?.cancel();
    _balancePointsByWhatsappSub?.cancel();
    _pricesSub?.cancel();
    _offersSub?.cancel();
    _orderStatusWatchSub?.cancel();
    _activeTiktokDialogRefresh = null;
    _inputCtrl.dispose();
    _promoCtrl.dispose();
    _nameCtrl.dispose();
    _tiktokCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTiktokFromProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTiktok = (prefs.getString('user_tiktok') ?? '').trim();
      if (savedTiktok.isNotEmpty) {
        setState(() => _tiktokCtrl.text = savedTiktok);
        return;
      }

      final uid = (prefs.getString('user_uid') ?? '').trim();
      final whatsapp = widget.whatsapp.trim().isNotEmpty
          ? widget.whatsapp.trim()
          : (prefs.getString('user_whatsapp') ?? '').trim();

      final users = FirebaseFirestore.instance.collection('users');
      DocumentSnapshot<Map<String, dynamic>>? snap;
      if (uid.isNotEmpty) {
        snap = await users.doc(uid).get();
        if (!snap.exists) {
          final q = await users.where('uid', isEqualTo: uid).limit(1).get();
          if (q.docs.isNotEmpty) snap = q.docs.first;
        }
      }
      snap ??= await users.doc(whatsapp).get();

      final data = snap.data();
      final remoteTiktok = (data?['tiktok'] ?? data?['username'] ?? '')
          .toString()
          .trim();
      if (remoteTiktok.isNotEmpty) {
        setState(() => _tiktokCtrl.text = remoteTiktok);
        prefs.setString('user_tiktok', remoteTiktok);
      }
    } catch (_) {
      // نتجاهل أي خطأ في المزامنة الصامتة
    }
  }

  // EN: Shows Custom Toast.
  // AR: تعرض Custom Toast.
  void _showCustomToast(
    String msg, {
    Color color = TTColors.primaryCyan,
    Duration? duration = const Duration(seconds: 3),
  }) {
    if (!mounted) return;

    IconData? icon;
    if (color == Colors.green) {
      icon = Icons.check_circle;
    } else if (color == Colors.red) {
      icon = Icons.error;
    } else if (color == Colors.orange) {
      icon = Icons.warning_amber_rounded;
    }

    TopSnackBar.show(
      context,
      msg,
      backgroundColor: color,
      textColor: Colors.white,
      icon: icon,
      duration: duration,
    );
  }

  Future<T?> _showBlurDialog<T>({
    required WidgetBuilder builder,
    bool barrierDismissible = false,
    String barrierLabel = 'Dialog',
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: barrierLabel,
      barrierColor: Colors.black.withAlpha(96),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, routeAnimation, secondaryAnimation) =>
          const SizedBox.shrink(),
      transitionBuilder: (_, animation, routeAnimation, secondaryAnimation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final blur = Tween<double>(begin: 0, end: 8).animate(curved);

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur.value, sigmaY: blur.value),
          child: FadeTransition(
            opacity: curved,
            child: SafeArea(child: Builder(builder: builder)),
          ),
        );
      },
    );
  }

  Widget _buildMaterialDialogCard(
    BuildContext context, {
    String? title,
    required Widget content,
    List<Widget>? actions,
    TextStyle? titleStyle,
  }) {
    final size = MediaQuery.sizeOf(context);
    final maxWidth = _resolveDialogMaxWidthForWeb(size: size, requested: 560);
    final constrainedContent = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: content,
    );

    return AlertDialog(
      backgroundColor: TTColors.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: kIsWeb ? 20 : 16,
        vertical: 20,
      ),
      titlePadding: title == null
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      title: title == null
          ? null
          : Text(
              title,
              style:
                  titleStyle ??
                  const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
            ),
      content: constrainedContent,
      actions: actions,
      actionsAlignment: MainAxisAlignment.end,
      actionsOverflowAlignment: OverflowBarAlignment.end,
      actionsOverflowDirection: VerticalDirection.down,
      actionsOverflowButtonSpacing: 8,
      buttonPadding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  double _resolveDialogMaxWidthForWeb({
    required Size size,
    required double requested,
  }) {
    if (!kIsWeb) return requested;
    final cappedRequested = math.min(requested, 500.0);
    final available = math.max(320.0, size.width - 40);
    return math.min(cappedRequested, available);
  }

  Future<void> _openAccountDialog() async {
    if (!mounted) return;
    AppNavigator.pushNamed(context, '/account');
  }

  Future<void> _switchToMerchantMode() async {
    final prefs = await SharedPreferences.getInstance();
    final ref = await _resolveUserDocRef();
    if (ref == null) {
      _showCustomToast('تعذر فتح وضع التاجر حالياً', color: Colors.red);
      return;
    }

    final snap = await ref.get();
    final data = snap.data() ?? <String, dynamic>{};
    final hasMerchantAccess = data['is_merchant'] == true;
    if (!hasMerchantAccess) {
      _showCustomToast(
        'هذا الحساب غير مسجل كتاجر. أكمل طلب التوثيق أولاً.',
        color: Colors.orange,
      );
      return;
    }

    final verified = _isMerchantVerifiedData(data);
    final uid = (data['uid'] ?? prefs.getString('user_uid') ?? '')
        .toString()
        .trim();
    final resolvedName = (data['name'] ?? prefs.getString('user_name') ?? '')
        .toString()
        .trim();
    final resolvedWhatsapp = _normalizeWhatsapp(
      (data['merchant_whatsapp'] ??
              data['whatsapp'] ??
              prefs.getString('user_whatsapp') ??
              widget.whatsapp)
          .toString(),
    );

    if (uid.isNotEmpty) {
      await prefs.setString('user_uid', uid);
    }
    if (resolvedName.isNotEmpty) {
      await prefs.setString('user_name', resolvedName);
    }
    if (resolvedWhatsapp.isNotEmpty) {
      await prefs.setString('user_whatsapp', resolvedWhatsapp);
    }

    await prefs.setBool('is_merchant', true);
    AppInfo.isMerchantApp = true;

    if (!mounted) return;
    if (verified) {
      AppNavigator.pushNamedAndRemoveUntil(
        context,
        '/merchant/orders',
        (route) => false,
      );
      return;
    }

    AppNavigator.pushNamed(context, '/merchant/verify');
  }

  String _normalizedMerchantVerificationStatus(dynamic raw) {
    final status = (raw ?? '').toString().trim().toLowerCase();
    if (status == 'approved') return 'approved';
    if (status == 'pending') return 'pending';
    if (status == 'rejected') return 'rejected';
    return 'not_submitted';
  }

  bool _isMerchantVerifiedData(Map<String, dynamic> data) {
    final status = _normalizedMerchantVerificationStatus(
      data['merchant_verification_status'],
    );
    return data['merchant_verified'] == true || status == 'approved';
  }

  Future<void> _openAboutDialog() async {
    if (!mounted) return;
    if (kIsWeb) return;
    AppNavigator.pushNamed(context, '/about');
  }

  Future<void> _openTiktokDialog() async {
    if (!mounted) return;
    AppNavigator.pushNamed(
      context,
      '/home/tiktok',
      arguments: _homeRouteArguments(forceTikTokCharge: true),
    );
  }

  Future<void> _openGamesDialog() async {
    if (!mounted) return;
    AppNavigator.pushNamed(
      context,
      '/home/games',
      arguments: _homeRouteArguments(showGamesOnly: true),
    );
  }

  void _toggleInputMode() {
    setState(() {
      _isPointsMode = !_isPointsMode;
      _inputCtrl.clear();
      _resultText = "";
      _isInputValid = false;
      _pointsValue = null;
      _priceValue = null;
    });
  }

  Widget _buildTiktokChargeFormContent({
    required bool includeAppName,
    BuildContext? closeContext,
    VoidCallback? refreshDialog,
  }) {
    final String? pricesStatusText = _arePricesReady
        ? null
        : _resolvedPricesStatusMessage();
    final Color pricesStatusColor = _hasPricesError
        ? Colors.orangeAccent
        : TTColors.textGray;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (includeAppName) ...[
          const SizedBox(height: 20),
          Text(
            AppInfo.appName,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: TTColors.textWhite,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 30),
        ],
        TextField(
          controller: _inputCtrl,
          onChanged: (val) {
            _recompute(val);
            refreshDialog?.call();
          },
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: _isPointsMode
                ? "ادخل عدد النقاط المطلوب"
                : "ادخل المبلغ الذي معك",
          ),
        ),
        const SizedBox(height: 15),
        if (pricesStatusText != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              pricesStatusText,
              style: TextStyle(
                color: pricesStatusColor,
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        if (_resultText.isNotEmpty && _resultText != pricesStatusText)
          Text(
            _resultText,
            style: TextStyle(
              color: TTColors.textWhite,
              fontSize: 18,
              fontFamily: 'Cairo',
            ),
          ),
        if (_outOfRange != _OutOfRange.none)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: _buildOutOfRangeCard(),
          ),
        if (_showPromoCodeSection)
          GlassCard(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.all(14),
            borderColor: TTColors.goldAccent.withAlpha(160),
            child: Column(
              children: [
                Text(
                  _offersCardTitle,
                  style: TextStyle(
                    color: TTColors.goldAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
                if (!_isDiscountActive) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _promoCtrl,
                    decoration: const InputDecoration(
                      labelText: "الكود الذهبي",
                      prefixIcon: Icon(Icons.vpn_key, color: Color(0xFFFFD700)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () async {
                      await _activatePromo();
                      refreshDialog?.call();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                      foregroundColor: Colors.black,
                    ),
                    child: const Text("تفعيل"),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _requestDiscountCode,
                      icon: const Icon(Icons.card_giftcard),
                      label: Text(
                        _offersRequestButtonTitle,
                        textAlign: TextAlign.center,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFFD700),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ] else
                  const Text(
                    "✅ تم التفعيل!",
                    style: TextStyle(color: Color(0xFFFFD700)),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        TextButton.icon(
          onPressed: () {
            _toggleInputMode();
            refreshDialog?.call();
          },
          icon: const Icon(Icons.swap_vert),
          label: const Text("تبديل النمط"),
        ),
        const SizedBox(height: 20),
        const SizedBox(height: 14),
        ElevatedButton(
          onPressed: (_arePricesReady && _isInputValid)
              ? () async {
                  final bool isDialogMode = closeContext != null;
                  if (closeContext != null && Navigator.canPop(closeContext)) {
                    Navigator.pop(closeContext);
                  }
                  await _startCheckoutFlow();
                  if (isDialogMode) {
                    _resetTiktokDialogCalculationState(refreshDialog: false);
                  }
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            minimumSize: const Size(double.infinity, 50),
          ),
          child: const Text(
            "طلب الشحن",
            style: TextStyle(fontSize: 18, fontFamily: 'Cairo'),
          ),
        ),
      ],
    );
  }

  void _closeRouteDialogPage() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }
    AppNavigator.pushReplacementNamed(
      context,
      '/home',
      arguments: _homeRouteArguments(),
    );
  }

  Widget _buildRouteDialogPage({
    required String title,
    required Widget child,
    double maxWidth = 620,
    bool contentScrollable = true,
    bool showAccountAction = false,
    bool showThemeAction = false,
    bool showAboutAction = false,
  }) {
    final size = MediaQuery.sizeOf(context);
    Widget content = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxWidth,
        maxHeight: size.height * (kIsWeb ? 0.78 : 0.84),
      ),
      child: child,
    );
    if (contentScrollable) {
      content = SingleChildScrollView(child: content);
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: _buildCompactAppBar(
        showBack: true,
        showLogout: false,
        title: title,
        showAccountAction: showAccountAction,
        showThemeAction: showThemeAction,
        showAboutAction: showAboutAction,
      ),
      body: Stack(
        children: [
          const SnowBackground(),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                child: GlassCard(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.all(16),
                  child: content,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _ensureTiktokHandle() {
    if (_isGameOrder || _isPromoOrder) return true;
    final tiktok = _tiktokCtrl.text.trim();
    if (tiktok.isEmpty) {
      // حاول استخدام القيمة المحفوظة سابقاً
      SharedPreferences.getInstance().then((p) {
        final saved = (p.getString('user_tiktok') ?? '').trim();
        if (saved.isEmpty) {
          _showCustomToast(
            "حساب تيك توك غير مضاف، حدثه من صفحة حسابي",
            color: Colors.orange,
          );
        } else {
          _tiktokCtrl.text = saved;
        }
      });
      return false;
    }
    SharedPreferences.getInstance().then((p) {
      p.setString('user_tiktok', tiktok);
      _syncTiktokToFirestore(tiktok, p);
    });
    return true;
  }

  Future<void> _syncTiktokToFirestore(
    String handle,
    SharedPreferences? prefs,
  ) async {
    if (handle.isEmpty) return;
    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      final uid = p.getString('user_uid') ?? '';
      final whatsapp = p.getString('user_whatsapp') ?? widget.whatsapp;
      final users = FirebaseFirestore.instance.collection('users');

      DocumentReference<Map<String, dynamic>>? ref;
      if (uid.isNotEmpty) {
        ref = users.doc(uid);
        final doc = await ref.get();
        if (!doc.exists) {
          // fallback to query by uid field
          final q = await users.where('uid', isEqualTo: uid).limit(1).get();
          if (q.docs.isNotEmpty) ref = q.docs.first.reference;
        }
      }
      ref ??= users.doc(whatsapp);

      await ref.set({
        'tiktok': handle,
        'username': handle,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // تجاهل أي خطأ غير حرج في المزامنة
    }
  }

  String _normalizeWhatsapp(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '').trim();
  }

  int _toInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is double) return raw.round();
    if (raw is num) return raw.toInt();
    final text = (raw ?? '').toString().trim();
    return int.tryParse(text) ?? 0;
  }

  Future<DocumentReference<Map<String, dynamic>>?> _resolveUserDocRef() async {
    if (_userDocRef != null) return _userDocRef;

    final prefs = await SharedPreferences.getInstance();
    final users = FirebaseFirestore.instance.collection('users');
    final uid = (prefs.getString('user_uid') ?? '').trim();
    final fallbackWhatsapp = (prefs.getString('user_whatsapp') ?? '').trim();
    final whatsapp = _normalizeWhatsapp(
      widget.whatsapp.trim().isNotEmpty ? widget.whatsapp : fallbackWhatsapp,
    );

    if (uid.isNotEmpty) {
      final direct = users.doc(uid);
      final directSnap = await direct.get();
      if (directSnap.exists) {
        _userDocRef = direct;
        return _userDocRef;
      }
      final byUid = await users.where('uid', isEqualTo: uid).limit(1).get();
      if (byUid.docs.isNotEmpty) {
        _userDocRef = byUid.docs.first.reference;
        return _userDocRef;
      }
    }

    if (whatsapp.isNotEmpty) {
      final byWhatsapp = await users
          .where('whatsapp', isEqualTo: whatsapp)
          .limit(1)
          .get();
      if (byWhatsapp.docs.isNotEmpty) {
        _userDocRef = byWhatsapp.docs.first.reference;
        return _userDocRef;
      }

      _userDocRef = users.doc(uid.isNotEmpty ? uid : whatsapp);
      return _userDocRef;
    }

    return null;
  }

  Future<void> _initializeBalancePoints() async {
    await _refreshBalancePoints(forceServer: false);
    await _startBalancePointsListener();
  }

  void _applyBalancePointsFromRaw(dynamic rawPoints) {
    if (!mounted) return;
    final safePoints = _toInt(rawPoints);
    final normalized = safePoints < 0 ? 0 : safePoints;
    if (_balancePoints != normalized) {
      setState(() => _balancePoints = normalized);
    }
  }

  Future<void> _bindBalanceDocListener(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    await _balancePointsSub?.cancel();
    _balancePointsSub = ref.snapshots().listen(
      (snap) {
        final data = snap.data();
        _applyBalancePointsFromRaw(data?['balance_points']);
      },
      onError: (_) {
        // نتجاهل أخطاء الاستماع اللحظي
      },
    );
  }

  Future<void> _startBalancePointsListener() async {
    await _balancePointsSub?.cancel();
    await _balancePointsByUidSub?.cancel();
    await _balancePointsByWhatsappSub?.cancel();
    final ref = await _resolveUserDocRef();
    if (ref != null) {
      _userDocRef = ref;
      await _bindBalanceDocListener(ref);
    }

    final prefs = await SharedPreferences.getInstance();
    final uid = (prefs.getString('user_uid') ?? '').trim();
    final fallbackWhatsapp = (prefs.getString('user_whatsapp') ?? '').trim();
    final whatsapp = _normalizeWhatsapp(
      widget.whatsapp.trim().isNotEmpty ? widget.whatsapp : fallbackWhatsapp,
    );
    final users = FirebaseFirestore.instance.collection('users');

    if (uid.isNotEmpty) {
      _balancePointsByUidSub = users
          .where('uid', isEqualTo: uid)
          .limit(1)
          .snapshots()
          .listen((snap) {
            if (snap.docs.isEmpty) return;
            final doc = snap.docs.first;
            final data = doc.data();
            _applyBalancePointsFromRaw(data['balance_points']);
            final candidateRef = doc.reference;
            if (_userDocRef?.path != candidateRef.path) {
              _userDocRef = candidateRef;
              unawaited(_bindBalanceDocListener(candidateRef));
            }
          });
    }

    if (whatsapp.isNotEmpty) {
      _balancePointsByWhatsappSub = users
          .where('whatsapp', isEqualTo: whatsapp)
          .limit(1)
          .snapshots()
          .listen((snap) {
            if (snap.docs.isEmpty) return;
            final doc = snap.docs.first;
            final data = doc.data();
            _applyBalancePointsFromRaw(data['balance_points']);
            final candidateRef = doc.reference;
            if (_userDocRef?.path != candidateRef.path) {
              _userDocRef = candidateRef;
              unawaited(_bindBalanceDocListener(candidateRef));
            }
          });
    }
  }

  Future<void> _refreshBalancePoints({bool forceServer = true}) async {
    try {
      final ref = await _resolveUserDocRef();
      if (ref == null) return;

      await ref.set({
        'balance_points': FieldValue.increment(0),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      DocumentSnapshot<Map<String, dynamic>> snap;
      if (forceServer) {
        snap = await ref.get(const GetOptions(source: Source.server));
      } else {
        snap = await ref.get();
      }

      final data = snap.data();
      final points = _toInt(data?['balance_points']);
      if (!mounted) return;
      setState(() => _balancePoints = points < 0 ? 0 : points);
    } catch (_) {
      // نتجاهل أي خطأ في تحديث الرصيد
    }
  }

  Future<String?> _createOrderWithOptionalPoints({
    required Map<String, dynamic> payload,
    String? orderId,
  }) async {
    final orders = FirebaseFirestore.instance.collection('orders');
    try {
      late final DocumentReference<Map<String, dynamic>> createdOrderRef;
      if (orderId == null || orderId.trim().isEmpty) {
        createdOrderRef = await orders.add(payload);
      } else {
        createdOrderRef = orders.doc(orderId);
        await createdOrderRef.set(payload, SetOptions(merge: true));
      }
      unawaited(
        _seedOrderChatThread(orderId: createdOrderRef.id, payload: payload),
      );
      unawaited(_notifyNewOrder(orderId: createdOrderRef.id, payload: payload));
      return createdOrderRef.id;
    } catch (_) {
      _showCustomToast("تعذر إنشاء الطلب، حاول مجددًا", color: Colors.red);
      return null;
    }
  }

  Future<void> _notifyNewOrder({
    required String orderId,
    required Map<String, dynamic> payload,
  }) async {
    var merchantWhatsapp = _normalizeWhatsapp(
      (payload['merchant_whatsapp'] ?? '').toString(),
    );
    if (merchantWhatsapp.isEmpty && _selectedMerchant != null) {
      merchantWhatsapp = _normalizeWhatsapp(
        (_selectedMerchant!['whatsapp'] ?? '').toString(),
      );
    }

    if (merchantWhatsapp.isEmpty) {
      final merchantId = (payload['merchant_id'] ?? '').toString().trim();
      if (merchantId.isNotEmpty) {
        try {
          final merchantSnap = await FirebaseFirestore.instance
              .collection('users')
              .doc(merchantId)
              .get();
          final merchantData = merchantSnap.data() ?? <String, dynamic>{};
          merchantWhatsapp = _normalizeWhatsapp(
            (merchantData['merchant_whatsapp'] ?? merchantData['whatsapp'] ?? '')
                .toString(),
          );
        } catch (_) {
          // Ignore lookup failures and fallback to admin notification.
        }
      }
    }

    if (merchantWhatsapp.isNotEmpty) {
      await CloudflareNotifyService.notifyMerchantNewOrder(
        orderId: orderId,
        order: payload,
        merchantWhatsapp: merchantWhatsapp,
      );
      return;
    }
    await CloudflareNotifyService.notifyAdminsNewOrder(
      orderId: orderId,
      order: payload,
    );
  }

  void _resetCheckoutMeta() {
    setState(() {
      _promoLink = null;
      _tiktokChargeMode = _tiktokChargeModeLink;
      _tiktokPasswordForOrder = null;
    });
  }

  // EN: Fetches Data.
  // AR: تجلب Data.
  Future<void> _fetchData() async {
    await _refreshRemoteConfigValues(forceUsdtRefresh: true);
    await _listenToOffers();

    if (mounted) {
      setState(() {
        _isPricesLoading = true;
        _hasPricesError = false;
        _pricesStatusMessage = 'جاري تحميل الأسعار...';
      });
    }
    _refreshActiveTiktokDialog();

    await _pricesSub?.cancel();
    _pricesSub = FirebaseFirestore.instance
        .collection('prices')
        .orderBy('min')
        .snapshots()
        .listen(
          (snap) {
            if (!mounted) return;
            final nextPrices = snap.docs.map((d) => d.data()).toList();
            setState(() {
              _prices = nextPrices;
              _isPricesLoading = false;
              if (nextPrices.isEmpty) {
                _hasPricesError = true;
                _pricesStatusMessage = 'تعذر تحميل الأسعار حالياً';
              } else {
                _hasPricesError = false;
                _pricesStatusMessage = '';
                if (_inputCtrl.text.isEmpty) {
                  _resultText = '';
                  _isInputValid = false;
                }
              }
            });
            _maybePrefillPoints();
            if (_inputCtrl.text.isNotEmpty) _recompute(_inputCtrl.text);
            _maybeAutolaunchPayment();
            _refreshActiveTiktokDialog();
          },
          onError: (Object _, StackTrace stackTrace) {
            if (!mounted) return;
            setState(() {
              _prices = [];
              _isPricesLoading = false;
              _hasPricesError = true;
              _pricesStatusMessage = 'تعذر تحميل الأسعار، حاول تحديث الصفحة';
              _isInputValid = false;
              _resultText = _inputCtrl.text.isEmpty ? '' : _pricesStatusMessage;
            });
            _refreshActiveTiktokDialog();
          },
        );
  }

  double? _tryReadDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  double _resolveOfferRateForPoints({
    required double points,
    required double fallbackRate,
  }) {
    if (!_isDiscountActive ||
        !_isPromoOffersEnabled ||
        !_isSeasonalPromoEnabled) {
      return fallbackRate;
    }
    if (points >= 75000 && _offerRateFor75000 > 0) return _offerRateFor75000;
    if (points >= 50000 && _offerRateFor50000 > 0) return _offerRateFor50000;
    if (points >= 1000 && _offerRateFor1000 > 0) return _offerRateFor1000;
    if (points >= 500 && _offerRateFor500 > 0) return _offerRateFor500;
    if (points >= 100 && _offerRateFor100 > 0) return _offerRateFor100;
    return fallbackRate;
  }

  void _applyOffersData(Map<String, dynamic>? rawData) {
    final data = rawData ?? const <String, dynamic>{};
    final parsed100 =
        _tryReadDouble(data['rate_100']) ?? _tryReadDouble(data['offer5']) ?? 0;
    final parsed500 = _tryReadDouble(data['rate_500']) ?? parsed100;
    final parsed1000 = _tryReadDouble(data['rate_1000']) ?? parsed500;
    final parsed50000 =
        _tryReadDouble(data['rate_50000']) ??
        _tryReadDouble(data['offer50']) ??
        0;
    final parsed75000 = _tryReadDouble(data['rate_75000']) ?? parsed50000;
    final title = (data['title'] as String? ?? '').trim();
    final requestCta = (data['request_cta'] as String? ?? '').trim();
    if (!mounted) return;
    setState(() {
      _offersEnabled = data['enabled'] as bool? ?? true;
      _offerRateFor100 = parsed100;
      _offerRateFor500 = parsed500;
      _offerRateFor1000 = parsed1000;
      _offerRateFor50000 = parsed50000;
      _offerRateFor75000 = parsed75000;
      _offersTitle = title.isEmpty ? '✨ عروض الخصم ✨' : title;
      _offersRequestCta = requestCta.isEmpty
          ? 'اضغط لطلب كود الخصم الخاص بك'
          : requestCta;
    });
    _updateWebMetaDescription();
    if (_isDiscountActive && _inputCtrl.text.isNotEmpty) {
      _recompute(_inputCtrl.text);
    }
    _refreshActiveTiktokDialog();
  }

  Future<void> _listenToOffers() async {
    await _offersSub?.cancel();
    _offersSub = FirebaseFirestore.instance
        .collection('offers')
        .doc('current')
        .snapshots()
        .listen((doc) {
          _applyOffersData(doc.data());
        });
  }

  Future<void> _refreshOffersFromServer() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('offers')
          .doc('current')
          .get(const GetOptions(source: Source.server));
      _applyOffersData(snap.data());
    } catch (_) {
      // إذا فشل جلب السيرفر نكتفي بالاستماع اللحظي.
    }
  }

  Future<void> _refreshUsdPriceFromFirestore() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('currency')
          .get(const GetOptions(source: Source.server));
      final data = snap.data();
      final value = _parseUsdValue(data?['usd_price'] ?? data?['usd_egp']);
      if (value != null && value > 0) {
        if (mounted) setState(() => _usdtPrice = value);
        return;
      }
    } catch (_) {}

    try {
      final snap = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('currency')
          .get();
      final data = snap.data();
      final value = _parseUsdValue(data?['usd_price'] ?? data?['usd_egp']);
      if (value != null && value > 0 && mounted) {
        setState(() => _usdtPrice = value);
      }
    } catch (_) {}
  }

  Future<void> _refreshUsdtPriceFromExternal({
    bool forceRefresh = false,
  }) async {
    final externalPrice = await UsdtPriceService.fetchDiscountedEgpPrice(
      forceRefresh: forceRefresh,
    );
    if (!mounted) return;

    if (externalPrice != null && externalPrice > 0) {
      setState(() {
        _usdtPrice = externalPrice;
      });
    }
  }

  Future<void> _refreshRemoteConfigValues({
    bool forceUsdtRefresh = false,
  }) async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(minutes: 1),
          minimumFetchInterval: Duration.zero,
        ),
      );
      await rc.fetchAndActivate();
      final isRamadanRaw = rc.getBool('is_ramadan');
      final isEidRaw = rc.getBool('is_eid');
      final isRamadanSeason = isRamadanRaw && !isEidRaw;
      final isEidSeason = isEidRaw && !isRamadanRaw;
      setState(() {
        // نوقف استخدام القيم الافتراضية للمحفظة/إنستاباي/باينانس، التاجر يرسلها في الشات.
        _binanceId = '';
        _isRamadanSeason = isRamadanSeason;
        _isEidSeason = isEidSeason;
      });
      await _refreshUsdPriceFromFirestore();
      if (_usdtPrice <= 0) {
        await _refreshUsdtPriceFromExternal(forceRefresh: forceUsdtRefresh);
      }
      _updateWebMetaDescription();
    } catch (e) {
      debugPrint("RemoteConfig error: $e");
      await _refreshUsdPriceFromFirestore();
      if (_usdtPrice <= 0) {
        await _refreshUsdtPriceFromExternal(forceRefresh: forceUsdtRefresh);
      }
    }
  }

  Future<void> _handlePageSwipeRefresh() async {
    await _refreshRemoteConfigValues(forceUsdtRefresh: true);
    await _refreshOffersFromServer();
    await _refreshBalancePoints(forceServer: true);

    if (mounted) {
      setState(() {
        _isPricesLoading = true;
        _hasPricesError = false;
        _pricesStatusMessage = 'جاري تحميل الأسعار...';
      });
    }
    _refreshActiveTiktokDialog();

    try {
      final snap = await FirebaseFirestore.instance
          .collection('prices')
          .orderBy('min')
          .get(const GetOptions(source: Source.server));
      if (mounted) {
        final nextPrices = snap.docs.map((d) => d.data()).toList();
        setState(() {
          _prices = nextPrices;
          _isPricesLoading = false;
          if (nextPrices.isEmpty) {
            _hasPricesError = true;
            _pricesStatusMessage = 'تعذر تحميل الأسعار حالياً';
          } else {
            _hasPricesError = false;
            _pricesStatusMessage = '';
            if (_inputCtrl.text.isEmpty) {
              _resultText = '';
              _isInputValid = false;
            }
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _prices = [];
          _isPricesLoading = false;
          _hasPricesError = true;
          _pricesStatusMessage = 'تعذر تحميل الأسعار، حاول التحديث مرة أخرى';
          _isInputValid = false;
          _resultText = _inputCtrl.text.isEmpty ? '' : _pricesStatusMessage;
        });
      }
    }
    _maybePrefillPoints();
    if (_inputCtrl.text.isNotEmpty) _recompute(_inputCtrl.text);
    _refreshActiveTiktokDialog();
  }

  Widget _wrapWithSwipeRefresh(Widget child) {
    return CustomMaterialIndicator(
      onRefresh: _handlePageSwipeRefresh,
      color: TTColors.primaryCyan,
      backgroundColor: TTColors.cardBg,
      child: child,
    );
  }

  void _maybePrefillPoints() {
    if (widget.prefillPoints != null &&
        widget.prefillPoints! > 0 &&
        _inputCtrl.text.isEmpty) {
      _inputCtrl.text = widget.prefillPoints!.toString();
      _recompute(_inputCtrl.text);
    }
  }

  Future<void> _maybeAutolaunchPayment() async {
    if (!widget.autolaunchPayment) return;
    if (!_isInputValid) return;
    // حد الإلغاء 5 خلال 24 ساعة
    final ok = await _checkCancelLimit();
    if (!ok) return;
    await _startCheckoutFlow();
  }

  // EN: Handles activate Promo.
  // AR: تتعامل مع activate Promo.
  Future<void> _activatePromo() async {
    if (!_showPromoCodeSection) {
      _showCustomToast("أكواد الخصم غير متاحة حالياً", color: Colors.orange);
      return;
    }
    final String code = _promoCtrl.text.trim().toUpperCase().replaceAll(
      "-",
      "",
    );
    if (code.isEmpty) {
      _showCustomToast("الرجاء كتابة الكود", color: Colors.orange);
      return;
    }

    await EasyLoadingService.show(status: 'جاري التحقق...');

    try {
      final docRef = FirebaseFirestore.instance
          .collection('promo_codes')
          .doc(code);
      final doc = await docRef.get();

      if (!mounted) return;

      if (!doc.exists) {
        _showCustomToast("الكود غير صحيح ❌", color: Colors.red);
        return;
      }
      if (doc.data()!['is_used'] == true) {
        _showCustomToast("تم استخدامه من قبل 🚫", color: Colors.red);
        return;
      }

      await docRef.update({'is_used': true});
      if (!mounted) return;
      setState(() => _isDiscountActive = true);

      if (_inputCtrl.text.isNotEmpty) _recompute(_inputCtrl.text);
      _refreshActiveTiktokDialog();

      _showCustomToast("تم التفعيل! 🎉", color: Colors.green);
    } catch (e) {
      if (!mounted) return;
      _showCustomToast("خطأ في التحقق", color: Colors.red);
      _refreshActiveTiktokDialog();
    } finally {
      await EasyLoadingService.dismiss();
    }
  }

  // EN: Requests Discount Code.
  // AR: تطلب كود خصم.
  Future<void> _requestDiscountCode() async {
    if (!_showPromoCodeSection) {
      _showCustomToast("أكواد الخصم غير متاحة حالياً", color: Colors.orange);
      return;
    }
    final tiktokHandle = _tiktokCtrl.text.trim();
    if (_nameCtrl.text.isEmpty ||
        widget.whatsapp.isEmpty ||
        tiktokHandle.isEmpty) {
      _showCustomToast("البيانات ناقصة", color: Colors.red);
      return;
    }

    await EasyLoadingService.show(status: 'جاري إرسال الطلب...');

    try {
      final existing = await FirebaseFirestore.instance
          .collection('code_requests')
          .where('whatsapp', isEqualTo: widget.whatsapp)
          .where('status', isEqualTo: 'pending')
          .get();

      if (!mounted) return;
      if (existing.docs.isNotEmpty) {
        _showCustomToast("لديك طلب قيد الانتظار", color: Colors.orange);
        return;
      }

      final reqRef = await FirebaseFirestore.instance
          .collection('code_requests')
          .add({
            'name': _nameCtrl.text,
            'whatsapp': widget.whatsapp,
            'tiktok': tiktokHandle,
            'status': 'pending',
            'created_at': FieldValue.serverTimestamp(),
          });
      unawaited(
        CloudflareNotifyService.notifyAdminsCodeRequest(
          requestId: reqRef.id,
          name: _nameCtrl.text,
          whatsapp: widget.whatsapp,
          tiktok: tiktokHandle,
        ),
      );

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => _buildMaterialDialogCard(
          ctx,
          title: "تم إرسال الطلب",
          titleStyle: const TextStyle(
            color: TTColors.goldAccent,
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
          content: Text(
            "سيتم مراجعة طلبك، تابع قسم الأكواد.",
            style: TextStyle(color: TTColors.textWhite),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("حسناً"),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showCustomToast("خطأ في الطلب", color: Colors.red);
    } finally {
      await EasyLoadingService.dismiss();
    }
  }

  // EN: Calculates calculate.
  // AR: تحسب calculate.
  void _recompute(String val) {
    _isInputValid = false;
    _resultText = "";
    _pointsValue = null;
    _priceValue = null;
    _selectedPackage = null;
    _selectedGameId = null;
    _outOfRange = _OutOfRange.none;

    if (val.isEmpty) {
      setState(() {});
      _refreshActiveTiktokDialog();
      return;
    }

    if (!_arePricesReady) {
      _resultText = _resolvedPricesStatusMessage();
      setState(() {});
      _refreshActiveTiktokDialog();
      return;
    }

    final double inputVal = double.tryParse(val) ?? 0;

    if (_isPointsMode) {
      if (inputVal < _minPoints || inputVal > _maxPoints) {
        _outOfRange = inputVal < _minPoints
            ? _OutOfRange.belowMin
            : _OutOfRange.aboveMax;
        _isInputValid = false;
        setState(() {});
        _refreshActiveTiktokDialog();
        return;
      }

      final firstRange = _prices.first;
      final lastRange = _prices.last;
      final rule = _prices.firstWhere(
        (r) => inputVal >= r['min'] && inputVal <= r['max'],
        orElse: () {
          final firstMin = (firstRange['min'] as num?)?.toDouble() ?? 0;
          return inputVal < firstMin ? firstRange : lastRange;
        },
      );

      double rate = rule['pricePer1000'].toDouble();
      rate = _resolveOfferRateForPoints(points: inputVal, fallbackRate: rate);

      final rawPrice = (inputVal / 1000) * rate;
      _priceValue = _ceilToNearestFive(rawPrice);
      _pointsValue = inputVal.round();
      _resultText = "السعر: $_priceValue جنيه";
      _isInputValid = true;
    } else {
      final hasFractions = val.contains('.') || val.contains(',');
      if (hasFractions || inputVal % 1 != 0) {
        _resultText = "أدخل مبلغًا صحيحًا ينتهي بـ 0 أو 5 (بدون كسور)";
        _isInputValid = false;
        setState(() {});
        _refreshActiveTiktokDialog();
        return;
      }

      final int amountInt = inputVal.toInt();
      final lastDigit = amountInt % 10;
      final isAllowedEnding = lastDigit == 0 || lastDigit == 5;
      if (!isAllowedEnding) {
        _resultText =
            "المبلغ يجب أن ينتهي بـ 0 أو 5 فقط. لا نقبل الفكة أو القروش.";
        setState(() {});
        _refreshActiveTiktokDialog();
        return;
      }

      final normalizedAmount = amountInt;
      int bestPoints = 0;
      bool foundTier = false;

      final reversedPrices = _prices.reversed.toList();
      for (var rule in reversedPrices) {
        final baseRate = rule['pricePer1000'].toDouble();
        int potentialPoints = ((normalizedAmount * 1000) / baseRate).floor();
        final appliedRate = _resolveOfferRateForPoints(
          points: potentialPoints.toDouble(),
          fallbackRate: baseRate,
        );
        potentialPoints = ((normalizedAmount * 1000) / appliedRate).floor();

        if (potentialPoints >= rule['min']) {
          bestPoints = potentialPoints;
          foundTier = true;
          break;
        }
      }

      if (!foundTier) {
        double rate = _prices.first['pricePer1000'].toDouble();
        bestPoints = ((normalizedAmount * 1000) / rate).floor();
      }

      if (bestPoints < _minPoints || bestPoints > _maxPoints) {
        _outOfRange = bestPoints < _minPoints
            ? _OutOfRange.belowMin
            : _OutOfRange.aboveMax;
        _pointsValue = bestPoints;
        _priceValue = inputVal.ceil();
        _isInputValid = false;
        setState(() {});
        _refreshActiveTiktokDialog();
        return;
      }

      _pointsValue = bestPoints;
      _priceValue = normalizedAmount;
      _resultText = "النقاط: $bestPoints نقطة";
      _isInputValid = true;
    }

    setState(() {});
    _refreshActiveTiktokDialog();
  }

  bool get _isGameOrder => _selectedPackage != null;
  bool get _isPromoOrder => (_promoLink ?? '').isNotEmpty;

  _OutOfRange _outOfRange = _OutOfRange.none;

  int _ceilToNearestFive(num value) {
    final rounded = value.ceil();
    final rem = rounded % 5;
    return rem == 0 ? rounded : rounded + (5 - rem);
  }

  int? _validateWholeAmountEnding({
    required String raw,
    int? min,
    int? max,
    bool allowZero = false,
  }) {
    final normalized = raw.replaceAll(',', '.').trim();
    final amountDouble = double.tryParse(normalized);
    if (amountDouble == null || amountDouble % 1 != 0) {
      _showCustomToast(
        "أدخل مبلغًا صحيحًا ينتهي بـ 0 أو 5 (بدون كسور)",
        color: Colors.orange,
      );
      return null;
    }
    final amount = amountDouble.toInt();
    if (!allowZero && amount == 0) {
      _showCustomToast("المبلغ يجب أن يكون أكبر من صفر", color: Colors.orange);
      return null;
    }
    if (min != null && amount < min) {
      _showCustomToast("أقل مبلغ مسموح هو $min", color: Colors.orange);
      return null;
    }
    if (max != null && amount > max) {
      _showCustomToast("أقصى مبلغ مسموح هو $max", color: Colors.orange);
      return null;
    }
    final lastDigit = amount % 10;
    if (lastDigit != 0 && lastDigit != 5) {
      _showCustomToast(
        "المبلغ يجب أن ينتهي بـ 0 أو 5 فقط. لا نقبل الفكة أو القروش.",
        color: Colors.orange,
      );
      return null;
    }
    return amount;
  }

  Widget _buildOutOfRangeCard() {
    String message;
    if (_outOfRange == _OutOfRange.aboveMax) {
      message = "الحد الأقصى للشحن $_maxPoints عملة.";
    } else {
      message = "الحد الأدنى للشحن $_minPoints عملة.";
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orange, width: 1.4),
        borderRadius: BorderRadius.circular(12),
        color: Colors.orange.withAlpha(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                color: TTColors.textWhite,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _gameOrderTitle(GamePackage pkg) {
    final gameName = GamePackage.gameLabel(pkg.game);
    return "$gameName - ${pkg.label}";
  }

  IconData _gameIcon(String game) {
    switch (game) {
      case 'pubg':
        return Icons.sports_esports;
      case 'freefire':
        return Icons.local_fire_department;
      case 'cod':
        return Icons.shield;
      default:
        return Icons.videogame_asset;
    }
  }

  Widget _buildGamePackagesList({BuildContext? closeContext}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('game_packages')
          .where('enabled', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              "حدث خطأ أثناء تحميل الباقات",
              style: TextStyle(color: TTColors.textGray),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(color: TTColors.primaryCyan),
            ),
          );
        }

        final packages =
            snapshot.data!.docs.map((d) => GamePackage.fromDoc(d)).toList()
              ..sort((a, b) {
                final order = {'pubg': 0, 'freefire': 1, 'cod': 2};
                final g1 = order[a.game] ?? 9;
                final g2 = order[b.game] ?? 9;
                if (g1 != g2) return g1.compareTo(g2);
                return a.sort.compareTo(b.sort);
              });

        if (packages.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              "لا توجد باقات حالياً",
              style: TextStyle(color: TTColors.textGray),
            ),
          );
        }

        final Map<String, List<GamePackage>> grouped = {};
        for (final pkg in packages) {
          grouped.putIfAbsent(pkg.game, () => []).add(pkg);
        }

        final games = GamePackage.gameOrder()
            .where((g) => grouped[g]?.isNotEmpty ?? false)
            .toList();

        return ExpansionPanelList.radio(
          expandedHeaderPadding: EdgeInsets.zero,
          children: games.map((game) {
            final gamePackages = grouped[game] ?? const [];
            return ExpansionPanelRadio(
              value: game,
              canTapOnHeader: true,
              headerBuilder: (context, isExpanded) {
                return ListTile(
                  leading: Icon(_gameIcon(game)),
                  title: Text(
                    GamePackage.gameLabel(game),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              },
              body: Column(
                children: gamePackages
                    .map(
                      (pkg) => ListTile(
                        leading: const Icon(Icons.local_offer_outlined),
                        title: Text(pkg.label),
                        subtitle: Text(
                          "السعر: ${pkg.price} جنيه",
                          style: TextStyle(color: TTColors.textGray),
                        ),
                        onTap: () async {
                          if (closeContext != null &&
                              Navigator.canPop(closeContext)) {
                            Navigator.pop(closeContext);
                          }
                          await _handleGamePackageSelected(pkg);
                        },
                      ),
                    )
                    .toList(),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _handleGamePackageSelected(GamePackage pkg) async {
    await NotificationService.requestPermission();
    final id = await _promptGameId(pkg);
    if (id == null || id.isEmpty) return;

    setState(() {
      _selectedPackage = pkg;
      _selectedGameId = id;
      _priceValue = pkg.price;
      _isInputValid = true;
    });

    _startCheckoutFlow();
  }

  Future<String?> _promptGameId(GamePackage pkg) async {
    final controller = TextEditingController();
    String? result;

    await _showBlurDialog<void>(
      barrierLabel: 'game-id-dialog',
      builder: (ctx) => _buildMaterialDialogCard(
        ctx,
        title: _gameOrderTitle(pkg),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: "ادخل الـ ID"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            onPressed: () {
              result = controller.text.trim();
              Navigator.pop(ctx);
            },
            child: const Text("متابعة"),
          ),
        ],
      ),
    );

    return result;
  }

  Future<void> _startCheckoutFlow() async {
    if (!await _checkCancelLimit()) return;
    if (!_isInputValid && !_isGameOrder && !_isPromoOrder) return;

    if (_isGameOrder || _isPromoOrder) {
      _tiktokChargeMode = _tiktokChargeModeLink;
      _tiktokPasswordForOrder = null;
      await _refreshBalancePoints(forceServer: true);
      if (!await _ensureMerchantSelected(forcePrompt: true)) return;
      _openPaymentDialogSafely();
      return;
    }

    if (!_ensureTiktokHandle()) return;

    final selectedMode = await _showTiktokChargeModeDialog();
    if (!mounted || selectedMode == null) return;

    if (selectedMode == _tiktokChargeModeLink ||
        selectedMode == _tiktokChargeModeQr) {
      setState(() {
        _tiktokChargeMode = selectedMode;
        _tiktokPasswordForOrder = null;
      });
      await _refreshBalancePoints(forceServer: true);
      if (!await _ensureMerchantSelected(forcePrompt: true)) return;
      _openPaymentDialogSafely();
      return;
    }

    final password = await _showTiktokPasswordDialog();
    if (!mounted || password == null) return;

    setState(() {
      _tiktokChargeMode = _tiktokChargeModeUserPass;
      _tiktokPasswordForOrder = password;
    });

    await _refreshBalancePoints(forceServer: true);
    if (!await _ensureMerchantSelected(forcePrompt: true)) return;
    _openPaymentDialogSafely();
  }

  void _openPaymentDialogSafely() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (!await _ensureSelectedMerchantOnlineForCheckout()) return;
      if (!mounted) return;
      _showPaymentDialog();
    });
  }

  Future<String?> _showTiktokChargeModeDialog() async {
    return _showBlurDialog<String>(
      barrierLabel: 'tiktok-charge-mode-dialog',
      builder: (ctx) {
        final size = MediaQuery.sizeOf(ctx);
        final maxWidth = _resolveDialogMaxWidthForWeb(
          size: size,
          requested: 560,
        );
        return Dialog(
          backgroundColor: TTColors.cardBg,
          shape: Dialogs.dialogShape,
          insetPadding: EdgeInsets.symmetric(
            horizontal: kIsWeb ? 20 : 16,
            vertical: 20,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: DialogWidget(
              color: TTColors.cardBg,
              title: "اختيار طريقة الشحن",
              titleStyle: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
              customViewPosition: CustomViewPosition.BEFORE_ACTION,
              customView: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      "اختار طريقة شحن عملات تيك توك قبل اختيار وسيلة الدفع.",
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      "تنبيه: في حالة اختيار يوزر + باسورد يجب أن يكون التحقق بخطوتين مغلق.",
                      style: TextStyle(
                        color: Colors.orangeAccent,
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx, _tiktokChargeModeLink);
                      },
                      child: const Text("الشحن بلينك"),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx, _tiktokChargeModeQr);
                      },
                      child: const Text("الشحن بـ QR"),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx, _tiktokChargeModeUserPass);
                      },
                      child: const Text("يوزر + باسورد"),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("إلغاء"),
                    ),
                  ),
                ],
              ),
              actions: const [],
            ),
          ),
        );
      },
    );
  }

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

  // EN: Shows Payment Dialog.
  // AR: تعرض Payment Dialog.
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

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "Pay",
      barrierColor: Colors.black.withAlpha(96),
      pageBuilder: (_, routeAnimation, secondaryAnimation) => const SizedBox(),
      transitionBuilder: (ctx, anim, routeAnimation, secondaryAnimation) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOut);
        final blur = Tween<double>(begin: 0, end: 8).animate(curved);
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur.value, sigmaY: blur.value),
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, -1),
              end: Offset.zero,
            ).animate(curved),
            child: SafeArea(
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Builder(
                        builder: (ctx) {
                          final payableAmount = totalAmount;
                          return GlassCard(
                            margin: EdgeInsets.zero,
                            padding: const EdgeInsets.all(24),
                            borderColor: TTColors.primaryCyan.withAlpha(140),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  "وسيلة الدفع",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                                const SizedBox(height: 10),
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
                                      color: TTColors.textWhite,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if ((_selectedGameId ?? '').isNotEmpty)
                                    Text(
                                      "ID: $_selectedGameId",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: TTColors.textGray,
                                      ),
                                    ),
                                ],
                                const SizedBox(height: 18),
                                _payOption(
                                  "فودافون كاش / محفظة",
                                  Icons.account_balance_wallet,
                                  Colors.orange,
                                  () => _processWalletOrder(
                                    payableAmount: payableAmount,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _payOption(
                                  "InstaPay",
                                  Icons.qr_code,
                                  Colors.purpleAccent,
                                  () => _processInstaPay(
                                    payableAmount: payableAmount,
                                  ),
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
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => Navigator.pop(ctx),
                                    icon: const Icon(Icons.close),
                                    label: const Text("إلغاء"),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
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
  }

  // EN: Handles pay Option.
  // AR: تتعامل مع pay Option.
  Widget _payOption(String t, IconData i, Color c, VoidCallback tap) {
    return ListTile(
      leading: Icon(i, color: c),
      title: Text(t, style: const TextStyle(fontFamily: 'Cairo')),
      onTap: tap,
      tileColor: TTColors.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _payOptionWithLeading(String t, Widget leading, VoidCallback tap) {
    return ListTile(
      leading: leading,
      title: Text(t, style: const TextStyle(fontFamily: 'Cairo')),
      onTap: tap,
      tileColor: TTColors.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  String _formatUsdtAmount(double amount) => amount.toStringAsFixed(2);

  double? _computeOrderUsdtAmount({required int egpAmount}) {
    if (egpAmount <= 0 || _usdtPrice <= 0) return null;
    return egpAmount / _usdtPrice;
  }

  bool _isMerchantOnline(Map<String, dynamic> merchant) {
    final manualOfflineRaw = merchant['merchant_manual_offline_raw'];
    if (manualOfflineRaw is bool) {
      // لو التاجر اختار الحالة يدويًا، نعتمدها مباشرة للمستخدمين.
      return !manualOfflineRaw;
    }

    if (merchant['merchant_manual_offline'] == true) return false;
    if (merchant['merchant_online'] != true) return false;
    final lastSeen = merchant['merchant_last_seen'];
    if (lastSeen is! Timestamp) {
      // بعض الحسابات القديمة قد لا تحتوي last_seen رغم تفعيل الحالة.
      return true;
    }
    // اعتبر التاجر متصلاً طالما آخر نبضة خلال 3 دقائق.
    return DateTime.now().difference(lastSeen.toDate()).inSeconds <= 180;
  }

  DateTime? _dateFromFirestore(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }

  bool _isMerchantSubscriptionActive(Map<String, dynamic> data, DateTime now) {
    final trialEnds = data['merchant_trial_ends_at'];
    final paidUntil = data['merchant_paid_until'];
    final trialActive =
        trialEnds is Timestamp && now.isBefore(trialEnds.toDate());
    final paidActive =
        paidUntil is Timestamp && now.isBefore(paidUntil.toDate());
    return trialActive || paidActive;
  }

  int _merchantProfileScore({
    required bool isMerchant,
    required bool verified,
    required bool active,
    required bool subscriptionActive,
    required bool blocked,
    required String uid,
    required String whatsapp,
  }) {
    var score = 0;
    if (isMerchant) score += 1000;
    if (verified) score += 200;
    if (active) score += 120;
    if (subscriptionActive) score += 80;
    if (!blocked) score += 30;
    if (uid.isNotEmpty) score += 10;
    if (whatsapp.isNotEmpty) score += 5;
    return score;
  }

  bool _isMoreRecentCandidate({
    required DateTime? next,
    required DateTime? current,
  }) {
    if (current == null) return true;
    if (next == null) return false;
    return next.isAfter(current);
  }

  List<Map<String, dynamic>> _extractActiveMerchants(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final now = DateTime.now();
    final grouped = <String, _MerchantGroupState>{};
    final groupAliases = <String, String>{};

    for (final doc in docs) {
      final data = doc.data();
      final docId = doc.id.trim();
      final merchantUid = (data['uid'] ?? '').toString().trim();
      final merchantWhatsapp = _normalizeWhatsapp(
        (data['merchant_whatsapp'] ?? data['whatsapp'] ?? '').toString(),
      );
      final merchantId = merchantUid.isNotEmpty ? merchantUid : docId;
      if (merchantId.isEmpty && merchantWhatsapp.isEmpty) continue;

      final uidKey = merchantUid.isNotEmpty ? 'uid:$merchantUid' : null;
      final whatsappKey = merchantWhatsapp.isNotEmpty
          ? 'wa:$merchantWhatsapp'
          : null;
      final aliasedUidGroup = uidKey == null ? null : groupAliases[uidKey];
      final aliasedWhatsappGroup = whatsappKey == null
          ? null
          : groupAliases[whatsappKey];
      final groupKey =
          aliasedUidGroup ??
          aliasedWhatsappGroup ??
          uidKey ??
          whatsappKey ??
          'doc:$docId';
      if (uidKey != null) {
        groupAliases[uidKey] = groupKey;
      }
      if (whatsappKey != null) {
        groupAliases[whatsappKey] = groupKey;
      }

      final group = grouped.putIfAbsent(groupKey, _MerchantGroupState.new);

      final trialEnds = data['merchant_trial_ends_at'];
      final paidUntil = data['merchant_paid_until'];
      final candidate = <String, dynamic>{
        'id': merchantId,
        'uid': merchantUid,
        'name': (data['name'] ?? data['username'] ?? 'تاجر').toString(),
        'whatsapp': merchantWhatsapp,
        'merchant_online': data['merchant_online'] == true,
        'merchant_manual_offline_raw': data['merchant_manual_offline'],
        'merchant_manual_offline': data['merchant_manual_offline'] == true,
        'merchant_last_seen': data['merchant_last_seen'],
        'merchant_verified': _isMerchantVerifiedData(data),
        'trial_ends_at': trialEnds,
        'paid_until': paidUntil,
      };

      final presenceTimestamp =
          _dateFromFirestore(data['merchant_last_seen']) ??
          _dateFromFirestore(data['updated_at']) ??
          _dateFromFirestore(data['created_at']);
      if (group.presenceCandidate == null ||
          _isMoreRecentCandidate(
            next: presenceTimestamp,
            current: group.presenceTimestamp,
          )) {
        group.presenceCandidate = candidate;
        group.presenceTimestamp = presenceTimestamp;
      }

      final accountStatus = (data['account_status'] ?? 'active')
          .toString()
          .trim()
          .toLowerCase();
      final blocked =
          accountStatus == 'blocked' || accountStatus == 'suspended';
      final active = data['merchant_active'] != false;
      final verified = _isMerchantVerifiedData(data);
      final isMerchant = data['is_merchant'] == true;
      final subscriptionActive = _isMerchantSubscriptionActive(data, now);
      if (blocked ||
          !active ||
          !verified ||
          !subscriptionActive ||
          !isMerchant) {
        continue;
      }

      final profileScore = _merchantProfileScore(
        isMerchant: isMerchant,
        verified: verified,
        active: active,
        subscriptionActive: subscriptionActive,
        blocked: blocked,
        uid: merchantUid,
        whatsapp: merchantWhatsapp,
      );
      final profileTimestamp =
          _dateFromFirestore(data['updated_at']) ??
          _dateFromFirestore(data['created_at']);
      if (group.profileCandidate == null ||
          profileScore > group.profileScore ||
          (profileScore == group.profileScore &&
              _isMoreRecentCandidate(
                next: profileTimestamp,
                current: group.profileTimestamp,
              ))) {
        group.profileCandidate = candidate;
        group.profileScore = profileScore;
        group.profileTimestamp = profileTimestamp;
      }
    }

    final merchants = <Map<String, dynamic>>[];
    for (final group in grouped.values) {
      final profile = group.profileCandidate;
      if (profile == null) continue;
      final merged = Map<String, dynamic>.from(profile);
      final presence = group.presenceCandidate;
      if (presence != null) {
        merged['merchant_online'] = presence['merchant_online'] == true;
        merged['merchant_manual_offline_raw'] =
            presence['merchant_manual_offline_raw'];
        merged['merchant_manual_offline'] =
            presence['merchant_manual_offline'] == true;
        if (presence['merchant_last_seen'] != null) {
          merged['merchant_last_seen'] = presence['merchant_last_seen'];
        }
        final mergedUid = (merged['uid'] ?? '').toString().trim();
        final presenceUid = (presence['uid'] ?? '').toString().trim();
        if (mergedUid.isEmpty && presenceUid.isNotEmpty) {
          merged['uid'] = presenceUid;
          merged['id'] = presenceUid;
        }
        final mergedWhatsapp = (merged['whatsapp'] ?? '').toString().trim();
        final presenceWhatsapp = (presence['whatsapp'] ?? '').toString().trim();
        if (mergedWhatsapp.isEmpty && presenceWhatsapp.isNotEmpty) {
          merged['whatsapp'] = presenceWhatsapp;
        }
      }

      final finalUid = (merged['uid'] ?? '').toString().trim();
      if (finalUid.isNotEmpty) {
        merged['id'] = finalUid;
      }
      final finalId = (merged['id'] ?? '').toString().trim();
      if (finalId.isEmpty) continue;
      if ((merged['name'] ?? '').toString().trim().isEmpty) {
        merged['name'] = 'تاجر';
      }
      merchants.add(merged);
    }

    merchants.sort((a, b) {
      final aOnline = _isMerchantOnline(a);
      final bOnline = _isMerchantOnline(b);
      if (aOnline != bOnline) return aOnline ? -1 : 1;
      final aName = (a['name'] ?? '').toString();
      final bName = (b['name'] ?? '').toString();
      return aName.compareTo(bName);
    });

    return merchants;
  }

  Future<Map<String, dynamic>?> _pickMerchant() async {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        final maxSheetHeight = math.min(
          MediaQuery.sizeOf(ctx).height * 0.62,
          500.0,
        );
        return SafeArea(
          child: GlassCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(12),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxSheetHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'اختر التاجر للتواصل والشحن',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    fit: FlexFit.loose,
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .where('is_merchant', isEqualTo: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'تعذر تحميل التجار حالياً.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          );
                        }
                        if (!snapshot.hasData) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final merchants = _extractActiveMerchants(
                          snapshot.data!.docs,
                        );
                        if (merchants.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'لا يوجد تجار متاحون حالياً.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          );
                        }

                        final shouldScroll = merchants.length > 4;
                        return ListView.separated(
                          shrinkWrap: !shouldScroll,
                          physics: shouldScroll
                              ? const AlwaysScrollableScrollPhysics()
                              : const NeverScrollableScrollPhysics(),
                          itemCount: merchants.length,
                          separatorBuilder: (_, index) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final m = merchants[index];
                            final online = _isMerchantOnline(m);
                            final verified = m['merchant_verified'] == true;
                            final name = (m['name'] ?? 'تاجر').toString();
                            final wa = (m['whatsapp'] ?? '').toString();
                            return ListTile(
                              leading: Icon(
                                online ? Icons.circle : Icons.circle_outlined,
                                color: online ? Colors.green : Colors.red,
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        fontFamily: 'Cairo',
                                      ),
                                    ),
                                  ),
                                  if (verified)
                                    const Icon(
                                      Icons.verified,
                                      size: 18,
                                      color: Colors.green,
                                    ),
                                ],
                              ),
                              subtitle: Text(
                                wa.isEmpty
                                    ? 'واتساب غير متوفر'
                                    : '${online ? 'متصل الآن' : 'غير متصل الآن'} • $wa',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              onTap: () => Navigator.pop(ctx, m),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<bool> _ensureMerchantSelected({bool forcePrompt = false}) async {
    if (!forcePrompt && _selectedMerchant != null) return true;
    final merchant = await _pickMerchant();
    if (!mounted || merchant == null) return false;
    setState(() => _selectedMerchant = merchant);
    return true;
  }

  Future<Map<String, dynamic>?> _loadLatestSelectedMerchant() async {
    final selected = _selectedMerchant;
    if (selected == null) return null;

    final users = FirebaseFirestore.instance.collection('users');
    final selectedUid = (selected['uid'] ?? '').toString().trim();
    final selectedId = (selected['id'] ?? '').toString().trim();
    final selectedWhatsapp = _normalizeWhatsapp(
      (selected['whatsapp'] ?? '').toString(),
    );

    QueryDocumentSnapshot<Map<String, dynamic>>? latestDoc;

    Future<void> tryByUid(String uid) async {
      if (uid.isEmpty || latestDoc != null) return;
      final byUid = await users.where('uid', isEqualTo: uid).limit(1).get();
      if (byUid.docs.isNotEmpty) {
        latestDoc = byUid.docs.first;
      }
    }

    if (selectedUid.isNotEmpty) {
      final direct = await users.doc(selectedUid).get();
      if (direct.exists) {
        final data = direct.data() ?? <String, dynamic>{};
        final merged = Map<String, dynamic>.from(selected);
        merged.addAll(data);
        merged['id'] = direct.id;
        return merged;
      }
      await tryByUid(selectedUid);
    }

    if (latestDoc == null && selectedId.isNotEmpty) {
      final direct = await users.doc(selectedId).get();
      if (direct.exists) {
        final data = direct.data() ?? <String, dynamic>{};
        final merged = Map<String, dynamic>.from(selected);
        merged.addAll(data);
        merged['id'] = direct.id;
        return merged;
      }
      await tryByUid(selectedId);
    }

    if (latestDoc == null && selectedWhatsapp.isNotEmpty) {
      final byMerchantWhatsapp = await users
          .where('merchant_whatsapp', isEqualTo: selectedWhatsapp)
          .limit(1)
          .get();
      if (byMerchantWhatsapp.docs.isNotEmpty) {
        latestDoc = byMerchantWhatsapp.docs.first;
      } else {
        final byWhatsapp = await users
            .where('whatsapp', isEqualTo: selectedWhatsapp)
            .limit(1)
            .get();
        if (byWhatsapp.docs.isNotEmpty) {
          latestDoc = byWhatsapp.docs.first;
        }
      }
    }

    if (latestDoc == null) return null;
    final data = latestDoc!.data();
    final merged = Map<String, dynamic>.from(selected);
    merged.addAll(data);
    merged['id'] = latestDoc!.id;
    return merged;
  }

  Future<bool> _ensureSelectedMerchantOnlineForCheckout() async {
    final selected = _selectedMerchant;
    if (selected == null) {
      _showCustomToast("اختر التاجر أولاً", color: Colors.orange);
      return false;
    }

    Map<String, dynamic> merchant = Map<String, dynamic>.from(selected);
    try {
      final latest = await _loadLatestSelectedMerchant();
      if (latest != null) {
        merchant = latest;
        if (mounted) {
          setState(() => _selectedMerchant = latest);
        } else {
          _selectedMerchant = latest;
        }
      }
    } catch (_) {
      // إذا تعذر التحديث نستخدم آخر حالة متاحة.
    }

    if (!_isMerchantOnline(merchant)) {
      _showCustomToast(
        "التاجر الذي تم اختياره غير متصل الآن",
        color: Colors.orange,
      );
      return false;
    }
    return true;
  }

  Map<String, dynamic> _buildOrderPayload({
    required String method,
    required String status,
    String? paymentTarget,
    String? instapayLink,
    String? binanceId,
    String? usdtAmount,
    double? usdtPrice,
    int? priceOverride,
  }) {
    final totalPriceValue = _priceValue ?? 0;
    final payablePrice = (priceOverride ?? totalPriceValue).clamp(0, 100000000);
    final tiktokHandle = _tiktokCtrl.text.trim();
    final data = <String, dynamic>{
      'name': _nameCtrl.text,
      'user_whatsapp': widget.whatsapp,
      'user_tiktok': tiktokHandle,
      'price': payablePrice.toString(),
      'original_price': totalPriceValue.toString(),
      'method': method,
      if (paymentTarget != null && paymentTarget.trim().isNotEmpty)
        'payment_target': paymentTarget.trim(),
      if (instapayLink != null && instapayLink.trim().isNotEmpty)
        'instapay_link': ensureHttps(instapayLink.trim()),
      if (binanceId != null && binanceId.trim().isNotEmpty)
        'binance_id': binanceId.trim(),
      if (usdtAmount != null && usdtAmount.trim().isNotEmpty)
        'usdt_amount': usdtAmount.trim(),
      if (usdtPrice != null && usdtPrice > 0) 'usdt_price': usdtPrice,
      'status': status,
      'created_at': FieldValue.serverTimestamp(),
    };
    if (_selectedMerchant != null) {
      final m = _selectedMerchant!;
      final merchantId =
          ((m['uid'] ?? '').toString().trim().isNotEmpty ? m['uid'] : m['id'])
              .toString()
              .trim();
      data['merchant_id'] = merchantId;
      data['merchant_name'] = (m['name'] ?? '').toString();
      data['merchant_whatsapp'] = _normalizeWhatsapp(
        (m['whatsapp'] ?? '').toString(),
      );
      data['merchant_assigned_at'] = FieldValue.serverTimestamp();
    }

    if (_isGameOrder && _selectedPackage != null) {
      data['product_type'] = 'game';
      data['game'] = _selectedPackage!.game;
      data['package_label'] = _selectedPackage!.label;
      data['package_quantity'] = _selectedPackage!.quantity;
      data['game_id'] = _selectedGameId ?? '';
    } else if (_isPromoOrder) {
      data['product_type'] = 'tiktok_promo';
      data['video_link'] = _promoLink;
    } else {
      data['product_type'] = 'tiktok';
      data['points'] = _pointsValue?.toString() ?? '';
      data['tiktok_charge_mode'] = _tiktokChargeMode;
      final password = (_tiktokPasswordForOrder ?? '').trim();
      if (_tiktokChargeMode == _tiktokChargeModeUserPass &&
          password.isNotEmpty) {
        data['tiktok_password'] = password;
      }
    }

    return data;
  }

  Future<void> _safeAddOrderChatMessage({
    required String orderId,
    required String senderRole,
    String senderName = '',
    String text = '',
    String attachmentType = '',
    String attachmentUrl = '',
    String attachmentLabel = '',
    Duration? attachmentExpiresIn,
  }) async {
    try {
      final expiresAt = attachmentExpiresIn == null
          ? null
          : Timestamp.fromDate(DateTime.now().add(attachmentExpiresIn));
      await OrderChatService.addMessage(
        orderId: orderId,
        senderRole: senderRole,
        senderName: senderName,
        text: text,
        attachmentType: attachmentType,
        attachmentUrl: attachmentUrl,
        attachmentLabel: attachmentLabel,
        attachmentExpiresAt: expiresAt,
        sendPushNotification: false,
      );
    } catch (e) {
      debugPrint('seed order chat message failed: $e');
    }
  }

  Future<void> _seedOrderChatThread({
    required String orderId,
    required Map<String, dynamic> payload,
  }) async {
    final productType = (payload['product_type'] ?? '').toString().trim();
    final method = (payload['method'] ?? '').toString().trim();
    final userName = (payload['name'] ?? '').toString().trim();
    final displayName = userName.isEmpty ? 'المستخدم' : userName;
    final price = (payload['price'] ?? '').toString().trim();
    final usdtAmount = (payload['usdt_amount'] ?? '').toString().trim();
    final gameId = (payload['game_id'] ?? '').toString().trim();
    final promoLink = (payload['video_link'] ?? '').toString().trim();
    final tiktokUser = (payload['user_tiktok'] ?? '').toString().trim();
    final tiktokPassword = (payload['tiktok_password'] ?? '').toString().trim();
    final tiktokChargeMode = (payload['tiktok_charge_mode'] ?? '')
        .toString()
        .trim();
    final tiktokChargeModeLabel = tiktokChargeMode == _tiktokChargeModeUserPass
        ? 'يوزر + باسورد'
        : tiktokChargeMode == _tiktokChargeModeQr
        ? 'QR'
        : tiktokChargeMode == _tiktokChargeModeLink
        ? 'لينك'
        : '';

    await _safeAddOrderChatMessage(
      orderId: orderId,
      senderRole: 'system',
      text: 'تم إنشاء الطلب.',
    );

    if (method == 'Wallet') {
      await _safeAddOrderChatMessage(
        orderId: orderId,
        senderRole: 'system',
        text: 'سيتم إرسال رقم المحفظة من التاجر داخل الشات.',
      );
      if (price.isNotEmpty) {
        await _safeAddOrderChatMessage(
          orderId: orderId,
          senderRole: 'system',
          text: 'المبلغ المطلوب: $price جنيه',
        );
      }
    } else if (method == 'InstaPay') {
      await _safeAddOrderChatMessage(
        orderId: orderId,
        senderRole: 'system',
        text: 'سيقوم التاجر بإرسال رابط أو رقم InstaPay داخل الشات.',
      );
      if (price.isNotEmpty) {
        await _safeAddOrderChatMessage(
          orderId: orderId,
          senderRole: 'system',
          text: 'المبلغ المطلوب: $price جنيه',
        );
      }
    } else if (method == 'Binance Pay') {
      await _safeAddOrderChatMessage(
        orderId: orderId,
        senderRole: 'system',
        text: 'سيتم إرسال Binance Pay ID من التاجر داخل الشات.',
      );
      if (usdtAmount.isNotEmpty) {
        await _safeAddOrderChatMessage(
          orderId: orderId,
          senderRole: 'system',
          text: 'المبلغ المطلوب: $usdtAmount USDT',
        );
      }
    }

    if (productType == 'game' && gameId.isNotEmpty) {
      await _safeAddOrderChatMessage(
        orderId: orderId,
        senderRole: 'user',
        senderName: displayName,
        text: 'ID اللعبة: $gameId',
      );
    }

    if (productType == 'tiktok_promo' && promoLink.isNotEmpty) {
      await _safeAddOrderChatMessage(
        orderId: orderId,
        senderRole: 'user',
        senderName: displayName,
        text: 'رابط فيديو الترويج',
        attachmentType: 'link',
        attachmentUrl: ensureHttps(promoLink),
        attachmentLabel: 'رابط الفيديو',
      );
    }

    if (productType == 'tiktok') {
      if (tiktokChargeModeLabel.isNotEmpty) {
        await _safeAddOrderChatMessage(
          orderId: orderId,
          senderRole: 'user',
          senderName: displayName,
          text: 'طريقة الشحن المطلوبة: $tiktokChargeModeLabel',
        );
      }
      if (tiktokUser.isNotEmpty) {
        await _safeAddOrderChatMessage(
          orderId: orderId,
          senderRole: 'user',
          senderName: displayName,
          text: 'حساب تيك توك: $tiktokUser',
        );
      }
      if (tiktokChargeMode == _tiktokChargeModeUserPass &&
          tiktokPassword.isNotEmpty) {
        await _safeAddOrderChatMessage(
          orderId: orderId,
          senderRole: 'user',
          senderName: displayName,
          text: 'كلمة المرور: $tiktokPassword',
        );
        await _safeAddOrderChatMessage(
          orderId: orderId,
          senderRole: 'system',
          text: 'تنبيه أمني: غيّر كلمة سر تيك توك بعد استلام الشحن مباشرة.',
        );
      }
    }
  }

  // EN: Processes Wallet Order.
  // AR: تعالج Wallet Order.
  Future<void> _processWalletOrder({required int payableAmount}) async {
    Navigator.pop(context);

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
              style: TextStyle(color: TTColors.textWhite, fontFamily: 'Cairo'),
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
  }

  Future<void> _processBinancePay({required int payableAmount}) async {
    Navigator.pop(context);

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
              style: TextStyle(color: TTColors.textWhite, fontFamily: 'Cairo'),
            ),
            const SizedBox(height: 8),
            Text(
              "المعادِل بالجنيه: $payableAmount",
              textAlign: TextAlign.center,
              style: TextStyle(color: TTColors.goldAccent, fontFamily: 'Cairo'),
            ),
            const SizedBox(height: 8),
            Text(
              "سيتم إرسال Binance Pay ID وتأكيدات الدفع داخل الشات من التاجر.",
              textAlign: TextAlign.center,
              style: TextStyle(color: TTColors.textWhite, fontFamily: 'Cairo'),
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
  }

  // EN: Processes Insta Pay.
  // AR: تعالج Insta Pay.
  Future<void> _processInstaPay({required int payableAmount}) async {
    Navigator.pop(context);

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
  }

  // ترويج فيديو تيك توك
  Future<void> _openPromoDialog() async {
    if (!await _checkCancelLimit()) return;

    final linkCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    bool proceed = false;

    await _showBlurDialog<void>(
      barrierLabel: 'promo-order-dialog',
      builder: (ctx) => _buildMaterialDialogCard(
        ctx,
        title: "ترويج فيديو تيك توك",
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: linkCtrl,
              decoration: const InputDecoration(
                labelText: "رابط الفيديو",
                hintText: "https://www.tiktok.com/...",
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: "المبلغ بالجنيه",
                hintText: "100 - 60000",
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
              proceed = true;
              Navigator.pop(ctx);
            },
            child: const Text("إنشاء طلب"),
          ),
        ],
      ),
    );

    if (!proceed) return;
    if (!mounted) return;

    final link = linkCtrl.text.trim();
    final amount = _validateWholeAmountEnding(
      raw: amountCtrl.text,
      min: 100,
      max: 60000,
    );

    bool isTiktokLink(String url) {
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasAuthority) return false;
      final h = uri.host.toLowerCase();
      return h.contains('tiktok.com');
    }

    if (amount == null || link.isEmpty || !isTiktokLink(link)) {
      TopSnackBar.show(
        context,
        "أدخل رابط تيك توك صالح ومبلغ بين 100 و 60000 جنيه",
        backgroundColor: Colors.orange,
        textColor: Colors.black,
        icon: Icons.warning_amber_rounded,
      );
      return;
    }

    setState(() {
      _promoLink = link;
      _priceValue = amount;
      _pointsValue = null;
      _isInputValid = true;
      _selectedPackage = null;
      _selectedGameId = null;
    });

    _startCheckoutFlow();
  }

  Future<bool> _checkCancelLimit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = (prefs.getString('user_uid') ?? '').trim();
      final decision = await CancelLimitService.checkCanCreateOrder(
        whatsapp: widget.whatsapp,
        uid: uid.isEmpty ? null : uid,
      );

      if (!decision.allowed) {
        _showCustomToast(
          "تم إلغاء ${decision.cancellationsInLast24Hours} طلبات خلال آخر 24 ساعة. الرجاء الانتظار 24 ساعة قبل إنشاء طلب جديد.",
          color: Colors.orange,
        );
        return false;
      }
    } catch (e) {
      debugPrint("cancel limit check failed: $e");
      // السماح بالمتابعة حتى لا نحظر المستخدم بسبب فهرس/شبكة
      return true;
    }

    return true;
  }

  String _normalizeSocialHandle(String value) {
    var out = value.trim();
    if (out.isEmpty) return '';
    if (out.startsWith('http://') || out.startsWith('https://')) {
      final uri = Uri.tryParse(out);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        out = uri.pathSegments.last;
      }
    }
    out = out.replaceFirst(RegExp(r'^@+'), '').trim();
    return out;
  }

  Uri? _socialUri(String platform, String handle) {
    final user = _normalizeSocialHandle(handle);
    if (user.isEmpty) return null;
    switch (platform) {
      case 'facebook':
        return Uri.parse('https://facebook.com/$user');
      case 'instagram':
        return Uri.parse('https://instagram.com/$user');
      case 'tiktok':
        return Uri.parse('https://www.tiktok.com/@$user');
      case 'telegram':
        return Uri.parse('https://t.me/$user');
      default:
        return null;
    }
  }

  Uri _githubUri(String username, String repo) {
    final normalizedUser = _normalizeSocialHandle(username);
    final normalizedRepo = _normalizeSocialHandle(repo);
    final user = normalizedUser.isEmpty ? GITHUB_USER : normalizedUser;
    final repoName = normalizedRepo.isEmpty ? GITHUB_REPO : normalizedRepo;
    return Uri.parse('https://github.com/$user/$repoName');
  }

  List<_SocialPlatformLink> _socialLinks() {
    final rc = RemoteConfigService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final githubUsername = rc.socialGithubUsername.isEmpty
        ? GITHUB_USER
        : rc.socialGithubUsername;
    final githubRepo = rc.socialGithubRepo.isEmpty
        ? GITHUB_REPO
        : rc.socialGithubRepo;

    final links = <_SocialPlatformLink>[
      _SocialPlatformLink(
        label: 'Facebook',
        icon: FontAwesome.facebook_f_brand,
        uri: _socialUri('facebook', rc.socialFacebookUrl),
        color: const Color(0xFF1877F2),
      ),
      _SocialPlatformLink(
        label: 'Instagram',
        icon: FontAwesome.instagram_brand,
        uri: _socialUri('instagram', rc.socialInstagramUrl),
        color: const Color(0xFFE1306C),
      ),
      _SocialPlatformLink(
        label: 'TikTok',
        icon: FontAwesome.tiktok_brand,
        uri: _socialUri('tiktok', rc.socialTiktokUrl),
        color: const Color(0xFF00C7B7),
      ),
      _SocialPlatformLink(
        label: 'Telegram',
        icon: FontAwesome.telegram_brand,
        uri: _socialUri('telegram', rc.socialTelegramUrl),
        color: const Color(0xFF229ED9),
      ),
      _SocialPlatformLink(
        label: 'GitHub',
        icon: FontAwesome.github_brand,
        uri: _githubUri(githubUsername, githubRepo),
        color: isDark ? const Color(0xFFE6EDF3) : const Color(0xFF24292F),
      ),
    ];

    return links.where((item) => item.uri != null).toList(growable: false);
  }

  Future<void> _openSocialLink(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      _showCustomToast("تعذر فتح الرابط", color: Colors.orange);
    }
  }

  Widget _buildLargeWebSocialDock(List<_SocialPlatformLink> links) {
    final brightness = Theme.of(context).brightness;
    final bool isDark = brightness == Brightness.dark;
    final cardTint = TTColors.cardBgFor(
      brightness,
    ).withValues(alpha: isDark ? 0.92 : 0.88);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: GlassCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        tint: cardTint,
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: links.map((item) {
            final bool needsHighContrast =
                isDark && item.color.computeLuminance() > 0.8;
            final Color chipBackground = needsHighContrast
                ? Colors.white.withAlpha(28)
                : item.color.withAlpha(30);
            final Color chipBorder = needsHighContrast
                ? Colors.white.withAlpha(128)
                : item.color.withAlpha(90);
            return Tooltip(
              message: item.label,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openSocialLink(item.uri!),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: chipBackground,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: chipBorder, width: 1),
                    ),
                    alignment: Alignment.center,
                    child: Icon(item.icon, size: 18, color: item.color),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // EN: Builds widget UI.
  // AR: تبني واجهة الودجت.
  @override
  Widget build(BuildContext context) {
    // Keep layout aligned with mobile sizing for all web widths.
    final bool isLargeWeb = MediaQuery.of(context).size.width >= 100000;
    final appBarHeight = kToolbarHeight;

    if (widget.showGamesOnly) {
      return _buildRouteDialogPage(
        title: "شحن ألعاب",
        maxWidth: 620,
        showAccountAction: false,
        showThemeAction: false,
        showAboutAction: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "اختر اللعبة والباقه",
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            _buildGamePackagesList(),
          ],
        ),
      );
    }

    if (widget.forceTikTokCharge) {
      return _buildRouteDialogPage(
        title: "شحن عملات تيك توك",
        maxWidth: 640,
        showAccountAction: true,
        showThemeAction: false,
        showAboutAction: false,
        child: _buildTiktokChargeFormContent(includeAppName: false),
      );
    }

    const String compactTitle = "";
    final socialLinks = _socialLinks();
    final bool showWebSocialDock = kIsWeb && socialLinks.isNotEmpty;
    final double webContentBottomPadding = showWebSocialDock ? 104 : 24;

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: null,
      appBar: _buildCompactAppBar(
        showBack: false,
        showLogout: true,
        title: compactTitle,
        showAboutAction: !kIsWeb,
      ),
      body: Stack(
        children: [
          const SnowBackground(),
          LayoutBuilder(
            builder: (context, constraints) {
              final double minHeight = constraints.maxHeight - appBarHeight;
              final menuBody = ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: _buildCompactMenuBody(),
              );

              if (isLargeWeb) {
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    24,
                    16,
                    webContentBottomPadding,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: minHeight > 0 ? minHeight : 0,
                    ),
                    child: Align(alignment: Alignment.center, child: menuBody),
                  ),
                );
              }

              final compactScrollView = SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  kIsWeb ? webContentBottomPadding : 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 540,
                    minHeight: minHeight > 0 ? minHeight : 0,
                  ),
                  child: Center(child: menuBody),
                ),
              );

              return Center(
                child: !kIsWeb
                    ? _wrapWithSwipeRefresh(compactScrollView)
                    : compactScrollView,
              );
            },
          ),
          if (showWebSocialDock)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                child: _buildLargeWebSocialDock(socialLinks),
              ),
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildCompactAppBar({
    required bool showBack,
    required bool showLogout,
    required String title,
    bool showAccountAction = true,
    bool showThemeAction = true,
    bool showAboutAction = true,
  }) {
    return GlassAppBar(
      title: const SizedBox.shrink(),
      centerTitle: true,
      automaticallyImplyLeading: false,
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _closeRouteDialogPage,
            )
          : IconButton(
              icon: const Icon(Icons.logout),
              tooltip: "خروج",
              onPressed: () async {
                await NotificationService.removeUserNotifications(
                  widget.whatsapp,
                );
                await NotificationService.disposeListeners();
                final p = await SharedPreferences.getInstance();
                await p.clear();
                if (!mounted) return;
                AppNavigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              },
            ),
      actions: [
        if (showAccountAction)
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: "حسابي / تعديل البيانات",
            onPressed: _openAccountDialog,
          ),
        if (showThemeAction)
          IconButton(
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.nightlight_round
                  : Icons.wb_sunny_rounded,
            ),
            tooltip: "وضع التطبيق",
            onPressed: () async {
              await showThemeModeSheet(context);
            },
          ),
        if (showAboutAction)
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: "حول التطبيق",
            onPressed: _openAboutDialog,
          ),
      ],
    );
  }

  Future<void> _openOrders({String? orderId}) async {
    var whatsapp = widget.whatsapp.trim();
    final prefs = await SharedPreferences.getInstance();
    whatsapp = whatsapp.isNotEmpty
        ? whatsapp
        : (prefs.getString('user_whatsapp') ?? '').trim();

    if (whatsapp.isEmpty) {
      _showCustomToast("أكمل بياناتك أولاً", color: Colors.orange);
      if (!mounted) return;
      AppNavigator.pushNamed(context, '/');
      return;
    }

    if (!mounted) return;
    final trimmedOrderId = (orderId ?? '').trim();
    final args = <String, dynamic>{'whatsapp': whatsapp};
    if (trimmedOrderId.isNotEmpty) {
      args['order_id'] = trimmedOrderId;
    }
    AppNavigator.pushNamed(context, '/orders', arguments: args);
  }

  Future<void> _openSupportChat({
    String? orderId,
    bool autoOpenedByStatus = false,
  }) async {
    if (!mounted || _supportChatNavigationInProgress) return;
    var whatsapp = widget.whatsapp.trim();
    var name = _nameCtrl.text.trim();
    final trimmedOrderId = (orderId ?? '').trim();
    final prefs = await SharedPreferences.getInstance();
    if (whatsapp.isEmpty) {
      whatsapp = (prefs.getString('user_whatsapp') ?? '').trim();
    }
    if (name.isEmpty) {
      name = (prefs.getString('user_name') ?? '').trim();
    }

    if (whatsapp.isEmpty) {
      _showCustomToast("أكمل بياناتك أولاً", color: Colors.orange);
      if (!mounted) return;
      AppNavigator.pushNamed(context, '/');
      return;
    }

    _supportChatNavigationInProgress = true;
    if (autoOpenedByStatus) {
      _showCustomToast('طلبك قيد التنفيذ.', color: Colors.green);
    }
    try {
      final args = <String, dynamic>{'whatsapp': whatsapp};
      if (name.isNotEmpty) {
        args['name'] = name;
      }
      if (trimmedOrderId.isNotEmpty) {
        args['order_id'] = trimmedOrderId;
      }
      if (!mounted) return;
      AppNavigator.pushNamed(context, '/support_chat', arguments: args);
    } finally {
      _supportChatNavigationInProgress = false;
    }
  }

  Map<String, dynamic> _homeRouteArguments({
    bool forceTikTokCharge = false,
    bool showRamadanPromo = true,
    bool showGamesOnly = false,
  }) {
    return {
      'name': widget.name,
      'whatsapp': widget.whatsapp,
      'tiktok': widget.tiktok,
      'force_tiktok_charge': forceTikTokCharge,
      'show_ramadan_promo': showRamadanPromo,
      'show_games_only': showGamesOnly,
    };
  }

  // ignore: unused_element
  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: TTColors.primaryCyan),
      title: Text(title, style: const TextStyle(fontFamily: 'Cairo')),
      onTap: onTap,
    );
  }

  Widget _buildCompactMenuBody() {
    final brightness = Theme.of(context).brightness;
    final bool isDark = brightness == Brightness.dark;
    final Color cardTint = TTColors.cardBgFor(
      brightness,
    ).withValues(alpha: isDark ? 0.9 : 0.85);
    final Color accent = isDark
        ? const Color(0xFF5FE0C9)
        : const Color(0xFF52D6C2);

    final items = [
      _MenuItem(
        title: "طلباتي",
        icon: Icons.history,
        onTap: () {
          _openOrders();
        },
      ),
      _MenuItem(
        title: "شحن عملات تيك توك",
        icon: Icons.monetization_on,
        onTap: _openTiktokDialog,
      ),
      _MenuItem(
        title: "ترويج فيديو تيك توك",
        icon: Icons.campaign,
        onTap: _openPromoDialog,
      ),
      if (_showPromoCodeSection)
        _MenuItem(
          title: _promoCodesTitle,
          icon: Icons.card_giftcard,
          onTap: () {
            AppNavigator.pushNamed(
              context,
              '/code_requests',
              arguments: widget.whatsapp,
            );
          },
        ),
      _MenuItem(
        title: "شحن ألعاب",
        icon: Icons.sports_esports,
        onTap: _openGamesDialog,
      ),
      _MenuItem(
        title: "سياسة الخصوصية",
        icon: Icons.privacy_tip,
        onTap: () {
          AppNavigator.pushNamed(context, '/privacy');
        },
      ),
      _MenuItem(
        title: "الذهاب لوضع التاجر",
        icon: Icons.storefront_rounded,
        onTap: () {
          unawaited(_switchToMerchantMode());
        },
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              tint: cardTint,
              child: ListTile(
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor: accent.withValues(alpha: 0.18),
                  child: Icon(item.icon, color: accent, size: 20),
                ),
                title: Text(
                  item.title,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: item.onTap,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // EN: Builds Web Nav Bar.
  // AR: تبني Web Nav Bar.
  // ignore: unused_element
  PreferredSizeWidget _buildWebNavBar() {
    return GlassAppBar(
      height: 80,
      centerTitle: false,
      titleSpacing: 24,
      title: const SizedBox.shrink(),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _webBtn("طلباتي", () => _openOrders()),
              _webBtn("شحن عملات تيك توك", _openTiktokDialog),
              _webBtn("ترويج فيديو تيك توك", _openPromoDialog),
              _webBtn("شحن ألعاب", _openGamesDialog),
              _webBtn(
                "سياسة الخصوصية",
                () => AppNavigator.pushNamed(context, '/privacy'),
              ),
              _webBtn("حسابي", _openAccountDialog),
              if (_showPromoCodeSection)
                _webBtn(
                  _promoCodesTitle,
                  () => AppNavigator.pushNamed(
                    context,
                    '/code_requests',
                    arguments: widget.whatsapp,
                  ),
                  color: TTColors.goldAccent,
                ),
              const SizedBox(width: 20),
              PopupMenuButton<ThemeMode>(
                tooltip: "وضع التطبيق",
                icon: Icon(
                  Theme.of(context).brightness == Brightness.dark
                      ? Icons.nightlight_round
                      : Icons.wb_sunny_rounded,
                  color: TTColors.primaryCyan,
                ),
                onSelected: (mode) async {
                  final prefs = await SharedPreferences.getInstance();
                  await ThemeService.setMode(mode, prefs);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: ThemeMode.system,
                    child: Text('تلقائي (حسب النظام)'),
                  ),
                  PopupMenuItem(value: ThemeMode.dark, child: Text('داكن')),
                  PopupMenuItem(value: ThemeMode.light, child: Text('فاتح')),
                ],
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  await NotificationService.removeUserNotifications(
                    widget.whatsapp,
                  );
                  await NotificationService.disposeListeners();
                  final p = await SharedPreferences.getInstance();
                  await p.clear();
                  if (!mounted) return;
                  navigator.pushNamedAndRemoveUntil('/', (r) => false);
                },
                icon: const Icon(Icons.logout),
                label: const Text("خروج"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // EN: Handles web Btn.
  // AR: تتعامل مع web Btn.
  Widget _webBtn(String t, VoidCallback o, {Color? color}) {
    final textColor = color ?? TTColors.textWhite;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: TextButton(
        onPressed: o,
        child: Text(
          t,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _MenuItem {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _MenuItem({
    required this.title,
    required this.icon,
    required this.onTap,
  });
}

class _SocialPlatformLink {
  final String label;
  final IconData icon;
  final Uri? uri;
  final Color color;

  const _SocialPlatformLink({
    required this.label,
    required this.icon,
    required this.uri,
    required this.color,
  });
}
