/// Top-level rental categories shown on Home / category filters
/// (spec section 11). Kept as a plain enum with a stable [id] used as the
/// database value — display labels are localized separately, never derived
/// from the enum name.
///
/// Expanded 2026-08 from the original 9-category set to a fuller 16 (per
/// the user's own list) — `space` (Талбай) was dropped since it wasn't in
/// that list; every other original id was kept so any asset already using
/// one never needs a data migration. Every id here must also exist as a
/// row in `public.categories` (`supabase/migrations/0003_seed_categories.sql`
/// + `0022_expand_categories.sql`) — `assets.category_id` is a foreign key
/// into that table, so a client-side id with no matching DB row makes
/// asset creation fail with a foreign-key violation.
enum AssetCategory {
  all('all'),
  camera('camera'),
  drone('drone'),
  electronics('electronics'),
  gaming('gaming'),
  audio('audio'),
  projector('projector'),
  event('event'),
  tools('tools'),
  travel('travel'),
  sports('sports'),
  vehicle('vehicle'),
  household('household'),
  office('office'),
  kids('kids'),
  fashion('fashion'),
  construction('construction'),
  other('other');

  const AssetCategory(this.id);

  final String id;

  static AssetCategory fromId(String id) {
    return AssetCategory.values.firstWhere(
      (c) => c.id == id,
      orElse: () => AssetCategory.other,
    );
  }
}
