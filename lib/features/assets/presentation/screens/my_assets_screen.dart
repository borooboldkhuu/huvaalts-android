import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failure.dart';
import '../../../../shared/cards/asset_card_tile.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../controllers/asset_providers.dart';

/// "Миний хөрөнгө" (spec section 22's minimal slice): the signed-in
/// user's own listings, any status, newest first. Not the full owner
/// analytics dashboard (views/bookings/earnings per listing) that spec
/// section 22 also describes — that's a later-phase addition once there's
/// booking/earnings data to show.
class MyAssetsScreen extends ConsumerWidget {
  const MyAssetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final myAssetsAsync = ref.watch(myAssetsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.myAssetsTitle)),
      body: myAssetsAsync.when(
        loading: () => GridView.builder(
          padding: const EdgeInsets.all(AppSpacing.lg),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.lg,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 0.74,
          ),
          itemCount: 4,
          itemBuilder: (context, index) => const SkeletonCard(),
        ),
        error: (error, stack) => ErrorStateView(
          failure: Failure.from(error),
          onRetry: () => ref.invalidate(myAssetsProvider),
        ),
        data: (assets) {
          if (assets.isEmpty) {
            return EmptyState(
              title: l10n.myAssetsEmptyTitle,
              icon: Icons.inventory_2_outlined,
              actionLabel: l10n.addAssetAction,
              onAction: () => context.pushNamed(RouteNames.assetCreate),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.lg,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 0.74,
            ),
            itemCount: assets.length,
            itemBuilder: (context, index) {
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
    );
  }
}
