/// The fixed set of per-category star ratings a review can optionally
/// break its overall `rating` down into, stored in `reviews.category_scores`
/// (`jsonb`). Not part of the Postgres schema (that column is a free-form
/// `jsonb` map) — this is an app-level choice of which keys the UI offers,
/// kept small and fixed rather than the smarter per-category suggested
/// fields a fuller review system might have.
enum ReviewCategory {
  communication('communication'),
  accuracy('accuracy'),
  condition('condition');

  const ReviewCategory(this.key);

  final String key;
}
