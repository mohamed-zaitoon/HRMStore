// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class UsdtPriceService {
  UsdtPriceService._();

  // -1% from USD/EGP (not crypto pair price).
  static const double _discountFactor = 0.99;
  static const Duration _requestTimeout = Duration(seconds: 5);
  static const Duration _cacheTtl = Duration(minutes: 3);

  static double? _cachedDiscountedPrice;
  static DateTime? _cachedAt;

  static Future<double?> fetchDiscountedEgpPrice({
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedDiscountedPrice != null &&
        _cachedAt != null &&
        now.difference(_cachedAt!) < _cacheTtl) {
      return _cachedDiscountedPrice;
    }

    final rawUsdEgp = await _fetchRawUsdEgpPrice();
    if (rawUsdEgp == null || rawUsdEgp <= 0) {
      return _cachedDiscountedPrice;
    }

    final discounted = rawUsdEgp * _discountFactor;
    if (discounted <= 0) {
      return _cachedDiscountedPrice;
    }

    final normalized = double.parse(discounted.toStringAsFixed(4));
    _cachedDiscountedPrice = normalized;
    _cachedAt = now;
    return normalized;
  }

  static Future<double?> _fetchRawUsdEgpPrice() async {
    final results = await Future.wait<double?>([
      _fetchFromCurrencyApiPages(),
      _fetchFromFloatRates(),
      _fetchFromFrankfurter(),
      _fetchFromOpenErApi(),
      _fetchFromExchangeApi(),
    ]);

    for (final value in results) {
      if (value != null && value > 0) {
        return value;
      }
    }
    _debugLog('all usd/egp providers failed');
    return null;
  }

  static Future<double?> _fetchFromCurrencyApiPages() async {
    const url = 'https://latest.currency-api.pages.dev/v1/currencies/usd.json';
    try {
      final response = await http.get(Uri.parse(url)).timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _debugLog('currency-api.pages bad status ${response.statusCode}');
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      final usd = decoded['usd'];
      if (usd is! Map<String, dynamic>) return null;
      return _toDouble(usd['egp']);
    } catch (e) {
      _debugLog('currency-api.pages error: $e');
      return null;
    }
  }

  static Future<double?> _fetchFromFloatRates() async {
    const url = 'https://www.floatrates.com/daily/usd.json';
    try {
      final response = await http.get(Uri.parse(url)).timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _debugLog('floatrates bad status ${response.statusCode}');
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      final egp = decoded['egp'];
      if (egp is! Map<String, dynamic>) return null;
      return _toDouble(egp['rate']);
    } catch (e) {
      _debugLog('floatrates error: $e');
      return null;
    }
  }

  static Future<double?> _fetchFromFrankfurter() async {
    const url = 'https://api.frankfurter.app/latest?from=USD&to=EGP';
    try {
      final response = await http.get(Uri.parse(url)).timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _debugLog('frankfurter bad status ${response.statusCode}');
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      final rates = decoded['rates'];
      if (rates is! Map<String, dynamic>) return null;
      return _toDouble(rates['EGP']);
    } catch (e) {
      _debugLog('frankfurter error: $e');
      return null;
    }
  }

  static Future<double?> _fetchFromOpenErApi() async {
    const url = 'https://open.er-api.com/v6/latest/USD';
    try {
      final response = await http.get(Uri.parse(url)).timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _debugLog('open.er-api bad status ${response.statusCode}');
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      final rates = decoded['rates'];
      if (rates is! Map<String, dynamic>) return null;
      return _toDouble(rates['EGP']);
    } catch (e) {
      _debugLog('open.er-api error: $e');
      return null;
    }
  }

  static Future<double?> _fetchFromExchangeApi() async {
    const url = 'https://api.exchangerate-api.com/v4/latest/USD';
    try {
      final response = await http.get(Uri.parse(url)).timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _debugLog('exchangerate-api bad status ${response.statusCode}');
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      final rates = decoded['rates'];
      if (rates is! Map<String, dynamic>) return null;
      return _toDouble(rates['EGP']);
    } catch (e) {
      _debugLog('exchangerate-api error: $e');
      return null;
    }
  }

  static void _debugLog(String message) {
    if (!kDebugMode) return;
    debugPrint('[UsdtPriceService] $message');
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }
}
