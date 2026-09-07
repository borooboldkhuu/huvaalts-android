import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/core/utils/app_date_utils.dart';

void main() {
  group('AppDateUtils.wholeDaysBetween', () {
    test('counts whole calendar days regardless of time-of-day', () {
      final start = DateTime(2026, 8, 17, 22);
      final end = DateTime(2026, 8, 20, 6);
      expect(AppDateUtils.wholeDaysBetween(start, end), 3);
    });

    test('same day returns 0', () {
      final day = DateTime(2026, 8, 17);
      expect(AppDateUtils.wholeDaysBetween(day, day), 0);
    });
  });

  group('AppDateUtils.formatShortDate', () {
    test('formats as yyyy.MM.dd', () {
      expect(AppDateUtils.formatShortDate(DateTime(2026, 8, 17)), '2026.08.17');
    });
  });
}
