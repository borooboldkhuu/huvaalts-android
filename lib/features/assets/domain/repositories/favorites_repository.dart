/// Favorites are a simple per-user bookmark on an asset (spec sections 11,
/// 27's "Favorite animation" reference, `public.favorites` table). Kept as
/// its own tiny repository rather than folded into [AssetRepository] since
/// it's a different access pattern (per-user membership, not a browse
/// query) with its own RLS shape.
abstract interface class FavoritesRepository {
  Future<bool> isFavorite(String assetId);

  Future<void> add(String assetId);

  Future<void> remove(String assetId);

  Future<Set<String>> favoriteAssetIds();
}
