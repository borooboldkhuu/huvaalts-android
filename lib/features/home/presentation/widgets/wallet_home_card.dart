import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../wallet/presentation/controllers/wallet_providers.dart';

/// Compact wallet balance summary on Home (2026 reference redesign) — a
/// shortcut into the full Wallet tab, not a duplicate of it. Deliberately
/// shows ONLY `availableBalance` (the one figure `pay_booking_from_wallet`
/// actually spends from, per `wallet.dart`'s own doc comment) — no loyalty/
/// bonus-points figure, since that system doesn't exist anywhere in this
/// schema; the reference design's "Бонус оноо" tile was dropped rather
/// than filled with a fabricated number (confirmed with the user rather
/// than guessed).
class WalletHomeCard extends ConsumerWidget {
  const WalletHomeCard({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppColors colors = context.colors;
    final walletAsync = ref.watch(walletProvider(userId));

    // No error branch here on purpose: Home is a browse surface, and a
    // wallet lookup failure (network blip, RLS edge case) shouldn't block
    // the rest of the page — the full Wallet tab (which this card only
    // links to) already has its own proper `ErrorStateView` + retry.
    final double? balance = walletAsync.value?.availableBalance;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => context.goNamed(RouteNames.wallet),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // The old header row also repeated "Дэлгэрэнгүй >" here
                      // — purely decorative, and on a narrow phone width its
                      // fixed-width siblings (title + label + chevron) didn't
                      // fit next to the FilledButton beside them, overflowing
                      // the row. Dropped rather than re-fitted: the whole
                      // card is already one `InkWell` to the same
                      // `RouteNames.wallet` destination, so the link was
                      // pure duplication, not new functionality.
                      Text(l10n.homeWalletCardTitle, style: theme.textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.sm),
                      Text(l10n.homeWalletBalanceLabel, style: theme.textTheme.bodySmall?.copyWith(color: colors.secondary)),
                      const SizedBox(height: 2),
                      Text(
                        balance != null ? CurrencyFormatter.format(balance) : '—',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: colors.accent),
                  onPressed: () => context.goNamed(RouteNames.wallet),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded, size: 16),
                      const SizedBox(width: 4),
                      Text(l10n.homeWalletTopUpCta),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
