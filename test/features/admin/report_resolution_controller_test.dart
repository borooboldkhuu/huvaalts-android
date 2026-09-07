import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/features/admin/domain/entities/report.dart';
import 'package:huvalts/features/admin/domain/entities/report_status.dart';
import 'package:huvalts/features/admin/domain/entities/report_target_type.dart';
import 'package:huvalts/features/admin/presentation/controllers/admin_providers.dart';
import 'package:huvalts/features/admin/presentation/controllers/report_resolution_controller.dart';

import 'fake_admin_repository.dart';

Report _report({ReportStatus status = ReportStatus.actioned}) {
  return Report(
    id: 'report-1',
    reporterId: 'user-1',
    targetType: ReportTargetType.asset,
    targetId: 'asset-1',
    reason: 'misleading photos',
    details: null,
    status: status,
    createdAt: DateTime(2026, 8, 1),
    resolvedAt: status == ReportStatus.actioned || status == ReportStatus.dismissed
        ? DateTime(2026, 8, 17)
        : null,
  );
}

void main() {
  test('resolve forwards reportId and newStatus', () async {
    final fake = FakeAdminRepository()..resolveReportResult = _report(status: ReportStatus.actioned);
    final container = ProviderContainer(overrides: [adminRepositoryProvider.overrideWithValue(fake)]);
    addTearDown(container.dispose);

    final controller = container.read(reportResolutionControllerProvider.notifier);
    final result = await controller.resolve(reportId: 'report-1', newStatus: ReportStatus.actioned);

    expect(fake.lastResolvedReportId, 'report-1');
    expect(fake.lastReportStatus, ReportStatus.actioned);
    expect(result.status, ReportStatus.actioned);
    expect(controller.state.isSubmitting, isFalse);
  });

  test('rethrows on failure (e.g. report_not_found) and resets isSubmitting', () async {
    final fake = FakeAdminRepository()..errorToThrow = Exception('report_not_found');
    final container = ProviderContainer(overrides: [adminRepositoryProvider.overrideWithValue(fake)]);
    addTearDown(container.dispose);

    final controller = container.read(reportResolutionControllerProvider.notifier);

    await expectLater(
      controller.resolve(reportId: 'report-1', newStatus: ReportStatus.dismissed),
      throwsException,
    );
    expect(controller.state.isSubmitting, isFalse);
  });
}
