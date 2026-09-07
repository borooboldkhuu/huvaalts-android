import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/features/reviews/domain/entities/reviewer_role.dart';

void main() {
  group('ReviewerRole.fromId', () {
    test('round-trips every known id back to its enum value', () {
      for (final role in ReviewerRole.values) {
        expect(ReviewerRole.fromId(role.id), role);
      }
    });

    test('falls back to renter for an unrecognized id', () {
      expect(ReviewerRole.fromId('not_a_real_role'), ReviewerRole.renter);
    });
  });
}
