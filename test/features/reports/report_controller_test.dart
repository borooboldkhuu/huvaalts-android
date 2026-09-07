import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/core/errors/app_exception.dart';
import 'package:huvalts/features/admin/domain/entities/report_target_type.dart';
import 'package:huvalts/features/reports/domain/repositories/report_repository.dart';
import 'package:huvalts/features/reports/presentation/controllers/report_controller.dart';

class _FakeReportRepository implements ReportRepository {
  ReportTargetType? lastTargetType;
  String? lastTargetId;
  String? lastReason;
  String? lastDetails;
  int submitCallCount = 0;
  Object? errorToThrow;

  @override
  Future<void> submit({
    required ReportTargetType targetType,
    required String targetId,
    required String reason,
    String? details,
  }) async {
    submitCallCount++;
    lastTargetType = targetType;
    lastTargetId = targetId;
    lastReason = reason;
    lastDetails = details;
    if (errorToThrow != null) throw errorToThrow!;
  }
}

void main() {
  ProviderContainer buildContainer(ReportRepository fake) {
    final container = ProviderContainer(
      overrides: [reportRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('submit() forwards exact fields to the repository', () async {
    final fake = _FakeReportRepository();
    final container = buildContainer(fake);
    final controller = container.read(reportControllerProvider.notifier);

    await controller.submit(
      targetType: ReportTargetType.asset,
      targetId: 'asset-1',
      reason: 'Fraud',
      details: 'looked fake',
    );

    expect(fake.submitCallCount, 1);
    expect(fake.lastTargetType, ReportTargetType.asset);
    expect(fake.lastTargetId, 'asset-1');
    expect(fake.lastReason, 'Fraud');
    expect(fake.lastDetails, 'looked fake');
  });

  test('submit() forwards null details unchanged', () async {
    final fake = _FakeReportRepository();
    final container = buildContainer(fake);
    final controller = container.read(reportControllerProvider.notifier);

    await controller.submit(
      targetType: ReportTargetType.user,
      targetId: 'user-1',
      reason: 'Harassment',
    );

    expect(fake.lastDetails, isNull);
  });

  test('isSubmitting is true only while the repository call is in flight', () async {
    final fake = _FakeReportRepository();
    final container = buildContainer(fake);
    final controller = container.read(reportControllerProvider.notifier);

    expect(container.read(reportControllerProvider).isSubmitting, isFalse);
    final future = controller.submit(
      targetType: ReportTargetType.message,
      targetId: 'msg-1',
      reason: 'Other',
    );
    expect(container.read(reportControllerProvider).isSubmitting, isTrue);
    await future;
    expect(container.read(reportControllerProvider).isSubmitting, isFalse);
  });

  test('a repository failure still resets isSubmitting to false and rethrows', () async {
    final fake = _FakeReportRepository()..errorToThrow = const UnknownException(message: 'boom');
    final container = buildContainer(fake);
    final controller = container.read(reportControllerProvider.notifier);

    await expectLater(
      controller.submit(targetType: ReportTargetType.review, targetId: 'review-1', reason: 'Other'),
      throwsA(isA<UnknownException>()),
    );

    expect(container.read(reportControllerProvider).isSubmitting, isFalse);
  });
}
