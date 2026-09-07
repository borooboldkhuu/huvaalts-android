import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/features/booking/domain/entities/price_breakdown.dart';

void main() {
  group('PriceBreakdown.estimate', () {
    test('computes nights, rental amount, platform fee, and total', () {
      final breakdown = PriceBreakdown.estimate(
        pricePerDay: 40000,
        startDate: DateTime(2026, 8, 20),
        endDate: DateTime(2026, 8, 23),
        commissionPercent: 10,
      );

      expect(breakdown.nights, 3);
      expect(breakdown.rentalAmount, 120000);
      expect(breakdown.platformFee, 12000);
      expect(breakdown.totalAmount, 132000);
    });

    test('clamps to at least 1 night even for a same-day range', () {
      final breakdown = PriceBreakdown.estimate(
        pricePerDay: 40000,
        startDate: DateTime(2026, 8, 20),
        endDate: DateTime(2026, 8, 20),
        commissionPercent: 10,
      );

      expect(breakdown.nights, 1);
      expect(breakdown.rentalAmount, 40000);
    });

    test('total is rental amount plus platform fee', () {
      final breakdown = PriceBreakdown.estimate(
        pricePerDay: 10000,
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 2),
        commissionPercent: 10,
      );

      expect(breakdown.totalAmount, breakdown.rentalAmount + breakdown.platformFee);
    });

    test('platform fee scales with nights via the rounded rental amount', () {
      final breakdown = PriceBreakdown.estimate(
        pricePerDay: 15000,
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 5),
        commissionPercent: 10,
      );

      expect(breakdown.nights, 4);
      expect(breakdown.rentalAmount, 60000);
      expect(breakdown.platformFee, 6000);
      expect(breakdown.totalAmount, 66000);
    });
  });
}
