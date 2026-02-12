// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/tt_colors.dart';
import '../../core/app_info.dart';
import '../../models/game_package.dart';
import '../../services/receipt_storage_service.dart';
import '../../services/notification_service.dart';
import '../../services/onesignal_service.dart';
import '../../services/theme_service.dart';
import '../../services/update_manager.dart';
import '../../utils/html_meta.dart';
import '../../widgets/snow_background.dart';
import '../../widgets/theme_mode_sheet.dart';
import '../../widgets/glass_bottom_sheet.dart';
import '../../widgets/glass_app_bar.dart';
import '../../widgets/glass_card.dart';
import '../../utils/url_sanitizer.dart';
import '../../widgets/top_snackbar.dart';

const MethodChannel _androidChannel = MethodChannel('tt_android_info');

// EN: Handles read File Bytes From Content Uri.
// AR: تتعامل مع read File Bytes From Content Uri.
Future<Uint8List?> _readFileBytesFromContentUri(String uri) async {
  try {
    final dynamic result = await _androidChannel.invokeMethod(
      'readFileAsBytes',
      {'uri': uri},
    );
    if (result == null) return null;
    if (result is Uint8List) return result;
    if (result is List<int>) return Uint8List.fromList(List<int>.from(result));
    return null;
  } catch (e) {
    debugPrint('readFileBytesFromContentUri error: $e');
    return null;
  }
}

class CalculatorScreen extends StatefulWidget {
  final String name;
  final String whatsapp;
  final String tiktok;
  final bool forceCalculator;
  final bool showRamadanPromo;
  final bool showGamesOnly;
  final int? prefillPoints;
  final bool autolaunchPayment;

  // EN: Creates CalculatorScreen.
  // AR: ينشئ CalculatorScreen.
  const CalculatorScreen({
    super.key,
    required this.name,
    required this.whatsapp,
    required this.tiktok,
    this.forceCalculator = false,
    this.showRamadanPromo = true,
    this.showGamesOnly = false,
    this.prefillPoints,
    this.autolaunchPayment = false,
  });

  // EN: Creates state object.
  // AR: تنشئ كائن الحالة.
  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isPointsMode = true;
  bool _isDiscountActive = false;
  bool _isInputValid = false;
  static const int _minPoints = 250;
  static const int _maxPoints = 130000;

  String _resultText = "";
  int? _calcPoints;
  int? _calcPrice;
  GamePackage? _selectedPackage;
  String? _selectedGameId;
  String? _promoLink;

  final _inputCtrl = TextEditingController();
  final _promoCtrl = TextEditingController();
  late TextEditingController _nameCtrl;
  final _tiktokCtrl = TextEditingController();
  List<Map<String, dynamic>> _prices = [];
  late final Future<PackageInfo> _packageInfoFuture;

  String _walletNumber = "";
  String _instapayLink = "";
  double _offer5 = 0;
  double _offer50 = 0;
  bool _isRamadanMode = false;

  // EN: Initializes widget state.
  // AR: تهيّئ حالة الودجت.
  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      setPageTitle(AppInfo.appName);

      setMetaDescription(
        'احسب سعر شحن نقاط تيك توك حسب عدد النقاط أو المبلغ، عروض خاصة ورمضان كود خصم حصري لمستخدمي الموقع والتطبيق.',
      );
    }

    _nameCtrl = TextEditingController(text: widget.name);
    _tiktokCtrl.text = widget.tiktok;
    _packageInfoFuture = PackageInfo.fromPlatform();

    if (widget.whatsapp.isNotEmpty) {
      NotificationService.listenToUserOrders(widget.whatsapp);
      NotificationService.listenToUserRamadanCodes(widget.whatsapp);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        Navigator.pushReplacementNamed(context, '/android');
      } else if (!kIsWeb) {
        UpdateManager.check(context);
      }
    });

    _loadTiktokFromProfile();
    _fetchData();
  }

  // EN: Releases resources.
  // AR: تفرّغ الموارد.
  @override
  void dispose() {
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
      final remoteTiktok =
          (data?['tiktok'] ?? data?['username'] ?? '').toString().trim();
      if (remoteTiktok.isNotEmpty) {
        setState(() => _tiktokCtrl.text = remoteTiktok);
        prefs.setString('user_tiktok', remoteTiktok);
      }
    } catch (_) {
      // نتجاهل أي خطأ في المزامنة الصامتة
    }
  }

  // EN: Handles try Get Android Sdk Int.
  // AR: تتعامل مع try Get Android Sdk Int.
  Future<int?> _tryGetAndroidSdkInt() async {
    try {
      final sdk = await _androidChannel.invokeMethod<int>('getSdkInt');
      return sdk;
    } catch (_) {
      return null;
    }
  }

  // EN: Shows Custom Toast.
  // AR: تعرض Custom Toast.
  void _showCustomToast(String msg, {Color color = TTColors.primaryCyan}) {
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
          _showCustomToast("يوزر تيك توك مطلوب", color: Colors.orange);
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

  Future<void> _syncTiktokToFirestore(String handle, SharedPreferences? prefs) async {
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

  // EN: Fetches Data.
  // AR: تجلب Data.
  Future<void> _fetchData() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(minutes: 1),
          minimumFetchInterval: Duration.zero,
        ),
      );
      await rc.fetchAndActivate();
      setState(() {
        _walletNumber = rc.getString('wallet_number');
        _instapayLink = rc.getString('instapay_link');
        _offer5 = rc.getDouble('offer5');
        _offer50 = rc.getDouble('offer50');
        _isRamadanMode = rc.getBool('is_ramadan');
      });
    } catch (e) {
      debugPrint("RemoteConfig error: $e");
    }

    FirebaseFirestore.instance
        .collection('prices')
        .orderBy('min')
        .snapshots()
        .listen((snap) {
          if (!mounted) return;
          setState(() {
            _prices = snap.docs.map((d) => d.data()).toList();
          });
          _maybePrefillPoints();
          if (_inputCtrl.text.isNotEmpty) _calculate(_inputCtrl.text);
          _maybeAutolaunchPayment();
        });
  }

  void _maybePrefillPoints() {
    if (widget.prefillPoints != null &&
        widget.prefillPoints! > 0 &&
        _inputCtrl.text.isEmpty) {
      _inputCtrl.text = widget.prefillPoints!.toString();
      _calculate(_inputCtrl.text);
    }
  }

  Future<void> _maybeAutolaunchPayment() async {
    if (!widget.autolaunchPayment) return;
    if (!_isInputValid) return;
    // حد الإلغاء 5 خلال 24 ساعة
    final ok = await _checkCancelLimit();
    if (!ok) return;
    _showPaymentDialog();
  }

  // EN: Handles activate Promo.
  // AR: تتعامل مع activate Promo.
  Future<void> _activatePromo() async {
    final String code = _promoCtrl.text.trim().toUpperCase().replaceAll(
      "-",
      "",
    );
    if (code.isEmpty) {
      _showCustomToast("الرجاء كتابة الكود", color: Colors.orange);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final docRef = FirebaseFirestore.instance
          .collection('promo_codes')
          .doc(code);
      final doc = await docRef.get();

      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);

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

      if (_inputCtrl.text.isNotEmpty) _calculate(_inputCtrl.text);

      _showCustomToast("تم التفعيل! 🎉", color: Colors.green);
    } catch (e) {
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);

      _showCustomToast("خطأ في التحقق", color: Colors.red);
    }
  }

  // EN: Requests Ramadan Code.
  // AR: تطلب Ramadan Code.
  Future<void> _requestRamadanCode() async {
    final tiktokHandle = _tiktokCtrl.text.trim();
    if (_nameCtrl.text.isEmpty ||
        widget.whatsapp.isEmpty ||
        tiktokHandle.isEmpty) {
      _showCustomToast("البيانات ناقصة", color: Colors.red);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final existing = await FirebaseFirestore.instance
          .collection('code_requests')
          .where('whatsapp', isEqualTo: widget.whatsapp)
          .where('status', isEqualTo: 'pending')
          .get();

      if (!mounted) return;
      if (existing.docs.isNotEmpty) {
        if (Navigator.canPop(context)) Navigator.pop(context);

        _showCustomToast("لديك طلب قيد الانتظار", color: Colors.orange);
        return;
      }

      await FirebaseFirestore.instance.collection('code_requests').add({
        'name': _nameCtrl.text,
        'whatsapp': widget.whatsapp,
        'tiktok': tiktokHandle,
        'status': 'pending',
        'created_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: TTColors.cardBg,
          title: const Text(
            "تم إرسال الطلب",
            style: TextStyle(color: TTColors.goldAccent),
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
      if (Navigator.canPop(context)) Navigator.pop(context);

      _showCustomToast("خطأ في الطلب", color: Colors.red);
    }
  }

  // EN: Calculates calculate.
  // AR: تحسب calculate.
  void _calculate(String val) {
    _isInputValid = false;
    _resultText = "";
    _calcPoints = null;
    _calcPrice = null;
    _selectedPackage = null;
    _selectedGameId = null;

    if (val.isEmpty || _prices.isEmpty) {
      setState(() {});
      return;
    }

    final double inputVal = double.tryParse(val) ?? 0;

    if (_isPointsMode) {
      if (inputVal < _minPoints || inputVal > _maxPoints) {
        _resultText = "النقاط من $_minPoints إلى $_maxPoints";
        setState(() {});
        return;
      }

      final rule = _prices.firstWhere(
        (r) => inputVal >= r['min'] && inputVal <= r['max'],
        orElse: () => _prices.last,
      );

      double rate = rule['pricePer1000'].toDouble();

      if (_isDiscountActive) {
        if (inputVal >= 50000) {
          rate = _offer50 > 0 ? _offer50 : rate;
        } else if (inputVal >= 5000) {
          rate = _offer5 > 0 ? _offer5 : rate;
        }
      }

      _calcPrice = ((inputVal / 1000) * rate).ceil();
      _calcPoints = inputVal.round();
      _resultText = "السعر: $_calcPrice جنيه";
      _isInputValid = true;
    } else {
      int bestPoints = 0;
      bool foundTier = false;

      final reversedPrices = _prices.reversed.toList();
      for (var rule in reversedPrices) {
        double rate = rule['pricePer1000'].toDouble();

        if (_isDiscountActive) {
          if (rule['min'] >= 50000) {
            rate = _offer50 > 0 ? _offer50 : rate;
          } else if (rule['min'] >= 5000) {
            rate = _offer5 > 0 ? _offer5 : rate;
          }
        }

        int potentialPoints = ((inputVal * 1000) / rate).floor();

        if (potentialPoints >= rule['min']) {
          bestPoints = potentialPoints;
          foundTier = true;
          break;
        }
      }

      if (!foundTier) {
        double rate = _prices.first['pricePer1000'].toDouble();
        bestPoints = ((inputVal * 1000) / rate).floor();
      }

      if (bestPoints < _minPoints || bestPoints > _maxPoints) {
        _resultText = "المبلغ خارج النطاق";
        _calcPoints = bestPoints;
        _calcPrice = inputVal.floor();
        setState(() {});
        return;
      }

      _calcPoints = bestPoints;
      _calcPrice = inputVal.floor();
      _resultText = "النقاط: $bestPoints نقطة";
      _isInputValid = true;
    }

    setState(() {});
  }

  bool get _isGameOrder => _selectedPackage != null;
  bool get _isPromoOrder => (_promoLink ?? '').isNotEmpty;

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
              child: CircularProgressIndicator(
                color: TTColors.primaryCyan,
              ),
            ),
          );
        }

        final packages = snapshot.data!.docs
            .map((d) => GamePackage.fromDoc(d))
            .toList()
          ..sort((a, b) {
            final order = {
              'pubg': 0,
              'freefire': 1,
              'cod': 2,
            };
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
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
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
                          style: TextStyle(
                            color: TTColors.textGray,
                          ),
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

  Future<void> _showOtherPackagesSheet() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: GlassBottomSheet(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildGamePackagesList(closeContext: ctx),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleGamePackageSelected(GamePackage pkg) async {
    await OneSignalService.requestPermission();
    final id = await _promptGameId(pkg);
    if (id == null || id.isEmpty) return;

    setState(() {
      _selectedPackage = pkg;
      _selectedGameId = id;
      _calcPrice = pkg.price;
      _isInputValid = true;
    });

    _showPaymentDialog();
  }

  Future<String?> _promptGameId(GamePackage pkg) async {
    final controller = TextEditingController();
    String? result;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TTColors.cardBg,
        title: Text(_gameOrderTitle(pkg)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: const InputDecoration(
            labelText: "ادخل الـ ID",
          ),
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

  // EN: Shows Payment Dialog.
  // AR: تعرض Payment Dialog.
  void _showPaymentDialog() {
    if (!_isInputValid && !_isGameOrder && !_isPromoOrder) return;
    if (!_isPromoOrder && !_ensureTiktokHandle()) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Pay",
      pageBuilder: (_, __, ___) => const SizedBox(),
      transitionBuilder: (ctx, anim, _, __) => SlideTransition(
        position: Tween(
          begin: const Offset(0, -1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: SafeArea(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: GlassCard(
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
                          "المبلغ: ${_calcPrice ?? 0} جنيه",
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
                              style: TextStyle(color: TTColors.textGray),
                            ),
                        ],

                        const SizedBox(height: 20),

                        _payOption(
                          "فودافون كاش / محفظة",
                          Icons.account_balance_wallet,
                          Colors.orange,
                          () => _processWalletOrder(),
                        ),

                        const SizedBox(height: 10),

                        _payOption(
                          "InstaPay",
                          Icons.qr_code,
                          Colors.purpleAccent,
                          () => _processInstaPay(),
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

  Map<String, dynamic> _buildOrderPayload({
    required String method,
    required String status,
    String? receiptUrl,
    String? receiptPath,
  }) {
    final priceValue = _calcPrice ?? 0;
    final tiktokHandle = _tiktokCtrl.text.trim();
    final data = <String, dynamic>{
      'name': _nameCtrl.text,
      'user_whatsapp': widget.whatsapp,
      'user_tiktok': tiktokHandle,
      'price': priceValue.toString(),
      'method': method,
      'wallet_number': _walletNumber,
      'status': status,
      'receipt_url': receiptUrl,
      'receipt_path': receiptPath,
      if (receiptUrl != null)
        'receipt_expires_at':
            Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 30))),
      'created_at': FieldValue.serverTimestamp(),
    };

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
      data['points'] = _calcPoints?.toString() ?? '';
    }

    return data;
  }

  // EN: Processes Wallet Order.
  // AR: تعالج Wallet Order.
  Future<void> _processWalletOrder() async {
    Navigator.pop(context);

    if (!await _checkCancelLimit()) return;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TTColors.cardBg,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info, color: Colors.orange, size: 50),

            const SizedBox(height: 10),

            Text(
              "سيظهر رقم المحفظة في 'طلباتي' بعد إنشاء الطلب.",
              textAlign: TextAlign.center,
              style: TextStyle(color: TTColors.textWhite, fontFamily: 'Cairo'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("متابعة"),
          ),
        ],
      ),
    );

    if (!mounted) return;
    await FirebaseFirestore.instance.collection('orders').add(
          _buildOrderPayload(
            method: "Wallet",
            status: 'pending_payment',
          ),
        );

    if (!mounted) return;
    Navigator.pushNamed(context, '/orders', arguments: widget.whatsapp);
    setState(() {
      _promoLink = null;
    });
  }

  // EN: Processes Insta Pay.
  // AR: تعالج Insta Pay.
  Future<void> _processInstaPay() async {
    Navigator.pop(context);

    if (!await _checkCancelLimit()) return;

    bool proceed = false;

    final instapayLink = ensureHttps(_instapayLink);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TTColors.cardBg,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "حول المبلغ عبر الرابط:",
              style: TextStyle(color: TTColors.textWhite),
            ),

            const SizedBox(height: 10),

            SelectableText(
              instapayLink,
              style: const TextStyle(color: Colors.purpleAccent),
            ),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: () => launchUrl(Uri.parse(instapayLink)),
              child: const Text("فتح التطبيق"),
            ),

            const SizedBox(height: 15),

            Text(
              "ثم اضغط متابعة لرفع الإيصال",
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
            child: const Text("متابعة ورفع"),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (!proceed) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp', 'heic'],
      withData: true,
      dialogTitle: 'اختر صورة من الملفات',
    );
    if (result == null || result.files.isEmpty) return;

    final pickedFile = result.files.first;
    Uint8List? bytes = pickedFile.bytes;

    if (bytes == null && !kIsWeb) {
      final String? path = pickedFile.path;
      if (path != null) {
        if (path.startsWith('content://')) {
          bytes = await _readFileBytesFromContentUri(path);
        } else {
          try {
            bytes = await File(path).readAsBytes();
          } catch (e) {
            debugPrint('File read error: $e');
            bytes = null;
          }
        }
      }
    }

    if (bytes == null) {
      _showCustomToast(
        "تعذر قراءة الصورة، جرّب صورة أخرى أو استخدم 'مستعرض الملفات'",
        color: Colors.red,
      );
      return;
    }

    final Uint8List imageBytes = bytes;

    if (!mounted) return;

    bool confirm = false;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TTColors.cardBg,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.memory(imageBytes, height: 200, fit: BoxFit.cover),

            const SizedBox(height: 10),

            Text("إرسال الصورة؟", style: TextStyle(color: TTColors.textWhite)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("لا"),
          ),

          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              confirm = true;
            },
            child: const Text("نعم"),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (!confirm) return;

    _showCustomToast("جاري الرفع...");
    final orderRef = FirebaseFirestore.instance.collection('orders').doc();
    final uploadRes = await ReceiptStorageService.uploadWithPath(
      bytes: imageBytes,
      whatsapp: widget.whatsapp,
      orderId: orderRef.id,
    );

    if (!mounted) return;
    if (uploadRes != null) {
      await orderRef.set(
        _buildOrderPayload(
          method: "InstaPay",
          status: 'pending_review',
          receiptUrl: uploadRes.url,
          receiptPath: uploadRes.path,
        ),
      );

      if (!mounted) return;
      Navigator.pushNamed(context, '/orders', arguments: widget.whatsapp);
      setState(() {
        _promoLink = null;
      });
    } else {
      _showCustomToast("فشل الرفع", color: Colors.red);
    }
  }

  // ترويج فيديو تيك توك
  Future<void> _openPromoDialog() async {
    if (!await _checkCancelLimit()) return;

    final linkCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    bool proceed = false;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TTColors.cardBg,
        title: const Text("ترويج فيديو تيك توك"),
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

    final link = linkCtrl.text.trim();
    final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;

    bool isTiktokLink(String url) {
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasAuthority) return false;
      final h = uri.host.toLowerCase();
      return h.contains('tiktok.com');
    }

    if (link.isEmpty || !isTiktokLink(link) || amount < 100 || amount > 60000) {
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
      _calcPrice = amount;
      _calcPoints = null;
      _isInputValid = true;
      _selectedPackage = null;
      _selectedGameId = null;
    });

    _showPaymentDialog();
  }

  Future<bool> _checkCancelLimit() async {
    final since =
        Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 24)));

    Future<int> _countCancelled(Query<Map<String, dynamic>> base) async {
      // The query already filters by status and timestamp.
      // We can just return the number of documents found.
      final snap = await base.get();
      return snap.docs.length;
    }

    try {
      final base = FirebaseFirestore.instance
          .collection('orders')
          .where('user_whatsapp', isEqualTo: widget.whatsapp)
          .where('status', isEqualTo: 'cancelled')
          .where('cancelled_at', isGreaterThanOrEqualTo: since)
          .limit(5);
      final count = await _countCancelled(base);
      if (count >= 5) {
        _showCustomToast(
          "تم إلغاء 5 طلبات خلال آخر 24 ساعة. الرجاء الانتظار 24 ساعة قبل إنشاء طلب جديد.",
          color: Colors.orange,
        );
        return false;
      }
    } catch (e) {
      debugPrint("cancel limit check failed: $e"); // TODO: أنشئ فهرس مركب: user_whatsapp Asc, cancelled_at Desc, status Asc
      // السماح بالمتابعة حتى لا نحظر المستخدم بسبب فهرس/شبكة
      return true;
    }

    return true;
  }

  // EN: Builds widget UI.
  // AR: تبني واجهة الودجت.
  @override
  Widget build(BuildContext context) {
    // Force the compact (app-like) layout on web for all sizes.
    final bool isLargeWeb = false;
    final appBarHeight = isLargeWeb ? 80.0 : kToolbarHeight;

    const double webMaxWidth = 540;
    const double mobileMaxWidth = 540;
    final bool showCompactMenu =
        !widget.forceCalculator && !widget.showGamesOnly && !isLargeWeb;
    final bool showBackButton = !showCompactMenu;
    final bool showLogout = showCompactMenu;
    final String compactTitle = widget.showGamesOnly
        ? "شحن ألعاب"
        : (widget.forceCalculator ? "شحن عملات تيك توك" : AppInfo.appName);

    return Scaffold(
      key: _scaffoldKey,

      endDrawer: null,

      appBar: isLargeWeb
          ? _buildWebNavBar()
          : _buildCompactAppBar(
              showBack: showBackButton,
              showLogout: showLogout,
              title: compactTitle,
            ),
      body: Stack(
        children: [
          const SnowBackground(),

          if (showCompactMenu)
            LayoutBuilder(
              builder: (context, constraints) {
                final double minHeight = constraints.maxHeight - appBarHeight;
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 540,
                        minHeight: minHeight > 0 ? minHeight : 0,
                      ),
                      child: Center(child: _buildCompactMenuBody()),
                    ),
                  ),
                );
              },
            )
          else if (widget.showGamesOnly)
            SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: isLargeWeb ? 20 : 0,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isLargeWeb ? webMaxWidth : mobileMaxWidth,
                  ),
                  child: GlassCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 8),
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
                  ),
                ),
              ),
            )
          else
            SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: isLargeWeb ? 20 : 0,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      appBarHeight -
                      (isLargeWeb ? 40 : 0),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isLargeWeb ? webMaxWidth : mobileMaxWidth,
                    ),
                    child: GlassCard(
                      margin: EdgeInsets.zero,
                      padding: const EdgeInsets.all(26),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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

                          TextField(
                            controller: _tiktokCtrl,
                            decoration: const InputDecoration(
                              labelText: "يوزر تيك توك",
                            ),
                          ),

                          const SizedBox(height: 12),

                          TextField(
                            controller: _inputCtrl,
                            onChanged: _calculate,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              labelText: _isPointsMode
                                  ? "ادخل عدد النقاط المطلوب"
                                  : "ادخل المبلغ الذي معك",
                            ),
                          ),

                            const SizedBox(height: 15),
                            if (_resultText.isNotEmpty)
                              Text(
                                _resultText,
                                style: TextStyle(
                                  color: _isInputValid
                                      ? TTColors.textWhite
                                      : Colors.red,
                                  fontSize: 18,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            // إظهار خانة كود الخصم دائماً عندما يكون العرض مفعّلاً
                            if (widget.showRamadanPromo)
                              GlassCard(
                                margin: const EdgeInsets.symmetric(vertical: 10),
                                padding: const EdgeInsets.all(14),
                                borderColor: TTColors.goldAccent.withAlpha(160),
                                child: Column(
                                  children: [
                                    const Text(
                                      "✨ عروض رمضان الذهبية ✨",
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
                                          prefixIcon: Icon(
                                            Icons.vpn_key,
                                            color: Color(0xFFFFD700),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 10),

                                      ElevatedButton(
                                        onPressed: _activatePromo,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFFFFD700),
                                          foregroundColor: Colors.black,
                                        ),
                                        child: const Text("تفعيل"),
                                      ),

                                      const SizedBox(height: 10),

                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: _requestRamadanCode,
                                          icon:
                                              const Icon(Icons.card_giftcard),
                                          label: const Text(
                                            "اضغط لطلب كود رمضان الخاص بك",
                                            textAlign: TextAlign.center,
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor:
                                                const Color(0xFFFFD700),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ] else
                                      const Text(
                                        "✅ تم التفعيل!",
                                        style: TextStyle(
                                          color: Color(0xFFFFD700),
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                            const SizedBox(height: 20),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isPointsMode = !_isPointsMode;
                                  _inputCtrl.clear();
                                  _resultText = "";
                                });
                              },
                              icon: const Icon(Icons.swap_vert),
                              label: const Text("تبديل النمط"),
                            ),

                            const SizedBox(height: 20),

                            const SizedBox(height: 14),

                            ElevatedButton(
                              onPressed:
                                  _isInputValid ? _showPaymentDialog : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: TTColors.primaryCyan,
                                foregroundColor: Colors.black,
                                minimumSize: const Size(double.infinity, 50),
                              ),
                              child: const Text(
                                "طلب الشحن",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontFamily: 'Cairo',
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
        ],
      ),
    );
  }

  PreferredSizeWidget _buildCompactAppBar({
    required bool showBack,
    required bool showLogout,
    required String title,
  }) {
    return GlassAppBar(
      title: Text(title),
      centerTitle: true,
      automaticallyImplyLeading: false,
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
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
                if (!context.mounted) return;
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              },
            ),
      actions: [
        IconButton(
          icon: const Icon(Icons.person),
          tooltip: "حسابي / تعديل البيانات",
          onPressed: () => Navigator.pushNamed(context, '/account'),
        ),
        IconButton(
          icon: const Icon(Icons.brightness_6),
          tooltip: "وضع التطبيق",
          onPressed: () async {
            await showThemeModeSheet(context);
          },
        ),
      ],
    );
  }

  Future<void> _openOrders() async {
    var whatsapp = widget.whatsapp.trim();
    final prefs = await SharedPreferences.getInstance();
    whatsapp = whatsapp.isNotEmpty
        ? whatsapp
        : (prefs.getString('user_whatsapp') ?? '').trim();

    if (whatsapp.isEmpty) {
      _showCustomToast("أكمل بياناتك أولاً", color: Colors.orange);
      if (!mounted) return;
      Navigator.pushNamed(context, '/');
      return;
    }

    if (!mounted) return;
    Navigator.pushNamed(context, '/orders', arguments: whatsapp);
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: TTColors.primaryCyan),
      title: Text(title, style: const TextStyle(fontFamily: 'Cairo')),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildCompactMenuBody() {
    final brightness = Theme.of(context).brightness;
    final bool isDark = brightness == Brightness.dark;
    final Color cardTint =
        TTColors.cardBgFor(brightness).withValues(alpha: isDark ? 0.9 : 0.85);
    final Color accent =
        isDark ? const Color(0xFF5FE0C9) : const Color(0xFF52D6C2);

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
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CalculatorScreen(
                name: widget.name,
                whatsapp: widget.whatsapp,
                tiktok: widget.tiktok,
                forceCalculator: true,
                showRamadanPromo: true,
              ),
            ),
          );
        },
      ),
      _MenuItem(
        title: "ترويج فيديو تيك توك",
        icon: Icons.campaign,
        onTap: _openPromoDialog,
      ),
      if (_isRamadanMode)
        _MenuItem(
          title: "أكواد خصم رمضان",
          icon: Icons.card_giftcard,
          onTap: () {
            Navigator.pushNamed(
              context,
              '/code_requests',
              arguments: widget.whatsapp,
            );
          },
      ),
      _MenuItem(
        title: "شحن ألعاب",
        icon: Icons.sports_esports,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CalculatorScreen(
                name: widget.name,
                whatsapp: widget.whatsapp,
                tiktok: widget.tiktok,
                showGamesOnly: true,
              ),
            ),
          );
        },
      ),
      _MenuItem(
        title: "سياسة الخصوصية",
        icon: Icons.privacy_tip,
        onTap: () {
          Navigator.pushNamed(context, '/privacy');
        },
      ),
      if (!kIsWeb)
        _MenuItem(
          title: "تحديث التطبيق",
          icon: Icons.system_update,
          onTap: () => UpdateManager.check(context, manual: true),
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
                trailing:
                    Icon(Icons.chevron_left, color: TTColors.textGray, size: 20),
                onTap: item.onTap,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          tint: cardTint,
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: accent.withValues(alpha: 0.18),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    width: 28,
                    height: 28,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.flash_on,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppInfo.appName,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: TTColors.textFor(brightness),
                      ),
                    ),
                    const SizedBox(height: 4),
                    FutureBuilder<PackageInfo>(
                      future: _packageInfoFuture,
                      builder: (context, snapshot) {
                        final info = snapshot.data;
                        final version = info == null ? '...' : info.version;
                        return Text(
                          'الإصدار: $version',
                          style: TextStyle(
                            color: TTColors.textGray,
                            fontFamily: 'Cairo',
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // EN: Builds Web Nav Bar.
  // AR: تبني Web Nav Bar.
  PreferredSizeWidget _buildWebNavBar() {
    return GlassAppBar(
      height: 80,
      centerTitle: false,
      titleSpacing: 24,
      title: Text(
        AppInfo.appName,
        style: TextStyle(
          color: TTColors.textWhite,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _webBtn(
                "طلباتي",
                () => _openOrders(),
              ),
              _webBtn(
                "شحن عملات تيك توك",
                () => Navigator.pushNamed(context, '/'),
              ),
              _webBtn(
                "ترويج فيديو تيك توك",
                _openPromoDialog,
              ),
              _webBtn("شحن ألعاب", _showOtherPackagesSheet),
              _webBtn(
                "سياسة الخصوصية",
                () => Navigator.pushNamed(context, '/privacy'),
              ),
              _webBtn(
                "حسابي",
                () => Navigator.pushNamed(context, '/account'),
              ),
              if (_isRamadanMode)
                _webBtn(
                  "أكواد خصم رمضان",
                  () => Navigator.pushNamed(
                    context,
                    '/code_requests',
                    arguments: widget.whatsapp,
                  ),
                  color: TTColors.goldAccent,
                ),
              const SizedBox(width: 20),
              PopupMenuButton<ThemeMode>(
                tooltip: "وضع التطبيق",
                icon: const Icon(
                  Icons.brightness_6,
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
