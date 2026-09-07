/// Mirrors the Postgres `report_status` enum
/// (`supabase/migrations/0001_init_schema.sql`). A client can only ever
/// create one in `open` (`reports_insert_own` RLS) — every other
/// transition is `admin_resolve_report` (`0012_admin_dashboard.sql`).
enum ReportStatus {
  open('open'),
  reviewed('reviewed'),
  actioned('actioned'),
  dismissed('dismissed');

  const ReportStatus(this.id);

  final String id;

  static ReportStatus fromId(String id) {
    return ReportStatus.values.firstWhere(
      (s) => s.id == id,
      orElse: () => ReportStatus.open,
    );
  }
}
