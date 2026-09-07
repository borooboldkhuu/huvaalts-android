/// Mirrors the Postgres `asset_status` enum
/// (`supabase/migrations/0001_init_schema.sql`). Lives in `features/assets`
/// (not `features/admin`, even though most *transitions* between these
/// are admin-only) because [AssetCard] itself now carries a `status` field
/// (Phase 11) — an owner viewing "My Assets" needs to know their listing
/// is `pendingReview`/`suspended`, not just admins reviewing a queue.
///
/// Every transition between these is enforced server-side by the
/// `enforce_asset_status_transition` trigger
/// (`supabase/migrations/0012_admin_dashboard.sql`) — a client can no
/// longer set an asset straight to `published` by updating the column
/// directly; new assets are forced to `pendingReview` on insert
/// regardless of what the client sends, and every other change is either
/// an admin action (`admin_approve_asset`/`admin_reject_asset`/
/// `admin_suspend_asset`) or the one owner self-service case
/// (`resubmit_asset_for_review`, from `draft` back to `pendingReview`
/// after a rejection).
enum AssetStatus {
  draft('draft'),
  pendingReview('pending_review'),
  published('published'),
  suspended('suspended'),
  archived('archived');

  const AssetStatus(this.id);

  final String id;

  static AssetStatus fromId(String id) {
    return AssetStatus.values.firstWhere(
      (s) => s.id == id,
      orElse: () => AssetStatus.draft,
    );
  }
}
