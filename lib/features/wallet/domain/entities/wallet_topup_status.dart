/// Mirrors `public.wallet_topups.status`
/// (`supabase/migrations/0017_wire_topup_and_wallet_payments.sql`) — a
/// plain `text check (...)` column, not a Postgres enum type, since it's
/// new enough not to need `ALTER TYPE`'s cross-migration ceremony.
enum WalletTopupStatus {
  pending('pending'),
  paid('paid'),
  failed('failed'),
  cancelled('cancelled');

  const WalletTopupStatus(this.id);

  final String id;

  static WalletTopupStatus fromId(String id) {
    return WalletTopupStatus.values.firstWhere(
      (s) => s.id == id,
      orElse: () => WalletTopupStatus.pending,
    );
  }
}
