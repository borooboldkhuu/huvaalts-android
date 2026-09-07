import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/features/admin/domain/entities/platform_settings.dart';
import 'package:huvalts/features/admin/presentation/controllers/admin_providers.dart';
import 'package:huvalts/features/admin/presentation/controllers/commission_settings_controller.dart';

import 'fake_admin_repository.dart';

void main() {
  test('update forwards the percent and returns the updated settings', () async {
    final fake = FakeAdminRepository()
      ..updateCommissionResult = PlatformSettings(
        commissionPercent: 12.5,
        updatedAt: DateTime(2026, 8, 17),
        updatedBy: 'admin-1',
      );
    final container = ProviderContainer(overrides: [adminRepositoryProvider.overrideWithValue(fake)]);
    addTearDown(container.dispose);

    final controller = container.read(commissionSettingsControllerProvider.notifier);
    final result = await controller.update(12.5);

    expect(fake.lastCommissionPercent, 12.5);
    expect(result.commissionPercent, 12.5);
    expect(controller.state.isSubmitting, isFalse);
  });

  test('rethrows on failure (e.g. invalid_commission_percent) and resets isSubmitting', () async {
    final fake = FakeAdminRepository()..errorToThrow = Exception('invalid_commission_percent');
    final container = ProviderContainer(overrides: [adminRepositoryProvider.overrideWithValue(fake)]);
    addTearDown(container.dispose);

    final controller = container.read(commissionSettingsControllerProvider.notifier);

    await expectLater(controller.update(150), throwsException);
    expect(controller.state.isSubmitting, isFalse);
  });
}
