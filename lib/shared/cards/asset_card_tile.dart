import 'dart:async' show unawaited;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/app_localizations.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/geo_utils.dart';
import '../../core/utils/storage_urls.dart';
import '../../features/assets/domain/entities/asset_card.dart' as domain;
import '../../features/assets/domain/entities/asset_status.dart';
import '../../features/assets/presentation/controllers/asset_providers.dart';
import '../../features/assets/presentation/widgets/asset_status_label.dart';
import '../../features/home/presentation/controllers/nearby_location_provider.dart';
import '../widgets/verified_badge.dart';

/// The single visual unit browse/search surfaces are built from (spec
/// sections 5, 11, 12): image, favorite toggle, title, rating, price. Named
/// `AssetCardTile` (not `AssetCard`) to avoid colliding with the domain
/// entity of the same short name — imported here under the `domain.`
/// prefix specifically to keep that distinction obvious at every use site.
class AssetCardTile extends ConsumerWidget {
  const AssetCardTile({required this.asset, this.onTap, super.key});

  final domain.AssetCard asset;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? imageUrl = StorageUrls.assetImage(asset.primaryImagePath);
    final favoriteIdsAsync = ref.watch(favoriteIdsControllerProvider);
    final bool isFavorite = favoriteIdsAsync.value?.contains(asset.id) ?? false;

    // Distance text (2026 redesign — reference design shows "· 1.2 км"
    // next to the rating). Computed client-side from the same best-effort
    // device fix Home's Nearby section already uses (`GeoUtils.distanceKm`,
    // `nearbyLocationProvider` — see their doc comments); `null` whenever
    // either coordinate is unavailable (no device fix yet, or this asset
    // has no location on file), in which case the line below is simply
    // omitted rather than showing a misleading "0.0 км".
    final (double, double)? userLocation = ref.watch(nearbyLocationProvider).value;
    final double? distanceKm = (userLocation != null && asset.latitude != null && asset.longitude != null)
        ? GeoUtils.distanceKm(userLocation.$1, userLocation.$2, asset.latitude!, asset.longitude!)
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            // 4:3 per the design spec (was 1.15/near-square) — a wider,
            // more editorial photo crop.
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl != null)
                    CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: theme.colorScheme.surface),
                      errorWidget: (context, url, error) => _imageFallback(theme),
                    )
                  else
                    _imageFallback(theme),
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: _FavoriteButton(
                      isFavorite: isFavorite,
                      onTap: () => unawaited(
                        ref.read(favoriteIdsControllerProvider.notifier).toggle(asset.id),
                      ),
                    ),
                  ),
                  // Reference design's "white circle, star, bold number"
                  // rating badge floating on the image — bottom-left so it
                  // never collides with the favorite button (top-right) or
                  // the status pill (top-left, `MyAssetsScreen` only).
                  if (asset.assetReviewCount > 0)
                    Positioned(
                      bottom: AppSpacing.sm,
                      left: AppSpacing.sm,
                      child: _RatingBadge(rating: asset.assetRating),
                    ),
                  // Every public browse/search query filters
                  // `.eq('status', 'published')`, so this only ever
                  // renders on `MyAssetsScreen`'s unfiltered-by-status
                  // query — an owner seeing their own pending/rejected/
                  // suspended listing, never a stray badge on the public
                  // feed (spec section 22, Phase 11).
                  if (asset.status != AssetStatus.published)
                    Positioned(
                      top: AppSpacing.sm,
                      left: AppSpacing.sm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: assetStatusColor(asset.status, context.colors),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          assetStatusLabel(asset.status, l10n),
                          style: theme.textTheme.labelSmall?.copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  asset.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (asset.ownerVerificationLevel >= 1) ...[
                const SizedBox(width: 4),
                VerifiedBadge(level: asset.ownerVerificationLevel, compact: true),
              ],
            ],
          ),
          if (distanceKm != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.place_rounded, size: 12, color: theme.colorScheme.secondary),
                const SizedBox(width: 2),
                Text(
                  l10n.homeDistanceKm(distanceKm.toStringAsFixed(1)),
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.secondary),
                ),
              ],
            ),
          ],
          const SizedBox(height: 2),
          Text(_priceLabel(l10n), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _priceLabel(AppLocalizations l10n) {
    if (asset.pricePerDay != null) {
      return CurrencyFormatter.formatPerUnit(asset.pricePerDay!, l10n.unitDay);
    }
    if (asset.pricePerHour != null) {
      return CurrencyFormatter.formatPerUnit(asset.pricePerHour!, l10n.unitHour);
    }
    if (asset.pricePerWeek != null) {
      return CurrencyFormatter.formatPerUnit(asset.pricePerWeek!, l10n.unitWeek);
    }
    return '';
  }

  Widget _imageFallback(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surface,
      child: Icon(
        Icons.inventory_2_outlined,
        size: 40,
        color: theme.colorScheme.secondary.withOpacity(0.4),
      ),
    );
  }
}

/// The reference design's floating "★ 4.9" pill — a white (near-opaque)
/// capsule sitting on the image, rather than plain text below it. Kept
/// deliberately terse (no review count — that lives on the asset detail
/// screen) to match the reference's minimal badge.
class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 14, color: Colors.black),
          const SizedBox(width: 2),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black),
          ),
        ],
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.isFavorite, required this.onTap});

  final bool isFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: const BoxDecoration(
          color: Colors.black45,
          shape: BoxShape.circle,
        ),
        child: AnimatedSwitcher(
          duration: AppMotion.fast,
          // The heart "pops" in with a soft overshoot on favorite/
          // unfavorite (AppMotion.spring) rather than a flat cross-fade —
          // a small, contained example of 2026's micro-delight motion
          // trend on the one tap target here that's purely emotional
          // (every other interaction on this card is informational).
          switchInCurve: AppMotion.spring,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
          child: Icon(
            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            key: ValueKey(isFavorite),
            size: 18,
            color: isFavorite ? Colors.redAccent : Colors.white,
          ),
        ),
      ),
    );
  }
}
