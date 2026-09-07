import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/features/chat/domain/entities/message_kind.dart';

void main() {
  group('MessageKind.fromId', () {
    test('round-trips every known id back to its enum value', () {
      for (final kind in MessageKind.values) {
        expect(MessageKind.fromId(kind.id), kind);
      }
    });

    test('falls back to text for an unrecognized id', () {
      expect(MessageKind.fromId('not_a_real_kind'), MessageKind.text);
    });
  });
}
