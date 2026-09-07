/// Mirrors the Postgres `booking_status` enum (`supabase/migrations/
/// 0001_init_schema.sql`) — kept as a client-side enum (not a raw string)
/// so status-dependent UI (which actions are available, which color a
/// chip gets) is a compiler-checked `switch`, the same pattern
/// `AssetCategory` uses for `categories.id`.
enum BookingStatus {
  pending('pending'),
  confirmed('confirmed'),
  rejected('rejected'),
  cancelled('cancelled'),
  active('active'),
  completed('completed'),
  disputed('disputed');

  const BookingStatus(this.id);

  final String id;

  static BookingStatus fromId(String id) {
    return BookingStatus.values.firstWhere(
      (s) => s.id == id,
      orElse: () => BookingStatus.pending,
    );
  }
}
