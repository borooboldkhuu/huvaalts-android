/// Mirrors the Postgres `condition_report_stage` enum
/// (`supabase/migrations/0001_init_schema.sql`). A booking gets at most
/// one report per stage — `condition_reports_booking_stage_unique`
/// (`0010_condition_reports_reviews_disputes.sql`) enforces that
/// server-side.
enum ConditionReportStage {
  pickup('pickup'),
  return_('return');

  const ConditionReportStage(this.id);

  final String id;

  static ConditionReportStage fromId(String id) {
    return ConditionReportStage.values.firstWhere(
      (s) => s.id == id,
      orElse: () => ConditionReportStage.pickup,
    );
  }
}
