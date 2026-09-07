import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/features/admin/domain/entities/promotion.dart';
import 'package:huvalts/features/admin/presentation/controllers/admin_providers.dart';
import 'package:huvalts/features/admin/presentation/controllers/promotion_management_controller.dart';

import 'fake_admin_repository.dart';

Promotion _promotion({bool isActive = true}) {
  return Promotion(
    id: 'promo-1',
    code: 'SUMMER25',
    title: 'Зуны хямдрал',
    description: null,
    discountPercent: 25,
    startsAt: DateTime(2026, 8, 1),
    endsAt: DateTime(2026, 9, 1),
    isActive: isActive,
    createdAt: DateTime(2026, 7, 20),
  );
}

void main() {
  test('upsert forwards a null id for create and returns the created promotion', () async {
    final fake = FakeAdminRepository()..upsertPromotionResult = _promotion();
    final container = ProviderContainer(overrides: [adminRepositoryProvider.overrideWithValue(fake)]);
    addTearDown(container.dispose);

    final controller = container.read(promotionManagementControllerProvider.notifier);
    final result = await controller.upsert(
      title: 'Зуны хямдрал',
      startsAt: DateTime(2026, 8, 1),
      endsAt: DateTime(2026, 9, 1),
      isActive: true,
    );

    expect(fake.lastUpsertedPromotionId, isNull);
    expect(fake.lastUpsertedPromotionTitle, 'Зуны хямдрал');
    expect(result.id, 'promo-1');
    expect(controller.state.isSubmitting, isFalse);
  });

  test('upsert forwards a non-null id for an edit', () async {
    final fake = FakeAdminRepository()..upsertPromotionResult = _promotion();
    final container = ProviderContainer(overrides: [adminRepositoryProvider.overrideWithValue(fake)]);
    addTearDown(container.dispose);

    final controller = container.read(promotionManagementControllerProvider.notifier);
    await controller.upsert(
      id: 'promo-1',
      title: 'Зуны хямдрал',
      startsAt: DateTime(2026, 8, 1),
      endsAt: DateTime(2026, 9, 1),
      isActive: true,
    );

    expect(fake.lastUpsertedPromotionId, 'promo-1');
  });

  test('deactivate forwards the promotion id and returns the inactive result', () async {
    final fake = FakeAdminRepository()..deactivatePromotionResult = _promotion(isActive: false);
    final container = ProviderContainer(overrides: [adminRepositoryProvider.overrideWithValue(fake)]);
    addTearDown(container.dispose);

    final controller = container.read(promotionManagementControllerProvider.notifier);
    final result = await controller.deactivate('promo-1');

    expect(fake.lastDeactivatedPromotionId, 'promo-1');
    expect(result.isActive, isFalse);
    expect(controller.state.isSubmitting, isFalse);
  });

  test('isSubmitting is true only while an action is in flight', () async {
    final fake = FakeAdminRepository()..upsertPromotionResult = _promotion();
    final container = ProviderContainer(overrides: [adminRepositoryProvider.overrideWithValue(fake)]);
    addTearDown(container.dispose);

    final controller = container.read(promotionManagementControllerProvider.notifier);
    expect(controller.state.isSubmitting, isFalse);

    final future = controller.upsert(
      title: 'Зуны хямдрал',
      startsAt: DateTime(2026, 8, 1),
      endsAt: DateTime(2026, 9, 1),
      isActive: true,
    );
    expect(controller.state.isSubmitting, isTrue);

    await future;
    expect(controller.state.isSubmitting, isFalse);
  });

  test('rethrows on failure (e.g. invalid_date_range) and resets isSubmitting', () async {
    final fake = FakeAdminRepository()..errorToThrow = Exception('invalid_date_range');
    final container = ProviderContainer(overrides: [adminRepositoryProvider.overrideWithValue(fake)]);
    addTearDown(container.dispose);

    final controller = container.read(promotionManagementControllerProvider.notifier);

    await expectLater(
      controller.upsert(
        title: 'Зуны хямдрал',
        startsAt: DateTime(2026, 9, 1),
        endsAt: DateTime(2026, 8, 1),
        isActive: true,
      ),
      throwsException,
    );
    expect(controller.state.isSubmitting, isFalse);
  });
}
