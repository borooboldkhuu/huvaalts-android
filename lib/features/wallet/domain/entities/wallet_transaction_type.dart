/// Mirrors the Postgres `wallet_transaction_type` enum
/// (`supabase/migrations/0001_init_schema.sql`). `amount` on
/// [WalletTransaction] is signed — this only classifies *why* a
/// transaction happened, not its sign.
enum WalletTransactionType {
  bookingIncome('booking_income'),
  platformFee('platform_fee'),
  refund('refund'),
  payout('payout'),
  // Added by `0016_wallet_enum_values.sql` for wallet-based top-ups/
  // booking payments (see that migration's header comment).
  walletTopup('wallet_topup'),
  bookingPayment('booking_payment'),
  // Note: the Postgres `wallet_transaction_type` enum
  // (`0001_init_schema.sql`) still declares `'deposit_release'` — vanilla
  // Postgres has no `ALTER TYPE ... DROP VALUE`, so removing it there
  // would require recreating the whole enum type. It was already dead
  // (nothing ever inserted it; the real pending->available wallet release
  // in `advance_booking_on_condition_report` uses `'adjustment'`), so it's
  // left in place on the Postgres side but dropped here since this Dart
  // case has no real producer.
  adjustment('adjustment');

  const WalletTransactionType(this.id);

  final String id;

  static WalletTransactionType fromId(String id) {
    return WalletTransactionType.values.firstWhere(
      (t) => t.id == id,
      orElse: () => WalletTransactionType.adjustment,
    );
  }
}
