import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/core/utils/date_range_utils.dart';

void main() {
  group('DateRangeUtils.overlapsAny', () {
    test('false when there are no blocked ranges', () {
      final result = DateRangeUtils.overlapsAny(
        DateTime(2026, 8, 20),
        DateTime(2026, 8, 22),
        const [],
      );
      expect(result, isFalse);
    });

    test('false when the requested range is entirely before a blocked range', () {
      final result = DateRangeUtils.overlapsAny(
        DateTime(2026, 8, 10),
        DateTime(2026, 8, 12),
        [(DateTime(2026, 8, 20), DateTime(2026, 8, 22))],
      );
      expect(result, isFalse);
    });

    test('false when the requested range is entirely after a blocked range', () {
      final result = DateRangeUtils.overlapsAny(
        DateTime(2026, 8, 25),
        DateTime(2026, 8, 27),
        [(DateTime(2026, 8, 20), DateTime(2026, 8, 22))],
      );
      expect(result, isFalse);
    });

    test('true when the requested range is fully inside a blocked range', () {
      final result = DateRangeUtils.overlapsAny(
        DateTime(2026, 8, 21),
        DateTime(2026, 8, 21),
        [(DateTime(2026, 8, 20), DateTime(2026, 8, 22))],
      );
      expect(result, isTrue);
    });

    test('true when the requested range only touches the blocked range at one shared day', () {
      // Both ranges are inclusive of both endpoints (matches the
      // database's same-day-turnover-proof semantics — see this class's
      // doc comment), so sharing exactly day 22 counts as an overlap.
      final result = DateRangeUtils.overlapsAny(
        DateTime(2026, 8, 22),
        DateTime(2026, 8, 24),
        [(DateTime(2026, 8, 20), DateTime(2026, 8, 22))],
      );
      expect(result, isTrue);
    });

    test('true when the requested range fully contains a blocked range', () {
      final result = DateRangeUtils.overlapsAny(
        DateTime(2026, 8, 1),
        DateTime(2026, 8, 30),
        [(DateTime(2026, 8, 20), DateTime(2026, 8, 22))],
      );
      expect(result, isTrue);
    });

    test('checks every blocked range, not just the first', () {
      final blocked = [
        (DateTime(2026, 8, 1), DateTime(2026, 8, 3)),
        (DateTime(2026, 9, 1), DateTime(2026, 9, 3)),
      ];
      expect(DateRangeUtils.overlapsAny(DateTime(2026, 9, 2), DateTime(2026, 9, 2), blocked), isTrue);
      expect(DateRangeUtils.overlapsAny(DateTime(2026, 8, 15), DateTime(2026, 8, 16), blocked), isFalse);
    });

    test('ignores time-of-day components, comparing dates only', () {
      final result = DateRangeUtils.overlapsAny(
        DateTime(2026, 8, 22, 23, 59),
        DateTime(2026, 8, 23, 0, 1),
        [(DateTime(2026, 8, 20, 8, 0), DateTime(2026, 8, 22, 9, 0))],
      );
      expect(result, isTrue);
    });
  });
}
