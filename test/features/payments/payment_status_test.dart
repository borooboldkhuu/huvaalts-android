import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/features/payments/domain/entities/payment_status.dart';

void main() {
  group('PaymentStatus.fromId', () {
    test('round-trips every known id back to its enum value', () {
      for (final status in PaymentStatus.values) {
        expect(PaymentStatus.fromId(status.id), status);
      }
    });

    test('falls back to pending for an unrecognized id', () {
      expect(PaymentStatus.fromId('not_a_real_status'), PaymentStatus.pending);
    });

    test('partially_refunded id maps to partiallyRefunded', () {
      expect(PaymentStatus.fromId('partially_refunded'), PaymentStatus.partiallyRefunded);
    });
  });
}
