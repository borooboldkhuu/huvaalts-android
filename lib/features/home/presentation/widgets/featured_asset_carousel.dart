import 'dart:async' show unawaited;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/storage_urls.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../../../assets/domain/entities/asset_card.dart';
import '../../../assets/domain/entities/asset_search_filters.dart';
import '../../../assets/presentation/controllers/asset_providers.dart';

/// The "Танд санал болгож байна" hero — a full-width swipeable carousel of
/// `is_featured` assets (2026 reference redesign), distinct from the
/// same-titled row further down the page (`AssetHomeSection`'s
/// `recommended` sort): that section is *ordered* by featured-first but
/// still falls through to the whole catalog, while this hero shows ONLY
/// featured listings and disappears entirely when there are none — a big
/// empty/looping carousel would read as broken, not as "nothing featured
/// right now".
class FeaturedAssetCarousel extends ConsumerStatefulWidget {
  const FeaturedAssetCarousel({super.key});

  static const AssetSearchFilters _filters = AssetSearchFilters(featuredOnly: true);

  @override
  ConsumerState<FeaturedAssetCarousel> createState() => _FeaturedAssetCarouselState();
}

class _FeaturedAssetCarouselState extends ConsumerState<FeaturedAssetCarousel> {
  final PageController _controller = PageController(viewportFraction: 1);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(homeSectionProvider(FeaturedAssetCarousel._filters));

    return resultsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: SizedBox(height: 220, child: SkeletonCard()),
      ),
      error: (error, stack) => const SizedBox.shrink(),
      data: (assets) {
        if (assets.isEmpty) return const SizedBox.shrink();
        return Column(
          children: [
            SizedBox(
              height: 220,
              child: PageView.builder(
                controller: _controller,
                padEnds: false,
                itemCount: assets.length,
                onPageChanged: (index) => setState(() => _page = index),
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: _FeaturedCard(asset: assets[index]),
                ),
              ),
            ),
            if (assets.length > 1) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < assets.length; i++)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _page ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _page ? context.colors.accent : context.colors.border,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
          ],
        );
      },
    );
  }
}

class _FeaturedCard extends ConsumerWidget {
  const _FeaturedCard({required this.asset});

  final AssetCard asset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppColors colors = context.colors;
    final String? imageUrl = StorageUrls.assetImage(asset.primaryImagePath);
    final favoriteIdsAsync = ref.watch(favoriteIdsControllerProvider);
    final bool isFavorite = favoriteIdsAsync.value?.contains(asset.id) ?? false;

    return GestureDetector(
      onTap: () => context.pushNamed(RouteNames.assetDetail, pathParameters: {'id': asset.id}),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: colors.surface),
                errorWidget: (context, url, error) => Container(color: colors.surface),
              )
            else
              Container(
                color: colors.surface,
                child: Icon(Icons.inventory_2_outlined, size: 40, color: colors.secondary.withOpacity(0.4)),
              ),
            // Bottom gradient so white text stays legible over any photo,
            // matching the reference's dark-scrim hero treatment.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                  stops: [0.35, 1.0],
                ),
              ),
            ),
            Positioned(
              top: AppSpacing.md,
              left: AppSpacing.md,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                decoration: BoxDecoration(color: colors.accent, borderRadius: BorderRadius.circular(AppRadius.pill)),
                child: Text(
                  l10n.homeFeaturedBadge,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF171717),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Positioned(
              top: AppSpacing.md,
              right: AppSpacing.md,
              child: GestureDetector(
                onTap: () => unawaited(ref.read(favoriteIdsControllerProvider.notifier).toggle(asset.id)),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                  child: Icon(
                    isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    size: 18,
                    color: isFavorite ? Colors.redAccent : Colors.white,
                  ),
                ),
              ),
            ),
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.md,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    asset.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  if (asset.assetReviewCount > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, size: 15, color: Colors.white),
                        const SizedBox(width: 2),
                        Text(
                          '${asset.assetRating.toStringAsFixed(1)} (${asset.assetReviewCount})',
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  const SizedBox(height: 4),
                  Text(
                    asset.pricePerDay != null
                        ? CurrencyFormatter.formatPerUnit(asset.pricePerDay!, l10n.unitDay)
                        : (asset.displayPrice != null ? CurrencyFormatter.format(asset.displayPrice!) : ''),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                  if (asset.ownerVerificationLevel >= 1) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            asset.ownerDisplayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
