import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failure.dart';
import '../../../../shared/cards/asset_card_tile.dart';
import '../../../../shared/widgets/category_chip_row.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../../../../core/constants/asset_categories.dart';
import '../../../assets/domain/entities/asset_search_filters.dart';
import '../../../map/presentation/widgets/asset_map_view.dart';
import '../controllers/search_controller.dart';
import '../widgets/search_filter_sheet.dart';

/// Search (spec section 12): debounced free-text search over
/// `public.asset_cards`, category/price/verified/sort filters via
/// [showSearchFilterSheet], and a 2-column results grid with cursor-based
/// "load more" — see [SearchAssetsController] for why full-text search is
/// currently a simple `ILIKE` rather than a ranked search index, and why
/// pagination only fully applies to the newest/recommended sorts.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({this.initialFilters, super.key});

  final AssetSearchFilters? initialFilters;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _queryController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isMapView = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(searchControllerProvider.notifier).initialize(widget.initialFilters);
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Search is now the Хайх bottom tab (AppShell), so this screen's State
    // stays alive across visits instead of being recreated per push —
    // `initState` alone would miss a second category-chip tap on Home
    // that navigates here again with new filters. Re-apply whenever a
    // non-null filter set actually changed.
    if (widget.initialFilters != null && widget.initialFilters != oldWidget.initialFilters) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(searchControllerProvider.notifier).initialize(widget.initialFilters);
      });
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      ref.read(searchControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final SearchState state = ref.watch(searchControllerProvider);
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.searchTitle),
        actions: [
          IconButton(
            icon: Icon(_isMapView ? Icons.view_list_outlined : Icons.map_outlined),
            tooltip: _isMapView ? l10n.searchShowListAction : l10n.searchShowMapAction,
            onPressed: () => setState(() => _isMapView = !_isMapView),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  // Same 56px/18px/soft-shadow treatment as Home's search
                  // entry (design spec) — a real `TextField` here (Home's
                  // version is just a button into this screen), so the
                  // themed border/fill is switched off in favor of this
                  // container's own decoration instead of layering two.
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: theme.dividerColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _queryController,
                      autofocus: widget.initialFilters == null,
                      decoration: InputDecoration(
                        hintText: l10n.searchHint,
                        prefixIcon: const Icon(Icons.search),
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      ),
                      onChanged: (value) => ref.read(searchControllerProvider.notifier).setQuery(value),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton.filledTonal(
                  icon: const Icon(Icons.tune_rounded),
                  tooltip: l10n.searchFilters,
                  onPressed: () async {
                    final result = await showSearchFilterSheet(context, current: state.filters);
                    if (result != null) {
                      ref.read(searchControllerProvider.notifier).applyFilters(result);
                    }
                  },
                ),
              ],
            ),
          ),
          CategoryChipRow(
            selected:
                state.filters.categoryId == null ? null : AssetCategory.fromId(state.filters.categoryId!),
            onSelected: (category) => ref.read(searchControllerProvider.notifier).applyFilters(
              state.filters.copyWith(categoryId: category?.id, clearCategory: category == null),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: state.results.when(
              loading: () => const _ResultsSkeleton(),
              error: (error, stack) => ErrorStateView(
                failure: error is Failure ? error : Failure.from(error),
                onRetry: () => ref.read(searchControllerProvider.notifier).retry(),
              ),
              data: (assets) {
                if (assets.isEmpty) {
                  return EmptyState(title: l10n.emptyAssetsTitle, icon: Icons.search_off);
                }
                if (_isMapView) {
                  return AssetMapView(
                    assets: assets,
                    onAssetTap: (id) => context.pushNamed(
                      RouteNames.assetDetail,
                      pathParameters: {'id': id},
                    ),
                  );
                }
                return GridView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.xxl,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: AppSpacing.lg,
                    crossAxisSpacing: AppSpacing.md,
                    // Was 0.68, tuned for AssetCardTile's old ~1.15
                    // (near-square) image crop — recomputed for the design
                    // spec's wider 4:3 crop, which leaves less vertical
                    // space per card, so the grid cell should be shorter
                    // too or cards leave blank space at the bottom.
                    childAspectRatio: 0.74,
                  ),
                  itemCount: assets.length + (state.hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= assets.length) {
                      return const Center(child: Padding(
                        padding: EdgeInsets.all(AppSpacing.md),
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ));
                    }
                    final asset = assets[index];
                    return AssetCardTile(
                      asset: asset,
                      onTap: () => context.pushNamed(
                        RouteNames.assetDetail,
                        pathParameters: {'id': asset.id},
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultsSkeleton extends StatelessWidget {
  const _ResultsSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.lg,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.74,
      ),
      itemCount: 6,
      itemBuilder: (context, index) => const SkeletonCard(),
    );
  }
}
