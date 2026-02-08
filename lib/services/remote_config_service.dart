// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class RemoteConfigService {
  RemoteConfigService._();
  static final RemoteConfigService instance = RemoteConfigService._();

  late FirebaseRemoteConfig _remoteConfig;

  static const Map<String, dynamic> _defaults = {
    'admin_whatsapp': '',
    'wallet_number': '',
    'instapay_link': '',

    'imgbb_api_key': '',
    'imgbb_expiration': 0,

    'offer5': 0.0,
    'offer50': 0.0,
    'is_ramadan': false,

    'admin_enabled': true,

    'onesignal_app_id': 'd9dcc8b4-585d-4ccf-a101-7b94b0d504ce',
    'onesignal_reset_api': 'os_v2_app_3homrncylvgm7iibpoklbviez3j2tzctbu7uvyvo5ghzpf7oco3bo7furj2qa74bgfexprxt27e2fzqguk24cklmvwuiiswsuokeqzq',
  };

  // EN: Initializes init.
  // AR: تهيّئ init.
  Future<void> init() async {
    _remoteConfig = FirebaseRemoteConfig.instance;

    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 20),
        minimumFetchInterval: kDebugMode
            ? Duration.zero
            : const Duration(minutes: 30),
      ),
    );

    await _remoteConfig.setDefaults(_defaults);

    try {
      final List<ConnectivityResult> results =
          await Connectivity().checkConnectivity();
      final bool hasConnection =
          !results.contains(ConnectivityResult.none);

      if (!hasConnection) {
        if (kDebugMode) {
          debugPrint('RemoteConfig: offline, skip fetch');
        }
        return;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RemoteConfig: connectivity check failed ($e)');
      }
      return;
    }

    try {
      await _remoteConfig.fetchAndActivate();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RemoteConfig: fetch failed ($e)');
      }
    }
  }

  // EN: Handles admin Whatsapp.
  // AR: تتعامل مع admin Whatsapp.
  String get adminWhatsapp => _remoteConfig.getString('admin_whatsapp');

  // EN: Handles wallet Number.
  // AR: تتعامل مع wallet Number.
  String get walletNumber => _remoteConfig.getString('wallet_number');

  // EN: Handles instapay Link.
  // AR: تتعامل مع instapay Link.
  String get instapayLink => _remoteConfig.getString('instapay_link');

  // EN: Handles imgbb Api Key.
  // AR: تتعامل مع imgbb Api Key.
  String get imgbbApiKey => _remoteConfig.getString('imgbb_api_key');

  // EN: Handles imgbb Expiration.
  // AR: تتعامل مع imgbb Expiration.
  int get imgbbExpiration => _remoteConfig.getInt('imgbb_expiration');

  // EN: Handles offer5k.
  // AR: تتعامل مع offer5k.
  double get offer5k => _remoteConfig.getDouble('offer5');

  // EN: Handles offer50k.
  // AR: تتعامل مع offer50k.
  double get offer50k => _remoteConfig.getDouble('offer50');

  // EN: Handles is Ramadan.
  // AR: تتعامل مع is Ramadan.
  bool get isRamadan => _remoteConfig.getBool('is_ramadan');

  // EN: Handles is Admin Enabled.
  // AR: تتعامل مع is Admin Enabled.
  bool get isAdminEnabled => _remoteConfig.getBool('admin_enabled');

  // EN: Handles e Signal App Id.
  // AR: تتعامل مع e Signal App Id.
  String get oneSignalAppId => _remoteConfig.getString('onesignal_app_id');

  // EN: Handles e Signal Rest Api Key.
  // AR: تتعامل مع e Signal Rest Api Key.
  String get oneSignalRestApiKey =>
      _remoteConfig.getString('onesignal_reset_api');

  // EN: Handles dump.
  // AR: تتعامل مع dump.
  Map<String, dynamic> dump() {
    return {
      'admin_whatsapp': adminWhatsapp,
      'wallet_number': walletNumber,
      'instapay_link': instapayLink,
      'imgbb_api_key': imgbbApiKey.isNotEmpty ? '***' : '',
      'imgbb_expiration': imgbbExpiration,
      'offer5': offer5k,
      'offer50': offer50k,
      'is_ramadan': isRamadan,
      'admin_enabled': isAdminEnabled,
      'onesignal_app_id': oneSignalAppId,
      'onesignal_reset_api': oneSignalRestApiKey.isNotEmpty ? '***' : '',
    };
  }
}
