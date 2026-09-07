import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/features/disputes/domain/entities/dispute_category.dart';

void main() {
  group('DisputeCategory.fromId', () {
    test('round-trips every known id back to its enum value', () {
      for (final category in DisputeCategory.values) {
        expect(DisputeCategory.fromId(category.id), category);
      }
    });

    test('falls back to other for an unrecognized id', () {
      expect(DisputeCategory.fromId('not_a_real_category'), DisputeCategory.other);
    });
  });
}
