/// A client-side price *estimate* shown on the booking request screen
/// before submit. This is display-only — the authoritative numbers are
/// computed server-side inside the `create_booking` Postgres function
/// (`supabase/migrations/0006_booking_rpc.sql`), which recomputes
/// everything from the asset's current price rather than trusting
/// whatever this class calculated (spec section 34: never trust
/// client-side price). The math here is deliberately kept identical to
/// the RPC's so the estimate the renter sees matches what they're
/// actually charged in the normal case — see `create_booking`'s comments
/// if the two ever need to diverge.
class PriceBreakdown {
  const PriceBreakdown({
    required this.nights,
    required this.rentalAmount,
    required this.platformFee,
    required this.totalAmount,
  });

  final int nights;
  final double rentalAmount;
  final double platformFee;
  final double totalAmount;

  /// [pricePerDay] comes from the asset being booked; [commissionPercent]
  /// defaults to `AppConstants.defaultCommissionPercent` at call sites
  /// rather than being hardcoded here, so this class doesn't need to
  /// import `core/constants`.
  factory PriceBreakdown.estimate({
    required double pricePerDay,
    required DateTime startDate,
    required DateTime endDate,
    required double commissionPercent,
  }) {
    final int rawNights = endDate.difference(startDate).inDays;
    final int nights = rawNights < 1 ? 1 : rawNights;
    final double rentalAmount = _round2(pricePerDay * nights);
    final double platformFee = _round2(rentalAmount * commissionPercent / 100);
    final double totalAmount = rentalAmount + platformFee;
    return PriceBreakdown(
      nights: nights,
      rentalAmount: rentalAmount,
      platformFee: platformFee,
      totalAmount: totalAmount,
    );
  }

  static double _round2(double value) => (value * 100).round() / 100;
}
