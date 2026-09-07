import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/features/admin/domain/entities/wire_topup_reconciliation_result.dart';
import 'package:huvalts/features/admin/presentation/controllers/admin_providers.dart';
import 'package:huvalts/features/admin/presentation/controllers/wire_topup_reconciliation_controller.dart';

import 'fake_admin_repository.dart';

void main() {
  ProviderContainer buildContainer(FakeAdminRepository fake) {
    final container = ProviderContainer(overrides: [adminRepositoryProvider.overrideWithValue(fake)]);
    addTearDown(container.dispose);
    return container;
  }

  test('starts Idle', () {
    final container = buildContainer(FakeAdminRepository());
    expect(container.read(wireTopupReconciliationControllerProvider), isA<WireTopupReconciliationIdle>());
  });

  test('reconcile() ends in Done carrying the repository result on success', () async {
    final fake = FakeAdminRepository()
      ..reconcileWireTopupsResult = const WireTopupReconciliationResult(checked: 5, credited: 2, markedFailed: 1);
    final container = buildContainer(fake);
    final controller = container.read(wireTopupReconciliationControllerProvider.notifier);

    await controller.reconcile();

    expect(fake.reconcileWireTopupsCallCount, 1);
    final state = container.read(wireTopupReconciliationControllerProvider);
    expect(state, isA<WireTopupReconciliationDone>());
    final result = (state as WireTopupReconciliationDone).result;
    expect(result.checked, 5);
    expect(result.credited, 2);
    expect(result.markedFailed, 1);
  });

  test('reconcile() ends in Failed (not a rethrow) when the repository throws', () async {
    final fake = FakeAdminRepository()..errorToThrow = Exception('wire_not_configured');
    final container = buildContainer(fake);
    final controller = container.read(wireTopupReconciliationControllerProvider.notifier);

    await controller.reconcile();

    final state = container.read(wireTopupReconciliationControllerProvider);
    expect(state, isA<WireTopupReconciliationFailed>());
  });

  test('state is InProgress while the call is in flight', () async {
    final fake = FakeAdminRepository()
      ..reconcileWireTopupsResult = const WireTopupReconciliationResult(checked: 0, credited: 0, markedFailed: 0);
    final container = buildContainer(fake);
    final controller = container.read(wireTopupReconciliationControllerProvider.notifier);

    final future = controller.reconcile();
    expect(
      container.read(wireTopupReconciliationControllerProvider),
      isA<WireTopupReconciliationInProgress>(),
    );
    await future;
  });

  test('reset() returns to Idle', () async {
    final fake = FakeAdminRepository()
      ..reconcileWireTopupsResult = const WireTopupReconciliationResult(checked: 0, credited: 0, markedFailed: 0);
    final container = buildContainer(fake);
    final controller = container.read(wireTopupReconciliationControllerProvider.notifier);
    await controller.reconcile();
    expect(container.read(wireTopupReconciliationControllerProvider), isA<WireTopupReconciliationDone>());

    controller.reset();

    expect(container.read(wireTopupReconciliationControllerProvider), isA<WireTopupReconciliationIdle>());
  });
}
