import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/features/disputes/domain/entities/dispute.dart';
import 'package:huvalts/features/disputes/domain/entities/dispute_category.dart';
import 'package:huvalts/features/disputes/domain/entities/dispute_status.dart';
import 'package:huvalts/features/disputes/domain/repositories/dispute_repository.dart';
import 'package:huvalts/features/disputes/presentation/controllers/dispute_providers.dart';
import 'package:huvalts/features/disputes/presentation/controllers/submit_dispute_controller.dart';

Dispute _dispute({DisputeCategory category = DisputeCategory.itemDamaged}) {
  return Dispute(
    id: 'dispute-1',
    bookingId: 'booking-1',
    raisedBy: 'renter-1',
    category: category,
    description: 'It broke',
    evidencePaths: const [],
    status: DisputeStatus.open,
    resolutionNotes: null,
    resolvedBy: null,
    createdAt: DateTime(2026, 8, 17),
    updatedAt: DateTime(2026, 8, 17),
  );
}

class _FakeDisputeRepository implements DisputeRepository {
  ({String bookingId, DisputeCategory category, String description})? lastSubmitArgs;
  Object? errorToThrow;

  @override
  Future<Dispute?> getLatestDisputeForBooking(String bookingId) async => null;

  @override
  Future<Dispute> submitDispute({
    required String bookingId,
    required DisputeCategory category,
    required String description,
    required List<(Uint8List, String)> evidence,
  }) async {
    lastSubmitArgs = (bookingId: bookingId, category: category, description: description);
    if (errorToThrow != null) throw errorToThrow!;
    return _dispute(category: category);
  }

  @override
  Future<String> signedEvidenceUrl(String path) async => 'https://example.com/$path';
}

void main() {
  test('submit forwards bookingId/category/description and returns the dispute', () async {
    final fake = _FakeDisputeRepository();
    final container = ProviderContainer(
      overrides: [disputeRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    final controller = container.read(submitDisputeControllerProvider.notifier);
    final dispute = await controller.submit(
      bookingId: 'booking-1',
      category: DisputeCategory.lateReturn,
      description: 'Returned three days late',
    );

    expect(dispute.category, DisputeCategory.lateReturn);
    expect(fake.lastSubmitArgs?.bookingId, 'booking-1');
    expect(fake.lastSubmitArgs?.category, DisputeCategory.lateReturn);
    expect(fake.lastSubmitArgs?.description, 'Returned three days late');
    expect(controller.state.isSubmitting, isFalse);
  });

  test('isSubmitting is true only while the call is in flight', () async {
    final fake = _FakeDisputeRepository();
    final container = ProviderContainer(
      overrides: [disputeRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    final controller = container.read(submitDisputeControllerProvider.notifier);
    expect(controller.state.isSubmitting, isFalse);

    final future = controller.submit(
      bookingId: 'booking-1',
      category: DisputeCategory.other,
      description: 'Something else',
    );
    expect(controller.state.isSubmitting, isTrue);

    await future;
    expect(controller.state.isSubmitting, isFalse);
  });

  test('rethrows on failure and still resets isSubmitting', () async {
    final fake = _FakeDisputeRepository()..errorToThrow = Exception('dispute_already_open');
    final container = ProviderContainer(
      overrides: [disputeRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    final controller = container.read(submitDisputeControllerProvider.notifier);

    await expectLater(
      controller.submit(
        bookingId: 'booking-1',
        category: DisputeCategory.other,
        description: 'Something else',
      ),
      throwsException,
    );
    expect(controller.state.isSubmitting, isFalse);
  });
}
