/// Mirrors the Postgres `dispute_status` enum
/// (`supabase/migrations/0001_init_schema.sql`). A client can only ever
/// create one in `open` (`disputes_insert_participant` RLS); every other
/// transition is an admin action (`disputes_update_admin`) — the admin
/// dashboard itself is Phase 11, so until then that only happens via
/// direct database access, not through this app's UI.
enum DisputeStatus {
  open('open'),
  underReview('under_review'),
  resolved('resolved'),
  rejected('rejected'),
  escalated('escalated');

  const DisputeStatus(this.id);

  final String id;

  bool get isActive => this == open || this == underReview || this == escalated;

  static DisputeStatus fromId(String id) {
    return DisputeStatus.values.firstWhere(
      (s) => s.id == id,
      orElse: () => DisputeStatus.open,
    );
  }
}
