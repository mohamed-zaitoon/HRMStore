import 'package:flutter_test/flutter_test.dart';
import 'package:hrmstoreapp/utils/offer_discount_tiers.dart';

void main() {
  group('offer discount tiers', () {
    test('parses saved manual offer tiers', () {
      final tiers = OfferPriceTier.parseList([
        {'min': 500, 'max': 999, 'price_per_1000': 148.5},
        {'min': 150, 'max': 499, 'pricePer1000': '151.2'},
      ]);

      expect(tiers.length, 2);
      expect(tiers.first.min, 150);
      expect(tiers.first.pricePer1000, 151.2);
      expect(tiers.last.min, 500);
      expect(tiers.last.pricePer1000, 148.5);
    });

    test('resolves manual offer rate by matching tier', () {
      final tiers = <OfferPriceTier>[
        const OfferPriceTier(min: 150, max: 499, pricePer1000: 151.5),
        const OfferPriceTier(min: 500, max: 999, pricePer1000: 149),
      ];

      expect(resolveOfferRate(tiers: tiers, points: 200), 151.5);
      expect(resolveOfferRate(tiers: tiers, points: 800), 149);
      expect(resolveOfferRate(tiers: tiers, points: 1200), isNull);
    });

    test('parses saved discount tiers', () {
      final tiers = OfferDiscountTier.parseList([
        {'min': 500, 'max': 999, 'discount_percent': 8.5},
        {'min': 150, 'max': 499, 'discount_percent': '12'},
      ]);

      expect(tiers.length, 2);
      expect(tiers.first.min, 150);
      expect(tiers.first.discountPercent, 12);
      expect(tiers.last.min, 500);
      expect(tiers.last.discountPercent, 8.5);
    });

    test('resolves discount percent by matching tier', () {
      final tiers = <OfferDiscountTier>[
        const OfferDiscountTier(min: 150, max: 499, discountPercent: 10),
        const OfferDiscountTier(min: 500, max: 999, discountPercent: 7.5),
      ];

      expect(resolveOfferDiscountPercent(tiers: tiers, points: 200), 10);
      expect(resolveOfferDiscountPercent(tiers: tiers, points: 800), 7.5);
      expect(resolveOfferDiscountPercent(tiers: tiers, points: 1200), isNull);
    });

    test('applies percentage discount to base rate', () {
      expect(applyDiscountPercent(baseRate: 800, discountPercent: 12.5), 700);
      expect(applyDiscountPercent(baseRate: 726, discountPercent: 5), 689.7);
    });

    test('derives percent from legacy fixed offer rate', () {
      expect(
        deriveDiscountPercentFromOfferRate(baseRate: 800, offerRate: 700),
        12.5,
      );
      expect(
        deriveDiscountPercentFromOfferRate(baseRate: 800, offerRate: 800),
        0,
      );
    });

    test('reads legacy offer breakpoints for migration', () {
      final data = <String, dynamic>{
        'rate_100': 760,
        'rate_500': 730,
        'rate_1000': 700,
        'rate_50000': 680,
        'rate_75000': 660,
      };

      expect(legacyOfferRateForPoints(data: data, points: 200), 760);
      expect(legacyOfferRateForPoints(data: data, points: 700), 730);
      expect(legacyOfferRateForPoints(data: data, points: 5000), 700);
      expect(legacyOfferRateForPoints(data: data, points: 60000), 680);
      expect(legacyOfferRateForPoints(data: data, points: 80000), 660);
    });
  });
}
