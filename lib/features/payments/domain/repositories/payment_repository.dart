import '../entities/payment.dart';

/// Booking payments are wallet-balance-based end to end (see
/// `payFromWallet` below) — this interface used to also expose
/// `initiatePayment`/`completeMockPayment` for the old mock-gateway flow
/// (`initiate-payment`/`mock-complete-payment` Edge Functions), removed
/// once `pay_booking_from_wallet` shipped in
/// `supabase/migrations/0017_wire_topup_and_wallet_payments.sql`. Those
/// two Edge Functions are now permanently disabled server-side (see their
/// own header comments) — they were a live free-money exploit once the
/// wallet flow superseded them (a renter could mark their own booking
/// "paid" and credit the owner's wallet without ever debiting their own).
/// Removed here too so nothing in the client can be wired back to them by
/// mistake.
abstract interface class PaymentRepository {
  /// The most recent payment for [bookingId], or null if none exists yet.
  /// A plain read against `public.payments` — allowed by
  /// `payments_select_participant` RLS (payer or the booking's owner can
  /// read it), no Edge Function needed.
  Future<Payment?> getForBooking(String bookingId);

  /// Pays a `confirmed` booking directly out of the renter's own
  /// `wallets.available_balance`, via the `pay_booking_from_wallet` RPC —
  /// the only way a booking gets paid now (booking payments are
  /// wallet-balance-based end to end; see that function's header comment
  /// in `supabase/migrations/0017_wire_topup_and_wallet_payments.sql`).
  /// Settles synchronously — no external gateway round trip, no separate
  /// "complete" step. Idempotent server-side: reuses the existing paid
  /// payment for this booking if one already exists rather than double-
  /// charging on a retry. Throws a
  /// [ConflictException] (message `insufficient_balance`) when the
  /// wallet doesn't have enough — callers should catch that specifically
  /// and offer a top-up instead of a generic error.
  Future<Payment> payFromWallet(String bookingId);
}
