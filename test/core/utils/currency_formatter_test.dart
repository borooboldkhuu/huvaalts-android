import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/core/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatter', () {
    test('formats whole amounts with thousands separators and ₮ suffix', () {
      expect(CurrencyFormatter.format(80000), '80,000₮');
      expect(CurrencyFormatter.format(240000), '240,000₮');
      expect(CurrencyFormatter.format(0), '0₮');
    });

    test('formatPerUnit appends the unit label', () {
      expect(CurrencyFormatter.formatPerUnit(80000, 'өдөр'), '80,000₮ / өдөр');
    });
  });
}
