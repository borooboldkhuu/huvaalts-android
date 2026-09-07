import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';

/// Static value-proposition banner (2026 reference redesign) — four
/// icon+label points restating what the marketplace already does
/// elsewhere (search, distance sort, wallet payment, verified owners).
/// Deliberately has no data dependency and never loads/errors: it's
/// marketing chrome, not a feature surface, so it always renders the same
/// four points rather than needing an empty/loading/error branch like
/// every data-backed section on this screen.
class PromoValueBanner extends StatelessWidget {
  const PromoValueBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppColors colors = context.colors;

    final items = [
      (Icons.bolt_rounded, l10n.homePromoEasySearchTitle, l10n.homePromoEasySearchDesc),
      (Icons.place_outlined, l10n.homePromoNearbyTitle, l10n.homePromoNearbyDesc),
      (Icons.shield_outlined, l10n.homePromoSafePaymentTitle, l10n.homePromoSafePaymentDesc),
      (Icons.verified_outlined, l10n.homePromoVerifiedTitle, l10n.homePromoVerifiedDesc),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.homePromoTitle, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.md),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              // A generous fixed ratio (not the default 1.0) — Mongolian
              // two-line descriptions under a short title need more
              // height than they do width, and a `GridView` cell that's
              // too short for its content overflows silently rather than
              // growing (unlike the intrinsic-height `Column` approach
              // `AssetHomeSection`'s mosaic uses on purpose — four short,
              // fixed-shape items here don't need that flexibility).
              childAspectRatio: 2.6,
              children: [for (final item in items) _PromoItem(icon: item.$1, title: item.$2, desc: item.$3)],
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoItem extends StatelessWidget {
  const _PromoItem({required this.icon, required this.title, required this.desc});

  final IconData icon;
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final AppColors colors = context.colors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: colors.accent.withOpacity(0.14), shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: colors.accent),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                desc,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(color: colors.secondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
