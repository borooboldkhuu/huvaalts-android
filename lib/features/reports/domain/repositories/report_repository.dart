import '../../../admin/domain/entities/report_target_type.dart';

/// Files an abuse/content report against a listing, user, message, or
/// review (spec sections 26, 30) — reuses [ReportTargetType] straight
/// from the admin feature rather than declaring a duplicate, same
/// "reuse, don't duplicate" convention `AdminRepository` itself already
/// documents for [Dispute]/[Payout]. The backend side of this
/// (`public.reports`, `reports_insert_own` RLS, `admin_resolve_report`)
/// has existed since Phase 0/1; this repository is the first client-side
/// thing that actually calls it — see
/// `supabase/migrations/0001_init_schema.sql`'s `reports` table comment.
abstract interface class ReportRepository {
  /// Inserts a `public.reports` row on the caller's own behalf —
  /// `reporter_id` is always the signed-in user, never accepted as a
  /// parameter (RLS ties inserts to `auth.uid()` anyway; accepting it
  /// here would just invite a mismatch). Throws [UnauthorizedException]
  /// if nobody is signed in.
  Future<void> submit({
    required ReportTargetType targetType,
    required String targetId,
    required String reason,
    String? details,
  });
}
