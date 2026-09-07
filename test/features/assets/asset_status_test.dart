import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/features/assets/domain/entities/asset_status.dart';

void main() {
  group('AssetStatus.fromId', () {
    test('round-trips every known id back to its enum value', () {
      for (final status in AssetStatus.values) {
        expect(AssetStatus.fromId(status.id), status);
      }
    });

    test('falls back to draft for an unrecognized id', () {
      expect(AssetStatus.fromId('not_a_real_status'), AssetStatus.draft);
    });
  });
}
