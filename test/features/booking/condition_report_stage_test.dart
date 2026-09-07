import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/features/booking/domain/entities/condition_report_stage.dart';

void main() {
  group('ConditionReportStage.fromId', () {
    test('round-trips every known id back to its enum value', () {
      for (final stage in ConditionReportStage.values) {
        expect(ConditionReportStage.fromId(stage.id), stage);
      }
    });

    test('falls back to pickup for an unrecognized id', () {
      expect(ConditionReportStage.fromId('not_a_real_stage'), ConditionReportStage.pickup);
    });
  });
}
