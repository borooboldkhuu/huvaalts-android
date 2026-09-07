import 'package:intl/intl.dart';

/// Formats amounts as Mongolian tugrik, e.g. `80,000₮`. Amounts are always
/// handled as integer төгрөг (no fractional möngö in this product) and
/// should be computed authoritatively on the backend — this formatter is
/// display-only (spec section 34: never trust client-side price).
class CurrencyFormatter {
  const CurrencyFormatter._();

  static final NumberFormat _formatter = NumberFormat.decimalPattern('mn_MN');

  static String format(num amount) {
    return '${_formatter.format(amount)}₮';
  }

  /// `80,000₮ / өдөр` style compound label for price-per-unit displays.
  static String formatPerUnit(num amount, String unitLabel) {
    return '${format(amount)} / $unitLabel';
  }
}
