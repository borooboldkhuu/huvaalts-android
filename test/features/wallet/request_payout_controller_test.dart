import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/features/wallet/domain/entities/payout.dart';
import 'package:huvalts/features/wallet/domain/entities/payout_status.dart';
import 'package:huvalts/features/wallet/domain/entities/wallet.dart';
import 'package:huvalts/features/wallet/domain/entities/wallet_transaction.dart';
import 'package:huvalts/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:huvalts/features/wallet/presentation/controllers/request_payout_controller.dart';
import 'package:huvalts/features/wallet/presentation/controllers/wallet_providers.dart';

Payout _payout({double amount = 10000}) {
  return Payout(
    id: 'payout-1',
    userId: 'user-1',
    amount: amount,
    status: PayoutStatus.pending,
    destinationReference: null,
    requestedAt: DateTime(2026, 8, 17),
    processedAt: null,
  );
}

class _FakeWalletRepository implements WalletRepository {
  double? lastRequestedAmount;
  Object? errorToThrow;

  @override
  Future<Wallet> getWallet(String userId) async {
    return Wallet(
      userId: userId,
      availableBalance: 50000,
      pendingBalance: 0,
      totalEarned: 50000,
      updatedAt: DateTime(2026, 8, 17),
    );
  }

  @override
  Future<List<WalletTransaction>> getTransactions(String userId) async => const [];

  @override
  Future<List<Payout>> getPayouts(String userId) async => const [];

  @override
  Future<Payout> requestPayout({required double amount}) async {
    lastRequestedAmount = amount;
    if (errorToThrow != null) throw errorToThrow!;
    return _payout(amount: amount);
  }
}

void main() {
  test('submit forwards the amount and returns the created payout', () async {
    final fake = _FakeWalletRepository();
    final container = ProviderContainer(
      overrides: [walletRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    final controller = container.read(requestPayoutControllerProvider.notifier);
    final payout = await controller.submit(amount: 15000);

    expect(payout.id, 'payout-1');
    expect(payout.amount, 15000);
    expect(fake.lastRequestedAmount, 15000);
    expect(controller.state.isSubmitting, isFalse, reason: 'must reset after completing');
  });

  test('isSubmitting is true only while the call is in flight', () async {
    final fake = _FakeWalletRepository();
    final container = ProviderContainer(
      overrides: [walletRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    final controller = container.read(requestPayoutControllerProvider.notifier);
    expect(controller.state.isSubmitting, isFalse);

    final future = controller.submit(amount: 5000);
    expect(controller.state.isSubmitting, isTrue);

    await future;
    expect(controller.state.isSubmitting, isFalse);
  });

  test('rethrows on failure and still resets isSubmitting', () async {
    final fake = _FakeWalletRepository()..errorToThrow = Exception('insufficient_available_balance');
    final container = ProviderContainer(
      overrides: [walletRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    final controller = container.read(requestPayoutControllerProvider.notifier);

    await expectLater(controller.submit(amount: 999999), throwsException);
    expect(controller.state.isSubmitting, isFalse);
  });
}
