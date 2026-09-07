import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/cards/asset_card_tile.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../../../assets/domain/entities/asset_card.dart' as domain;
import '../../../assets/domain/entities/asset_search_filters.dart';
import '../../../assets/presentation/controllers/asset_providers.dart';

/// One Home section (Nearby / Popular / Recently added / Recommended /
/// Under 50,000₮ / Verified owners / Trending — spec section 11). Renders
/// nothing at all (not even a header) when the query comes back empty, so
/// a catalog that's still thin in one category doesn't leave visible gaps
/// — this is a premium-marketplace feel choice, not an oversight
/// (contrast with `EmptyState`, which is for a screen whose *entire*
/// content is missing).
///
/// [icon]/[accentColor] give each section a distinct identity in its
/// header (a small icon-in-circle, the "icon in a colored circle" motif
/// used for e.g. [VerifiedBadge]) — with seven of these stacked on one
/// screen, that's what keeps scrolling past them from reading as one
/// undifferentiated wall of identical rows.
///
/// [mosaic] switches the one section meant to be a highlight (Trending)
/// from the usual horizontal-scroll row to a 2-column grid — a nod to the
/// 2026 "bento grid" layout trend. It's built from two independently
/// intrinsic-height `Column`s (not a fixed-`childAspectRatio` `GridView`)
/// specifically so a longer title, a rating line appearing/disappearing,
/// or a larger accessibility text size can never overflow a cell — every
/// card just takes the height it needs.
class AssetHomeSection extends ConsumerWidget {
  const AssetHomeSection({
    required this.title,
    required this.filters,
    this.icon,
    this.accentColor,
    this.mosaic = false,
    super.key,
  });

  final String title;
  final AssetSearchFilters filters;
  final IconData? icon;
  final Color? accentColor;
  final bool mosaic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final resultsAsync = ref.watch(homeSectionProvider(filters));

    return resultsAsync.when(
      loading: () => _SectionShell(
        title: title,
        icon: icon,
        accentColor: accentColor,
        child: mosaic ? const _LoadingMosaic() : const _LoadingRow(),
      ),
      error: (error, stack) => const SizedBox.shrink(),
      data: (assets) {
        if (assets.isEmpty) return const SizedBox.shrink();
        return _SectionShell(
          title: title,
          icon: icon,
          accentColor: accentColor,
          // `goNamed`, not `pushNamed` — Search is a bottom tab (AppShell),
          // so "see all" switches to it with the section's filters applied
          // instead of pushing a duplicate, nav-bar-less screen on top.
          onSeeAll: () => context.goNamed(
            RouteNames.search,
            extra: filters,
          ),
          seeAllLabel: l10n.sectionSeeAll,
          child: mosaic ? _AssetMosaic(assets: assets) : _AssetRow(assets: assets),
        );
      },
    );
  }
}

/// Card width as a fraction of screen width, and the resulting row height —
/// shared by [_AssetRow] and [_LoadingRow] so the loading skeleton never
/// jumps in size once real cards arrive. Design spec: cards should read as
/// ~70-75% of screen width (large enough that "the next one" peeks in from
/// the edge, inviting a swipe) rather than a fixed small tile — clamped so
/// they don't become absurdly wide on a tablet or overly cramped on a very
/// narrow phone.
double _cardWidth(BuildContext context) =>
    (MediaQuery.sizeOf(context).width * 0.72).clamp(200.0, 320.0);

/// [AssetCardTile]'s image is now 4:3 ([AssetCardTile]'s `AspectRatio`) —
/// this adds the roughly-constant height of the text block below the image
/// (title row, optional distance row, price) so the row's `SizedBox` is
/// tall enough for the tallest case (distance shown) without per-item
/// intrinsic sizing, which horizontal `ListView`s can't do cheaply.
double _rowHeight(BuildContext context) => _cardWidth(context) / (4 / 3) + 80;

class _AssetRow extends StatelessWidget {
  const _AssetRow({required this.assets});

  final List<domain.AssetCard> assets;

  @override
  Widget build(BuildContext context) {
    final double cardWidth = _cardWidth(context);
    return SizedBox(
      height: _rowHeight(context),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: assets.length,
        separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, index) {
          final asset = assets[index];
          return SizedBox(
            width: cardWidth,
            child: AssetCardTile(
              asset: asset,
              onTap: () => context.pushNamed(RouteNames.assetDetail, pathParameters: {'id': asset.id}),
            ),
          );
        },
      ),
    );
  }
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow();

  @override
  Widget build(BuildContext context) {
    final double cardWidth = _cardWidth(context);
    return SizedBox(
      height: _rowHeight(context),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: 3,
        separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, index) => SizedBox(width: cardWidth, child: const SkeletonCard()),
      ),
    );
  }
}

/// Up to 4 cards split into two columns (even indices left, odd right),
/// each column an ordinary intrinsic-height `Column` — see the
/// `mosaic` doc on [AssetHomeSection] for why that (and not a
/// fixed-aspect-ratio `GridView`) is the safe way to build this.
class _AssetMosaic extends StatelessWidget {
  const _AssetMosaic({required this.assets});

  final List<domain.AssetCard> assets;

  @override
  Widget build(BuildContext context) {
    final List<domain.AssetCard> shown = assets.take(4).toList();
    final List<domain.AssetCard> left = [for (int i = 0; i < shown.length; i += 2) shown[i]];
    final List<domain.AssetCard> right = [for (int i = 1; i < shown.length; i += 2) shown[i]];

    Widget column(List<domain.AssetCard> items) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            AssetCardTile(
              asset: items[i],
              onTap: () =>
                  context.pushNamed(RouteNames.assetDetail, pathParameters: {'id': items[i].id}),
            ),
          ],
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: column(left)),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: column(right)),
        ],
      ),
    );
  }
}

class _LoadingMosaic extends StatelessWidget {
  const _LoadingMosaic();

  @override
  Widget build(BuildContext context) {
    Widget column() => const Column(
          children: [
            SkeletonCard(),
            SizedBox(height: AppSpacing.md),
            SkeletonCard(),
          ],
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: column()),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: column()),
        ],
      ),
    );
  }
}

class _SectionShell extends StatelessWidget {
  const _SectionShell({
    required this.title,
    required this.child,
    this.onSeeAll,
    this.seeAllLabel,
    this.icon,
    this.accentColor,
  });

  final String title;
  final Widget child;
  final VoidCallback? onSeeAll;
  final String? seeAllLabel;
  final IconData? icon;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color badgeColor = accentColor ?? theme.colorScheme.secondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(color: badgeColor.withOpacity(0.12), shape: BoxShape.circle),
                        child: Icon(icon, size: 15, color: badgeColor),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Flexible(
                      child: Text(title, style: theme.textTheme.titleLarge, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              if (onSeeAll != null)
                TextButton(onPressed: onSeeAll, child: Text(seeAllLabel ?? '')),
            ],
          ),
        ),
        child,
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}
