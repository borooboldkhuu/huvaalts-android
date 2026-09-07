/// Pure date-range overlap helpers shared by the booking request screen's
/// client-side pre-check and its tests. This is a UX convenience only —
/// the authoritative check is the `create_booking` Postgres function
/// (`supabase/migrations/0006_booking_rpc.sql`), which re-validates
/// against the real, current state of the database regardless of what
/// this returns (spec section 34: never trust a client-side availability
/// computation).
class DateRangeUtils {
  const DateRangeUtils._();

  /// Both `blocked` and the requested `[start, end]` are treated as
  /// inclusive of both endpoints — matching the semantics of the
  /// `bookings_no_overlap` exclusion constraint and `asset_availability`
  /// blackout ranges server-side, so a range this reports as "free" is
  /// exactly the set the backend would also accept as non-overlapping.
  static bool overlapsAny(
    DateTime start,
    DateTime end,
    List<(DateTime start, DateTime end)> blocked,
  ) {
    for (final (DateTime bStart, DateTime bEnd) in blocked) {
      if (_overlaps(start, end, bStart, bEnd)) return true;
    }
    return false;
  }

  static bool _overlaps(DateTime aStart, DateTime aEnd, DateTime bStart, DateTime bEnd) {
    final DateTime aS = _dateOnly(aStart);
    final DateTime aE = _dateOnly(aEnd);
    final DateTime bS = _dateOnly(bStart);
    final DateTime bE = _dateOnly(bEnd);
    return !aE.isBefore(bS) && !bE.isBefore(aS);
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
