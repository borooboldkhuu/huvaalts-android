import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/features/admin/domain/entities/report_target_type.dart';

void main() {
  group('ReportTargetType.fromId', () {
    test('round-trips every known id back to its enum value', () {
      for (final type in ReportTargetType.values) {
        expect(ReportTargetType.fromId(type.id), type);
      }
    });

    test('falls back to user for an unrecognized id', () {
      expect(ReportTargetType.fromId('not_a_real_type'), ReportTargetType.user);
    });
  });
}
