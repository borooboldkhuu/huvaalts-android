import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/core/utils/geo_utils.dart';

void main() {
  group('GeoUtils.distanceKm', () {
    test('same point is zero distance', () {
      expect(GeoUtils.distanceKm(47.9184, 106.9177, 47.9184, 106.9177), closeTo(0, 0.001));
    });

    test('Ulaanbaatar to Darkhan is roughly 200km', () {
      // Sukhbaatar Square, UB -> central Darkhan.
      final double km = GeoUtils.distanceKm(47.9184, 106.9177, 49.4867, 105.9228);
      expect(km, greaterThan(150));
      expect(km, lessThan(250));
    });

    test('distance is symmetric', () {
      final double ab = GeoUtils.distanceKm(47.9184, 106.9177, 49.4867, 105.9228);
      final double ba = GeoUtils.distanceKm(49.4867, 105.9228, 47.9184, 106.9177);
      expect(ab, closeTo(ba, 0.0001));
    });
  });
}
