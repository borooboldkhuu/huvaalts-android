import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/features/wallet/domain/entities/payout_status.dart';
import 'package:huvalts/features/wallet/domain/entities/wallet_transaction_type.dart';

void main() {
  group('WalletTransactionType.fromId', () {
    test('round-trips every known id back to its enum value', () {
      for (final type in WalletTransactionType.values) {
        expect(WalletTransactionType.fromId(type.id), type);
      }
    });

    test('falls back to adjustment for an unrecognized id', () {
      expect(WalletTransactionType.fromId('not_a_real_type'), WalletTransactionType.adjustment);
    });
  });

  group('PayoutStatus.fromId', () {
    test('round-trips every known id back to its enum value', () {
      for (final status in PayoutStatus.values) {
        expect(PayoutStatus.fromId(status.id), status);
      }
    });

    test('falls back to pending for an unrecognized id', () {
      expect(PayoutStatus.fromId('not_a_real_status'), PayoutStatus.pending);
    });
  });
}
