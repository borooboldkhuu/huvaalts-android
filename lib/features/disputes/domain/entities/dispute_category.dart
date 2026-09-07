/// `disputes.category` is a free-form `text` column in Postgres (spec
/// section 26 doesn't pin an exact taxonomy) — this is an app-level
/// choice of a small fixed set to offer as a picker rather than a bare
/// text field, the same reasoning as `ReviewCategory`.
enum DisputeCategory {
  itemDamaged('item_damaged'),
  itemNotAsDescribed('item_not_as_described'),
  lateReturn('late_return'),
  noShow('no_show'),
  paymentIssue('payment_issue'),
  other('other');

  const DisputeCategory(this.id);

  final String id;

  static DisputeCategory fromId(String id) {
    return DisputeCategory.values.firstWhere(
      (c) => c.id == id,
      orElse: () => DisputeCategory.other,
    );
  }
}
