import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/features/admin/presentation/controllers/admin_providers.dart';
import 'package:huvalts/features/admin/presentation/controllers/dispute_resolution_controller.dart';
import 'package:huvalts/features/disputes/domain/entities/dispute.dart';
import 'package:huvalts/features/disputes/domain/entities/dispute_category.dart';
import 'package:huvalts/features/disputes/domain/entities/dispute_status.dart';

import 'fake_admin_repository.dart';

Dispute _dispute({DisputeStatus status = DisputeStatus.resolved, String? notes}) {
  return Dispute(
    id: 'dispute-1',
    bookingId: 'booking-1',
    raisedBy: 'renter-1',
    category: DisputeCategory.itemDamaged,
    description: 'The item came back scratched.',
    evidencePaths: const [],
    status: status,
    resolutionNotes: notes,
    resolvedBy: status == DisputeStatus.resolved || status == DisputeStatus.rejected ? 'admin-1' : null,
    createdAt: DateTime(2026, 8, 1),
    updatedAt: DateTime(2026, 8, 17),
  );
}

void main() {
  test('resolve forwards disputeId, newStatus, and resolutionNotes', () async {
    final fake = FakeAdminRepository()
      ..resolveDisputeResult = _dispute(status: DisputeStatus.resolved, notes: 'refunded deposit');
    final container = ProviderContainer(overrides: [adminRepositoryProvider.overrideWithValue(fake)]);
    addTearDown(container.dispose);

    final controller = container.read(disputeResolutionControllerProvider.notifier);
    final result = await controller.resolve(
      disputeId: 'dispute-1',
      newStatus: DisputeStatus.resolved,
      resolutionNotes: 'refunded deposit',
    );

    expect(fake.lastResolvedDisputeId, 'dispute-1');
    expect(fake.lastDisputeStatus, DisputeStatus.resolved);
    expect(fake.lastResolutionNotes, 'refunded deposit');
    expect(result.status, DisputeStatus.resolved);
    expect(controller.state.isSubmitting, isFalse);
  });

  test('resolutionNotes is optional (null when not provided)', () async {
    final fake = FakeAdminRepository()..resolveDisputeResult = _dispute(status: DisputeStatus.escalated);
    final container = ProviderContainer(overrides: [adminRepositoryProvider.overrideWithValue(fake)]);
    addTearDown(container.dispose);

    final controller = container.read(disputeResolutionControllerProvider.notifier);
    await controller.resolve(disputeId: 'dispute-1', newStatus: DisputeStatus.escalated);

    expect(fake.lastResolutionNotes, isNull);
  });

  test('rethrows on failure (e.g. dispute_not_found) and resets isSubmitting', () async {
    final fake = FakeAdminRepository()..errorToThrow = Exception('dispute_not_found');
    final container = ProviderContainer(overrides: [adminRepositoryProvider.overrideWithValue(fake)]);
    addTearDown(container.dispose);

    final controller = container.read(disputeResolutionControllerProvider.notifier);

    await expectLater(
      controller.resolve(disputeId: 'dispute-1', newStatus: DisputeStatus.resolved),
      throwsException,
    );
    expect(controller.state.isSubmitting, isFalse);
  });
}
