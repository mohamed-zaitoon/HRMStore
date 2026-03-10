// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

typedef OfferRateResolver =
    double Function({required double points, required double fallbackRate});

class PriceTier {
  const PriceTier({
    required this.min,
    required this.max,
    required this.pricePer1000,
  });

  final int min;
  final int max;
  final double pricePer1000;
}

final RegExp _decimalPattern = RegExp(r'^([+-]?)(\d+)(?:\.(\d+))?$');
final List<BigInt> _pow10Cache = <BigInt>[BigInt.one];

double? parseFlexibleDouble(String raw) {
  final normalized = raw.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

int ceilMoneyAmount(num value) {
  final decimal = _ScaledDecimal.parse(value);
  return _divideCeil(decimal.units, _pow10(decimal.scale)).toInt();
}

int floorCoinAmount(num value) {
  final decimal = _ScaledDecimal.parse(value);
  return (decimal.units ~/ _pow10(decimal.scale)).toInt();
}

int calculatePriceFromPoints({required num points, required num pricePer1000}) {
  final pointsDecimal = _ScaledDecimal.parse(points);
  final rateDecimal = _ScaledDecimal.parse(pricePer1000);
  final numerator = pointsDecimal.units * rateDecimal.units;
  final denominator =
      BigInt.from(1000) * _pow10(pointsDecimal.scale + rateDecimal.scale);
  return _divideCeil(numerator, denominator).toInt();
}

int calculatePointsFromAmount({
  required num amount,
  required num pricePer1000,
}) {
  final amountDecimal = _ScaledDecimal.parse(amount);
  final rateDecimal = _ScaledDecimal.parse(pricePer1000);
  final numerator =
      amountDecimal.units * BigInt.from(1000) * _pow10(rateDecimal.scale);
  final denominator = rateDecimal.units * _pow10(amountDecimal.scale);
  return (numerator ~/ denominator).toInt();
}

PriceTier resolveTierForPoints({
  required List<PriceTier> tiers,
  required double points,
}) {
  final firstTier = tiers.first;
  final lastTier = tiers.last;
  return tiers.firstWhere(
    (tier) => points >= tier.min && points <= tier.max,
    orElse: () => points < firstTier.min ? firstTier : lastTier,
  );
}

int calculateBestPointsFromAmount({
  required num amount,
  required List<PriceTier> tiers,
  OfferRateResolver? offerRateResolver,
}) {
  if (tiers.isEmpty) return 0;

  for (final tier in tiers.reversed) {
    final baseRate = tier.pricePer1000;
    var potentialPoints = calculatePointsFromAmount(
      amount: amount,
      pricePer1000: baseRate,
    );
    final appliedRate =
        offerRateResolver?.call(
          points: potentialPoints.toDouble(),
          fallbackRate: baseRate,
        ) ??
        baseRate;
    potentialPoints = calculatePointsFromAmount(
      amount: amount,
      pricePer1000: appliedRate,
    );

    if (potentialPoints >= tier.min) {
      return potentialPoints;
    }
  }

  return calculatePointsFromAmount(
    amount: amount,
    pricePer1000: tiers.first.pricePer1000,
  );
}

BigInt _divideCeil(BigInt numerator, BigInt denominator) {
  if (numerator <= BigInt.zero) return BigInt.zero;
  return (numerator + denominator - BigInt.one) ~/ denominator;
}

BigInt _pow10(int exponent) {
  while (_pow10Cache.length <= exponent) {
    _pow10Cache.add(_pow10Cache.last * BigInt.from(10));
  }
  return _pow10Cache[exponent];
}

class _ScaledDecimal {
  const _ScaledDecimal({required this.units, required this.scale});

  final BigInt units;
  final int scale;

  factory _ScaledDecimal.parse(Object raw) {
    final normalized = raw.toString().trim().replaceAll(',', '.');
    final match = _decimalPattern.firstMatch(normalized);
    if (match == null) {
      throw FormatException('Invalid decimal value: $raw');
    }

    final sign = match.group(1) == '-' ? -1 : 1;
    final integerPart = match.group(2) ?? '0';
    final fractionPart = match.group(3) ?? '';
    final digits = '$integerPart$fractionPart';
    var units = BigInt.parse(digits);
    if (sign < 0) units = -units;
    var scale = fractionPart.length;

    while (scale > 0 && units.remainder(BigInt.from(10)) == BigInt.zero) {
      units ~/= BigInt.from(10);
      scale -= 1;
    }

    return _ScaledDecimal(units: units, scale: scale);
  }
}
