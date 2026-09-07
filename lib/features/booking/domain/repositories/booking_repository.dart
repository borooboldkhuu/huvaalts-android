import '../entities/booking.dart';

abstract interface class BookingRepository {
  /// Calls the `create_booking` RPC — the *only* way a booking gets
  /// created (see `supabase/migrations/0006_booking_rpc.sql`'s header
  /// comment for why this isn't a plain table insert). Throws a
  /// [core/errors/app_exception.dart] subtype mapped from whatever the
  /// RPC raised — e.g. dates that collide with another booking or an
  /// owner blackout come back as a [ConflictException].
  Future<Booking> createBooking({
    required String assetId,
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<Booking?> getById(String bookingId);

  /// The signed-in user's bookings as the renter, newest first.
  Future<List<Booking>> getMyBookingsAsRenter();

  /// The signed-in user's bookings as the asset owner, newest first.
  Future<List<Booking>> getMyBookingsAsOwner();

  /// Date ranges already unavailable on [assetId] — from other active
  /// bookings and owner blackout ranges (`public.asset_booked_ranges`,
  /// see `supabase/migrations/0007_asset_booked_ranges.sql`). Each range
  /// is inclusive of both start and end, matching how the backend's
  /// double-booking guard treats overlap — used to steer the renter away
  /// from dates that would just get rejected, not as the final word (the
  /// RPC re-checks authoritatively at submit time regardless).
  Future<List<(DateTime start, DateTime end)>> getBlockedRanges(String assetId);

  Future<Booking> confirmBooking(String bookingId);

  Future<Booking> rejectBooking(String bookingId, {String? reason});

  Future<Booking> cancelBooking(String bookingId, {String? reason});
}
