import '../entities/asset_card.dart';
import '../entities/asset_detail.dart';
import '../entities/asset_search_filters.dart';
import '../entities/new_asset_input.dart';

/// One page of search/browse results plus a cursor for the next page —
/// keyset (not offset) pagination, per spec section 35 ("cursor pagination
/// where appropriate"): each page asks for rows older than the last seen
/// `created_at`, which stays correct even if new assets are published
/// while the user is scrolling (offset pagination would skip/duplicate
/// rows in that case).
class AssetPage {
  const AssetPage({required this.items, required this.nextCursor});

  final List<AssetCard> items;

  /// Pass as `cursor` to [AssetRepository.search] to fetch the next page.
  /// `null` means there are no more results.
  final DateTime? nextCursor;

  bool get hasMore => nextCursor != null;
}

abstract interface class AssetRepository {
  /// Published assets matching [filters], newest-first unless overridden
  /// by [AssetSearchFilters.sort]. [cursor] is the `createdAt` of the last
  /// item from the previous page (omit for the first page).
  Future<AssetPage> search(AssetSearchFilters filters, {DateTime? cursor, int limit = 20});

  /// Null if the asset doesn't exist, isn't published, or belongs to
  /// someone else and isn't published (RLS enforces the "published or
  /// own" rule server-side — this just surfaces "not found" for any of
  /// those cases rather than distinguishing them, to avoid leaking which
  /// case applies).
  Future<AssetCard?> getById(String assetId);

  /// Full detail (spec section 16) — same not-found semantics as [getById].
  Future<AssetDetail?> getDetailById(String assetId);

  /// Creates the asset row, uploads [images] to the `asset-images` bucket
  /// under the new asset's id, then inserts the corresponding
  /// `asset_images`/`asset_rules` rows. Not atomic across those steps —
  /// see the implementation's doc comment for what that means in
  /// practice and why it's an acceptable MVP tradeoff. Returns the new
  /// asset's id.
  Future<String> createAsset(NewAssetInput input, List<PickedAssetImage> images);

  /// The signed-in user's own assets, any status (draft/published/etc.),
  /// newest first — backs "Миний хөрөнгө" (spec section 22, minimal slice:
  /// listing only, not the full analytics dashboard that section also
  /// describes).
  Future<List<AssetCard>> getMyAssets();

  /// Bumps `assets.view_count` by one via `increment_asset_view_count`
  /// (`0018_security_and_consistency_hardening.sql`) — called once per
  /// asset-detail-screen open. Feeds Home's "Popular" sort
  /// (`AssetSortOption.mostViewed`), which had no producer for this
  /// column at all before that migration. Best-effort by design: a
  /// failure here should never block or degrade viewing the asset itself,
  /// so callers should swallow errors rather than surface them.
  Future<void> incrementViewCount(String assetId);
}
