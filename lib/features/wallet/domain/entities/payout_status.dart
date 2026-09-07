/// Mirrors the Postgres `payout_status` enum
/// (`supabase/migrations/0001_init_schema.sql`). A client can only ever
/// create a payout in `pending` (see `payouts_insert_own` RLS policy) —
/// moving it to `processing`/`paid`/`failed` is a backend/admin action
/// (Phase 11), not implemented yet.
enum PayoutStatus {
  pending('pending'),
  processing('processing'),
  paid('paid'),
  failed('failed');

  const PayoutStatus(this.id);

  final String id;

  static PayoutStatus fromId(String id) {
    return PayoutStatus.values.firstWhere(
      (s) => s.id == id,
      orElse: () => PayoutStatus.pending,
    );
  }
}
