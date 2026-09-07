import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/repositories/supabase_asset_repository.dart';
import '../../data/repositories/supabase_favorites_repository.dart';
import '../../domain/entities/asset_card.dart';
import '../../domain/entities/asset_detail.dart';
import '../../domain/entities/asset_search_filters.dart';
import '../../domain/repositories/asset_repository.dart';
import '../../domain/repositories/favorites_repository.dart';

final Provider<AssetRepository> assetRepositoryProvider = Provider<AssetRepository>((ref) {
  return SupabaseAssetRepository(ref.watch(supabaseClientProvider));
});

final Provider<FavoritesRepository> favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  return SupabaseFavoritesRepository(ref.watch(supabaseClientProvider));
});

/// One-shot fetch of a single-page result set for a given filter set — this
/// is what backs each Home section (spec section 11): each section is just
/// a different [AssetSearchFilters] value, so they share this one
/// provider family instead of one bespoke provider per section.
final homeSectionProvider =
    FutureProvider.family<List<AssetCard>, AssetSearchFilters>((ref, filters) async {
  final page = await ref.watch(assetRepositoryProvider).search(filters, limit: 12);
  return page.items;
});

final assetByIdProvider =
    FutureProvider.family<AssetCard?, String>((ref, assetId) {
  return ref.watch(assetRepositoryProvider).getById(assetId);
});

/// Full detail (spec section 16) — what [AssetDetailScreen] renders. Kept
/// as its own provider (rather than reusing [assetByIdProvider]) since it
/// fetches a materially different, heavier shape via a different
/// repository method — see [AssetRepository.getDetailById].
final assetDetailByIdProvider =
    FutureProvider.family<AssetDetail?, String>((ref, assetId) {
  return ref.watch(assetRepositoryProvider).getDetailById(assetId);
});

/// Fires `incrementViewCount` once per asset-detail-screen open — watched
/// (not read) from `AssetDetailScreen.build`, which relies on
/// `autoDispose` + Riverpod's memoization to run the increment exactly
/// once per navigation to a given asset rather than on every rebuild (the
/// family cache key is `assetId`; the provider is disposed and can fire
/// again next time the screen is reopened, which is the desired "count a
/// view" semantics). The `void` result is intentionally never read.
final assetViewTrackerProvider = FutureProvider.autoDispose.family<void, String>((ref, assetId) {
  return ref.watch(assetRepositoryProvider).incrementViewCount(assetId);
});

/// The signed-in user's own assets (spec section 22's minimal listing
/// slice) — backs "Миний хөрөнгө" in Profile.
final FutureProvider<List<AssetCard>> myAssetsProvider = FutureProvider<List<AssetCard>>((ref) {
  return ref.watch(assetRepositoryProvider).getMyAssets();
});

/// The signed-in user's favorited asset ids, held as a single in-memory
/// set so every [AssetCard] on screen can check membership synchronously
/// instead of firing its own query, and so toggling one favorite can
/// update optimistically (spec section 35/36 — instant heart-icon
/// feedback) with a clean revert path if the backend call fails (spec
/// section 43: never leave the UI claiming a state the server disagrees
/// with).
class FavoriteIdsController extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() {
    return ref.watch(favoritesRepositoryProvider).favoriteAssetIds();
  }

  Future<void> toggle(String assetId) async {
    final Set<String> current = state.value ?? <String>{};
    final bool wasFavorite = current.contains(assetId);

    final Set<String> optimistic = Set<String>.of(current);
    if (wasFavorite) {
      optimistic.remove(assetId);
    } else {
      optimistic.add(assetId);
    }
    state = AsyncData(optimistic);

    final FavoritesRepository repo = ref.read(favoritesRepositoryProvider);
    try {
      if (wasFavorite) {
        await repo.remove(assetId);
      } else {
        await repo.add(assetId);
      }
    } catch (_) {
      state = AsyncData(current); // revert — the backend didn't confirm it.
      rethrow;
    }
  }
}

final AsyncNotifierProvider<FavoriteIdsController, Set<String>> favoriteIdsControllerProvider =
    AsyncNotifierProvider<FavoriteIdsController, Set<String>>(FavoriteIdsController.new);
