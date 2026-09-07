import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/features/disputes/domain/entities/dispute_status.dart';

void main() {
  group('DisputeStatus.fromId', () {
    test('round-trips every known id back to its enum value', () {
      for (final status in DisputeStatus.values) {
        expect(DisputeStatus.fromId(status.id), status);
      }
    });

    test('falls back to open for an unrecognized id', () {
      expect(DisputeStatus.fromId('not_a_real_status'), DisputeStatus.open);
    });
  });

  group('DisputeStatus.isActive', () {
    test('is true for open, under_review, and escalated', () {
      expect(DisputeStatus.open.isActive, isTrue);
      expect(DisputeStatus.underReview.isActive, isTrue);
      expect(DisputeStatus.escalated.isActive, isTrue);
    });

    test('is false for resolved and rejected', () {
      expect(DisputeStatus.resolved.isActive, isFalse);
      expect(DisputeStatus.rejected.isActive, isFalse);
    });
  });
}
