import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/features/booking/domain/entities/condition_report.dart';
import 'package:huvalts/features/booking/domain/entities/condition_report_stage.dart';

ConditionReport _report({
  DateTime? confirmedByRenterAt,
  DateTime? confirmedByOwnerAt,
}) {
  return ConditionReport(
    id: 'report-1',
    bookingId: 'booking-1',
    stage: ConditionReportStage.pickup,
    submittedBy: 'renter-1',
    photoPaths: const [],
    notes: null,
    confirmedByRenterAt: confirmedByRenterAt,
    confirmedByOwnerAt: confirmedByOwnerAt,
    createdAt: DateTime(2026, 8, 17),
  );
}

void main() {
  group('ConditionReportViewHelpers', () {
    test('isFullyConfirmed is true only once both sides confirmed', () {
      expect(_report().isFullyConfirmed, isFalse);
      expect(_report(confirmedByRenterAt: DateTime(2026, 8, 17)).isFullyConfirmed, isFalse);
      expect(
        _report(
          confirmedByRenterAt: DateTime(2026, 8, 17),
          confirmedByOwnerAt: DateTime(2026, 8, 17),
        ).isFullyConfirmed,
        isTrue,
      );
    });

    test('needsConfirmationFrom is true for the renter until they confirm', () {
      final report = _report(confirmedByOwnerAt: DateTime(2026, 8, 17));
      expect(
        report.needsConfirmationFrom(userId: 'renter-1', renterId: 'renter-1', ownerId: 'owner-1'),
        isTrue,
      );
      expect(
        report.needsConfirmationFrom(userId: 'owner-1', renterId: 'renter-1', ownerId: 'owner-1'),
        isFalse,
      );
    });

    test('needsConfirmationFrom is false for a non-participant', () {
      final report = _report();
      expect(
        report.needsConfirmationFrom(userId: 'stranger', renterId: 'renter-1', ownerId: 'owner-1'),
        isFalse,
      );
    });
  });
}
