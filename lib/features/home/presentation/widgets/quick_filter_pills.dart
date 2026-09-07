import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../assets/domain/entities/asset_search_filters.dart';

/// Three one-tap shortcuts under the category row (2026 reference
/// redesign) — each just pre-fills Search's filters and switches to that
/// tab (`goNamed`, matching every other Home entry point into Search, see
/// `AssetHomeSection`'s doc comment on why not `pushNamed`). These are
/// shortcuts into the *existing* Search filter set, not a new filter
/// dimension: "50K-с доош" is `maxPrice: 50000` (the same filter Home's
/// own "Under 50,000₮" section already queries) and "3 км дотор" is a
/// tight-radius `nearLatitude`/`nearLongitude` (only enabled once a device
/// fix is available — same best-effort source as the Nearby section).
///
/// "Өнөөдөр авах" (available today) is deliberately NOT wired to a real
/// filter — the schema has no query yet for "has an open availability slot
/// today" (that lives in `asset_availability`, per-asset, not exposed
/// through `asset_cards`/`AssetSearchFilters` at all). Tapping it opens
/// Search with no filters applied rather than silently claiming to filter
/// by something it doesn't; add a real filter here once that query exists
/// server-side.
class QuickFilterPills extends StatelessWidget {
  const QuickFilterPills({required this.nearby, super.key});

  /// Device location, when available (same value `HomeScreen` already
  /// reads from `nearbyLocationProvider`) — passed in rather than watched
  /// here again so there's one source of truth for "is nearby available".
  final (double, double)? nearby;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppColors colors = context.colors;

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: [
          _Pill(
            icon: Icons.bolt_rounded,
            label: l10n.quickFilterAvailableToday,
            colors: colors,
            onTap: () => context.goNamed(RouteNames.search),
          ),
          const SizedBox(width: AppSpacing.sm),
          _Pill(
            icon: Icons.sell_outlined,
            label: l10n.quickFilterUnder50k,
            colors: colors,
            onTap: () => context.goNamed(
              RouteNames.search,
              extra: const AssetSearchFilters(maxPrice: 50000, sort: AssetSortOption.newest),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _Pill(
            icon: Icons.near_me_outlined,
            label: l10n.quickFilterNearby3km,
            colors: colors,
            enabled: nearby != null,
            onTap: nearby == null
                ? null
                : () => context.goNamed(
                      RouteNames.search,
                      extra: AssetSearchFilters(
                        sort: AssetSortOption.closest,
                        nearLatitude: nearby!.$1,
                        nearLongitude: nearby!.$2,
                        radiusKm: 3,
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final AppColors colors;
  final VoidCallback? onTap;
  final bool enabled;

  // Flat light-gray fill, no border — deliberately one visual step below
  // `CategoryAvatar`'s bordered-white pill (design spec: these quick
  // filters should read as a distinct, lower-emphasis tier under the
  // category row, not the same chip style repeated).
  static const Color _fill = Color(0xFFF7F7F7);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color fg = enabled ? colors.onSurface : colors.secondary.withOpacity(0.5);

    return Material(
      color: _fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: AppSpacing.xs),
              Text(label, style: theme.textTheme.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
