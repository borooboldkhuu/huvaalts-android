import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../assets/domain/entities/asset_card.dart';
import '../../../assets/domain/entities/asset_search_filters.dart';
import '../../../assets/presentation/controllers/asset_providers.dart';

class SearchState {
  const SearchState({
    required this.filters,
    required this.results,
    this.isLoadingMore = false,
    this.cursor,
    this.hasMore = false,
  });

  final AssetSearchFilters filters;
  final AsyncValue<List<AssetCard>> results;
  final bool isLoadingMore;
  final DateTime? cursor;
  final bool hasMore;

  SearchState copyWith({
    AssetSearchFilters? filters,
    AsyncValue<List<AssetCard>>? results,
    bool? isLoadingMore,
    DateTime? cursor,
    bool clearCursor = false,
    bool? hasMore,
  }) {
    return SearchState(
      filters: filters ?? this.filters,
      results: results ?? this.results,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      cursor: clearCursor ? null : (cursor ?? this.cursor),
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// Drives the Search screen (spec section 12): debounced free-text query,
/// category/price/verified/sort filters, and cursor-paginated results.
/// Text input is debounced 400ms so every keystroke doesn't fire a query
/// (spec section 12: "Search should debounce input", section 35: "avoid
/// unnecessary API requests").
class SearchAssetsController extends Notifier<SearchState> {
  Timer? _debounce;

  @override
  SearchState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const SearchState(filters: AssetSearchFilters(), results: AsyncValue.loading());
  }

  /// Called once when the screen opens, optionally pre-seeded with filters
  /// (e.g. tapping a category chip or a Home section's "See all").
  void initialize([AssetSearchFilters? initialFilters]) {
    state = state.copyWith(filters: initialFilters ?? state.filters);
    unawaited(_runSearch());
  }

  void setQuery(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      state = state.copyWith(
        filters: state.filters.copyWith(query: query, clearQuery: query.trim().isEmpty),
      );
      unawaited(_runSearch());
    });
  }

  void applyFilters(AssetSearchFilters newFilters) {
    state = state.copyWith(filters: newFilters);
    unawaited(_runSearch());
  }

  Future<void> retry() => _runSearch();

  Future<void> _runSearch() async {
    state = state.copyWith(results: const AsyncValue.loading(), clearCursor: true, hasMore: false);
    try {
      final page = await ref.read(assetRepositoryProvider).search(state.filters);
      state = state.copyWith(
        results: AsyncValue.data(page.items),
        cursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        hasMore: page.hasMore,
      );
    } catch (e, st) {
      state = state.copyWith(results: AsyncValue.error(Failure.from(e), st));
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await ref.read(assetRepositoryProvider).search(
            state.filters,
            cursor: state.cursor,
          );
      final List<AssetCard> current = state.results.value ?? const [];
      state = state.copyWith(
        results: AsyncValue.data([...current, ...page.items]),
        cursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        hasMore: page.hasMore,
        isLoadingMore: false,
      );
    } catch (_) {
      // Load-more failures are non-fatal — keep the results already shown
      // and just stop paginating rather than replacing a working screen
      // with an error (spec section 43's per-screen error handling is for
      // the *initial* load; a failed "load more" degrades quietly).
      state = state.copyWith(isLoadingMore: false);
    }
  }
}

final NotifierProvider<SearchAssetsController, SearchState> searchControllerProvider =
    NotifierProvider<SearchAssetsController, SearchState>(SearchAssetsController.new);
