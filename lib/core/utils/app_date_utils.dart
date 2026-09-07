import 'package:intl/intl.dart';

/// Date/time helpers. Named `AppDateUtils` (not `DateUtils`) to avoid
/// colliding with Flutter's own `material.dart` export of that name.
class AppDateUtils {
  const AppDateUtils._();

  static String formatShortDate(DateTime date) {
    // `.toLocal()` matters here: every timestamp/date this receives comes
    // from a `timestamptz`/`date` column parsed via `DateTime.parse` (UTC).
    // Without converting first, a moment within a few hours of local
    // midnight renders under the wrong calendar day for any user not on
    // UTC (Mongolia is UTC+8) — see `formatDateTime` below, which already
    // does this.
    return DateFormat('yyyy.MM.dd').format(date.toLocal());
  }

  static String formatDateRange(DateTime start, DateTime end) {
    return '${formatShortDate(start)} – ${formatShortDate(end)}';
  }

  /// Date + time, for timestamps where the time of day is actually useful
  /// (wallet transaction/payout history) rather than just a date.
  static String formatDateTime(DateTime dateTime) {
    return DateFormat('yyyy.MM.dd HH:mm').format(dateTime.toLocal());
  }

  static int wholeDaysBetween(DateTime start, DateTime end) {
    final DateTime startDay = DateTime(start.year, start.month, start.day);
    final DateTime endDay = DateTime(end.year, end.month, end.day);
    return endDay.difference(startDay).inDays;
  }
}
