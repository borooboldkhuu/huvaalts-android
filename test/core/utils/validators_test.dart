import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/core/utils/validators.dart';

void main() {
  group('Validators.isValidMongolianPhone', () {
    test('accepts local 8-digit numbers starting 5-9', () {
      expect(Validators.isValidMongolianPhone('99112233'), isTrue);
      expect(Validators.isValidMongolianPhone('88112233'), isTrue);
      expect(Validators.isValidMongolianPhone('55112233'), isTrue);
    });

    test('accepts numbers with +976 prefix and spaces', () {
      expect(Validators.isValidMongolianPhone('+976 99112233'), isTrue);
      expect(Validators.isValidMongolianPhone('+97699112233'), isTrue);
    });

    test('rejects numbers starting 0-4, wrong length, or non-numeric', () {
      expect(Validators.isValidMongolianPhone('12345678'), isFalse);
      expect(Validators.isValidMongolianPhone('9911223'), isFalse);
      expect(Validators.isValidMongolianPhone('abcdefgh'), isFalse);
      expect(Validators.isValidMongolianPhone(''), isFalse);
    });
  });

  group('Validators.normalizePhone', () {
    test('adds +976 prefix when missing', () {
      expect(Validators.normalizePhone('99112233'), '+97699112233');
    });

    test('leaves an already-prefixed number unchanged', () {
      expect(Validators.normalizePhone('+97699112233'), '+97699112233');
    });
  });

  group('Validators.isValidOtp', () {
    test('accepts exactly 6 digits by default', () {
      expect(Validators.isValidOtp('123456'), isTrue);
    });

    test('rejects wrong length or non-numeric', () {
      expect(Validators.isValidOtp('12345'), isFalse);
      expect(Validators.isValidOtp('12345a'), isFalse);
    });
  });
}
