/// Mirrors the Postgres `payment_status` enum (`supabase/migrations/
/// 0001_init_schema.sql`) — same rationale as `BookingStatus`: a
/// compiler-checked `switch` instead of comparing raw strings everywhere
/// status-dependent UI needs to branch.
enum PaymentStatus {
  pending('pending'),
  authorized('authorized'),
  paid('paid'),
  failed('failed'),
  cancelled('cancelled'),
  refunded('refunded'),
  partiallyRefunded('partially_refunded');

  const PaymentStatus(this.id);

  final String id;

  static PaymentStatus fromId(String id) {
    return PaymentStatus.values.firstWhere(
      (s) => s.id == id,
      orElse: () => PaymentStatus.pending,
    );
  }
}
