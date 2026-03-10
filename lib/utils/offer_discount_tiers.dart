// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

class OfferPriceTier {
  const OfferPriceTier({
    required this.min,
    required this.max,
    required this.pricePer1000,
  });

  final int min;
  final int max;
  final double pricePer1000;

  bool contains(double points) => points >= min && points <= max;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'min': min,
    'max': max,
    'price_per_1000': pricePer1000,
  };

  static List<OfferPriceTier> parseList(dynamic raw) {
    if (raw is! List) return const <OfferPriceTier>[];

    final tiers = <OfferPriceTier>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry);
      final min = _toInt(map['min']);
      final max = _toInt(map['max']);
      final pricePer1000 =
          parseOfferNumber(map['price_per_1000'] ?? map['pricePer1000']) ?? 0;
      if (min == null || max == null || pricePer1000 <= 0) continue;
      tiers.add(OfferPriceTier(min: min, max: max, pricePer1000: pricePer1000));
    }

    tiers.sort((a, b) => a.min.compareTo(b.min));
    return tiers;
  }

  static int? _toInt(dynamic raw) {
    final value = parseOfferNumber(raw);
    if (value == null) return null;
    return value.toInt();
  }
}

class OfferDiscountTier {
  const OfferDiscountTier({
    required this.min,
    required this.max,
    required this.discountPercent,
  });

  final int min;
  final int max;
  final double discountPercent;

  bool contains(double points) => points >= min && points <= max;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'min': min,
    'max': max,
    'discount_percent': discountPercent,
  };

  static List<OfferDiscountTier> parseList(dynamic raw) {
    if (raw is! List) return const <OfferDiscountTier>[];

    final tiers = <OfferDiscountTier>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry);
      final min = _toInt(map['min']);
      final max = _toInt(map['max']);
      final discountPercent =
          parseOfferNumber(map['discount_percent'] ?? map['discountPercent']) ??
          0;
      if (min == null || max == null || discountPercent < 0) continue;
      tiers.add(
        OfferDiscountTier(min: min, max: max, discountPercent: discountPercent),
      );
    }

    tiers.sort((a, b) => a.min.compareTo(b.min));
    return tiers;
  }

  static int? _toInt(dynamic raw) {
    final value = parseOfferNumber(raw);
    if (value == null) return null;
    return value.toInt();
  }
}

double? parseOfferNumber(dynamic raw) {
  if (raw is num) return raw.toDouble();
  if (raw is String) {
    final normalized = raw.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }
  return null;
}

double? resolveOfferRate({
  required List<OfferPriceTier> tiers,
  required double points,
}) {
  for (final tier in tiers) {
    if (tier.contains(points)) return tier.pricePer1000;
  }
  return null;
}

double? resolveOfferDiscountPercent({
  required List<OfferDiscountTier> tiers,
  required double points,
}) {
  for (final tier in tiers) {
    if (tier.contains(points)) return tier.discountPercent;
  }
  return null;
}

double applyDiscountPercent({
  required double baseRate,
  required double discountPercent,
}) {
  if (discountPercent <= 0) return baseRate;
  final discounted = baseRate * (1 - (discountPercent / 100));
  if (discounted <= 0) return 0;
  return double.parse(discounted.toStringAsFixed(6));
}

double deriveDiscountPercentFromOfferRate({
  required double baseRate,
  required double offerRate,
}) {
  if (baseRate <= 0 || offerRate <= 0 || offerRate >= baseRate) {
    return 0;
  }
  final percent = ((baseRate - offerRate) / baseRate) * 100;
  return double.parse(percent.toStringAsFixed(6));
}

double legacyOfferRateForPoints({
  required Map<String, dynamic> data,
  required double points,
}) {
  final rate100 =
      parseOfferNumber(data['rate_100']) ??
      parseOfferNumber(data['offer5']) ??
      0;
  final rate500 = parseOfferNumber(data['rate_500']) ?? rate100;
  final rate1000 = parseOfferNumber(data['rate_1000']) ?? rate500;
  final rate50000 =
      parseOfferNumber(data['rate_50000']) ??
      parseOfferNumber(data['offer50']) ??
      0;
  final rate75000 = parseOfferNumber(data['rate_75000']) ?? rate50000;

  if (points >= 75000 && rate75000 > 0) return rate75000;
  if (points >= 50000 && rate50000 > 0) return rate50000;
  if (points >= 1000 && rate1000 > 0) return rate1000;
  if (points >= 500 && rate500 > 0) return rate500;
  if (points >= 100 && rate100 > 0) return rate100;
  return 0;
}
