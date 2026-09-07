import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/features/admin/domain/entities/asset_moderation_summary.dart';
import 'package:huvalts/features/admin/presentation/controllers/admin_providers.dart';
import 'package:huvalts/features/admin/presentation/controllers/asset_moderation_controller.dart';
import 'package:huvalts/features/assets/domain/entities/asset_status.dart';

import 'fake_admin_repository.dart';

AssetModerationSummary _asset({AssetStatus status = AssetStatus.pendingReview, String? note}) {
  return AssetModerationSummary(
    id: 'asset-1',
    ownerId: 'owner-1',
    ownerDisplayName: 'Бат',
    title: 'Дрон',
    status: status,
    moderationNote: note,
    primaryImagePath: null,
    displayPrice: 20000,
    currency: 'MNT',
    createdAt: DateTime(2026, 8, 17),
  );
}

void main() {
  test('approve forwards the asset id and returns the approved summary', () async {
    final fake = FakeAdminRepository()..approveResult = _asset(status: AssetStatus.published);
    final container = ProviderContainer(overrides: [adminRepositoryProvider.overrideWithValue(fake)]);
    addTearDown(container.dispose);

    final controller = container.read(assetModerationControllerProvider.notifier);
    final result = await controller.approve('asset-1');

    expect(fake.lastApprovedAssetId, 'asset-1');
    expect(result.status, AssetStatus.published);
    expect(controller.state.isSubmitting, isFalse);
  });

  test('reject forwards the asset id and reason', () async {
    final fake = FakeAdminRepository()
      ..rejectResult = _asset(status: AssetStatus.draft, note: 'blurry photos');
    final container = ProviderContainer(overrides: [adminRepositoryProvider.overrideWithValue(fake)]);
    addTearDown(container.dispose);

    final controller = container.read(assetModerationControllerProvider.notifier);
    final result = await controller.reject(assetId: 'asset-1', reason: 'blurry photos');

    expect(fake.lastRejectedAssetId, 'asset-1');
    expect(fake.lastRejectReason, 'blurry photos');
    expect(result.moderationNote, 'blurry photos');
  });

  test('suspend forwards the asset id and reason', () async {
    final fake = FakeAdminRepository()..suspendResult = _asset(status: AssetStatus.suspended);
    final container = ProviderContainer(overrides: [adminRepositoryProvider.overrideWithValue(fake)]);
    addTearDown(container.dispose);

    final controller = container.read(assetModerationControllerProvider.notifier);
    final result = await controller.suspend(assetId: 'asset-1', reason: 'reported by multiple renters');

    expect(fake.lastSuspendedAssetId, 'asset-1');
    expect(result.status, AssetStatus.suspended);
  });

  test('isSubmitting is true only while an action is in flight', () async {
    final fake = FakeAdminRepository()..approveResult = _asset(status: AssetStatus.published);
    final container = ProviderContainer(overrides: [adminRepositoryProvider.overrideWithValue(fake)]);
    addTearDown(container.dispose);

    final controller = container.read(assetModerationControllerProvider.notifier);
    expect(controller.state.isSubmitting, isFalse);

    final future = controller.approve('asset-1');
    expect(controller.state.isSubmitting, isTrue);

    await future;
    expect(controller.state.isSubmitting, isFalse);
  });

  test('rethrows on failure (e.g. not_authorized) and still resets isSubmitting', () async {
    final fake = FakeAdminRepository()..errorToThrow = Exception('not_authorized');
    final container = ProviderContainer(overrides: [adminRepositoryProvider.overrideWithValue(fake)]);
    addTearDown(container.dispose);

    final controller = container.read(assetModerationControllerProvider.notifier);

    await expectLater(controller.approve('asset-1'), throwsException);
    expect(controller.state.isSubmitting, isFalse);
  });
}
