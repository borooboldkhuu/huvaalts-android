/// Mirrors the `target_type in ('user', 'asset', 'message', 'review')`
/// check constraint on `public.reports` (`0001_init_schema.sql`) — a
/// free-form `text` column in Postgres, modeled as a fixed enum on the
/// client the same way `DisputeCategory`/`ReviewCategory` wrap their
/// respective free-form columns.
enum ReportTargetType {
  user('user'),
  asset('asset'),
  message('message'),
  review('review');

  const ReportTargetType(this.id);

  final String id;

  static ReportTargetType fromId(String id) {
    return ReportTargetType.values.firstWhere(
      (t) => t.id == id,
      orElse: () => ReportTargetType.user,
    );
  }
}
