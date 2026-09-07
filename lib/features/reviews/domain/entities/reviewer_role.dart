/// Mirrors `reviews.role`'s `check (role in ('owner', 'renter'))` constraint
/// (`supabase/migrations/0001_init_schema.sql`) — the role of the
/// *reviewer* in the booking being reviewed, not the reviewee's.
enum ReviewerRole {
  owner('owner'),
  renter('renter');

  const ReviewerRole(this.id);

  final String id;

  static ReviewerRole fromId(String id) {
    return ReviewerRole.values.firstWhere(
      (r) => r.id == id,
      orElse: () => ReviewerRole.renter,
    );
  }
}
