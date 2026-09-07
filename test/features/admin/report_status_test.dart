import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/features/admin/domain/entities/report_status.dart';

void main() {
  group('ReportStatus.fromId', () {
    test('round-trips every known id back to its enum value', () {
      for (final status in ReportStatus.values) {
        expect(ReportStatus.fromId(status.id), status);
      }
    });

    test('falls back to open for an unrecognized id', () {
      expect(ReportStatus.fromId('not_a_real_status'), ReportStatus.open);
    });
  });
}
