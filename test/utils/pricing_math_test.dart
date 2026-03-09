import 'package:flutter_test/flutter_test.dart';
import 'package:hrmstoreapp/utils/pricing_math.dart';

void main() {
  group('pricing math', () {
    test('parses flexible decimal input', () {
      expect(parseFlexibleDouble('151'), 151);
      expect(parseFlexibleDouble('151.5'), 151.5);
      expect(parseFlexibleDouble('151,5'), 151.5);
      expect(parseFlexibleDouble(''), isNull);
    });

    test('money is rounded up only when a fraction exists', () {
      expect(ceilMoneyAmount(149), 149);
      expect(ceilMoneyAmount(149.1), 150);
      expect(ceilMoneyAmount(149.9), 150);
    });

    test('coins are always truncated down', () {
      expect(floorCoinAmount(200), 200);
      expect(floorCoinAmount(200.5), 200);
      expect(floorCoinAmount(201.2), 201);
    });

    test('price from points no longer jumps to the nearest five', () {
      expect(calculatePriceFromPoints(points: 200, pricePer1000: 726), 146);
    });

    test('price from decimal rate stays exact around integer boundaries', () {
      expect(calculatePriceFromPoints(points: 200, pricePer1000: 745.5), 150);
      expect(calculatePriceFromPoints(points: 250, pricePer1000: 596), 149);
    });

    test('amount to coins accepts any whole pound and floors the result', () {
      final tiers = <PriceTier>[
        const PriceTier(min: 150, max: 499, pricePer1000: 750),
      ];

      expect(calculateBestPointsFromAmount(amount: 150, tiers: tiers), 200);
      expect(calculateBestPointsFromAmount(amount: 151, tiers: tiers), 201);
    });

    test('amount to coins stays exact with decimal price per 1000', () {
      expect(calculatePointsFromAmount(amount: 150, pricePer1000: 748.5), 200);
      expect(calculatePointsFromAmount(amount: 151, pricePer1000: 748.5), 201);
    });

    test('amount to coins reapplies offer rate before truncation', () {
      final tiers = <PriceTier>[
        const PriceTier(min: 150, max: 499, pricePer1000: 800),
      ];

      final points = calculateBestPointsFromAmount(
        amount: 150,
        tiers: tiers,
        offerRateResolver:
            ({required double points, required double fallbackRate}) {
              if (points >= 100) return 750;
              return fallbackRate;
            },
      );

      expect(points, 200);
    });

    test('user-facing rounded money stays synchronized with coin amount', () {
      final tiers = <PriceTier>[
        const PriceTier(min: 150, max: 499, pricePer1000: 1010),
      ];

      final displayedMoney = calculatePriceFromPoints(
        points: 150,
        pricePer1000: 1010,
      );
      final restoredPoints = calculateBestPointsFromAmount(
        amount: displayedMoney,
        tiers: tiers,
      );

      expect(displayedMoney, 152);
      expect(restoredPoints, 150);
    });
  });
}
