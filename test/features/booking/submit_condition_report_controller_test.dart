import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/features/booking/domain/entities/condition_report.dart';
import 'package:huvalts/features/booking/domain/entities/condition_report_stage.dart';
import 'package:huvalts/features/booking/domain/repositories/condition_report_repository.dart';
import 'package:huvalts/features/booking/presentation/controllers/condition_report_providers.dart';
import 'package:huvalts/features/booking/presentation/controllers/submit_condition_report_controller.dart';

ConditionReport _report({required String submittedBy, ConditionReportStage stage = ConditionReportStage.pickup}) {
  return ConditionReport(
    id: 'report-1',
    bookingId: 'booking-1',
    stage: stage,
    submittedBy: submittedBy,
    photoPaths: const [],
    notes: null,
    confirmedByRenterAt: DateTime(2026, 8, 17),
    confirmedByOwnerAt: null,
    createdAt: DateTime(2026, 8, 17),
  );
}

class _FakeConditionReportRepository implements ConditionReportRepository {
  ({String bookingId, ConditionReportStage stage, String? notes})? lastSubmitArgs;
  String? lastConfirmedReportId;
  Object? submitError;
  Object? confirmError;

  @override
  Future<ConditionReport?> getReport(String bookingId, ConditionReportStage stage) async => null;

  @override
  Future<ConditionReport> submitReport({
    required String bookingId,
    required ConditionReportStage stage,
    required List<(Uint8List, String)> photos,
    String? notes,
  }) async {
    lastSubmitArgs = (bookingId: bookingId, stage: stage, notes: notes);
    if (submitError != null) throw submitError!;
    return _report(submittedBy: 'renter-1', stage: stage);
  }

  @override
  Future<ConditionReport> confirmReport(String reportId) async {
    lastConfirmedReportId = reportId;
    if (confirmError != null) throw confirmError!;
    return _report(submittedBy: 'renter-1').copyWith(confirmedByOwnerAt: DateTime(2026, 8, 17));
  }

  @override
  Future<String> signedPhotoUrl(String path) async => 'https://example.com/$path';
}

void main() {
  group('SubmitConditionReportController', () {
    test('submit forwards bookingId/stage/notes and returns the report', () async {
      final fake = _FakeConditionReportRepository();
      final container = ProviderContainer(
        overrides: [conditionReportRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final controller = container.read(submitConditionReportControllerProvider.notifier);
      final report = await controller.submit(
        bookingId: 'booking-1',
        stage: ConditionReportStage.return_,
        notes: 'Looks fine',
      );

      expect(report.stage, ConditionReportStage.return_);
      expect(fake.lastSubmitArgs?.bookingId, 'booking-1');
      expect(fake.lastSubmitArgs?.stage, ConditionReportStage.return_);
      expect(fake.lastSubmitArgs?.notes, 'Looks fine');
      expect(controller.state.isSubmitting, isFalse);
    });

    test('isSubmitting is true only while the call is in flight', () async {
      final fake = _FakeConditionReportRepository();
      final container = ProviderContainer(
        overrides: [conditionReportRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final controller = container.read(submitConditionReportControllerProvider.notifier);
      expect(controller.state.isSubmitting, isFalse);

      final future = controller.submit(bookingId: 'booking-1', stage: ConditionReportStage.pickup);
      expect(controller.state.isSubmitting, isTrue);

      await future;
      expect(controller.state.isSubmitting, isFalse);
    });

    test('rethrows on failure and still resets isSubmitting', () async {
      final fake = _FakeConditionReportRepository()..submitError = Exception('payment_required_before_pickup');
      final container = ProviderContainer(
        overrides: [conditionReportRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final controller = container.read(submitConditionReportControllerProvider.notifier);

      await expectLater(
        controller.submit(bookingId: 'booking-1', stage: ConditionReportStage.pickup),
        throwsException,
      );
      expect(controller.state.isSubmitting, isFalse);
    });
  });

  group('ConfirmConditionReportController', () {
    test('confirm forwards the report id and returns the updated report', () async {
      final fake = _FakeConditionReportRepository();
      final container = ProviderContainer(
        overrides: [conditionReportRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final controller = container.read(confirmConditionReportControllerProvider.notifier);
      final report = await controller.confirm('report-1');

      expect(fake.lastConfirmedReportId, 'report-1');
      expect(report.confirmedByOwnerAt, isNotNull);
      expect(controller.state.isSubmitting, isFalse);
    });

    test('rethrows on failure and still resets isSubmitting', () async {
      final fake = _FakeConditionReportRepository()..confirmError = Exception('not_authorized');
      final container = ProviderContainer(
        overrides: [conditionReportRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final controller = container.read(confirmConditionReportControllerProvider.notifier);

      await expectLater(controller.confirm('report-1'), throwsException);
      expect(controller.state.isSubmitting, isFalse);
    });
  });
}
