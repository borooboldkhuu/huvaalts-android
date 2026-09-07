import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/features/admin/presentation/controllers/admin_providers.dart';
import 'package:huvalts/features/admin/presentation/controllers/payout_processing_controller.dart';
import 'package:huvalts/features/wallet/domain/entities/payout.dart';
import 'package:huvalts/features/wallet/domain/entities/payout_status.dart';

import 'fake_admin_repository.dart';

Payout _payout({PayoutStatus status = PayoutStatus.processing, String? destinationReference}) {
  return Payout(
    id: 'payout-1',
    userId: 'owner-1',
    amount: 30000,
    status: status,
    destinationReference: destinationReference,
    requestedAt: DateTime(2026, 8, 1),
    processedAt: status == PayoutStatus.paid || status == PayoutStatus.failed
        ? DateTime(2026, 8, 17)
        : null,
  );
}

void main() {
  test('process forwards payoutId, newStatus, and destinationReference', () async {
    final fake = FakeAdminRepository()
      ..processPayoutResult = _payout(status: PayoutStatus.paid, destinationReference: 'ref-123');
    final container = ProviderContainer(overrides: [adminRepositoryProvider.overrideWithValue(fake)]);
    addTearDown(container.dispose);

    final controller = container.read(payoutProcessingControllerProvider.notifier);
    final result = await controller.process(
      payoutId: 'payout-1',
      newStatus: PayoutStatus.paid,
      destinationReference: 'ref-123',
    );

    expect(fake.lastProcessedPayoutId, 'payout-1');
    expect(fake.lastProcessedStatus, PayoutStatus.paid);
    expect(fake.lastDestinationReference, 'ref-123');
    expect(result.status, PayoutStatus.paid);
    expect(controller.state.isSubmitting, isFalse);
  });

  test('isSubmitting is true only while the call is in flight', () async {
    final fake = FakeAdminRepository()..processPayoutResult = _payout();
    final container = ProviderContainer(overrides: [adminRepositoryProvider.overrideWithValue(fake)]);
    addTearDown(container.dispose);

    final controller = container.read(payoutProcessingControllerProvider.notifier);
    expect(controller.state.isSubmitting, isFalse);

    final future = controller.process(payoutId: 'payout-1', newStatus: PayoutStatus.processing);
    expect(controller.state.isSubmitting, isTrue);

    await future;
    expect(controller.state.isSubmitting, isFalse);
  });

  test('rethrows on failure (e.g. invalid_status_transition) and resets isSubmitting', () async {
    final fake = FakeAdminRepository()..errorToThrow = Exception('invalid_status_transition');
    final container = ProviderContainer(overrides: [adminRepositoryProvider.overrideWithValue(fake)]);
    addTearDown(container.dispose);

    final controller = container.read(payoutProcessingControllerProvider.notifier);

    await expectLater(
      controller.process(payoutId: 'payout-1', newStatus: PayoutStatus.paid),
      throwsException,
    );
    expect(controller.state.isSubmitting, isFalse);
  });
}
