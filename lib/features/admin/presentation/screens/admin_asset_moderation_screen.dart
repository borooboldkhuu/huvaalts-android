import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/storage_urls.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../../../assets/domain/entities/asset_status.dart';
import '../../../assets/presentation/widgets/asset_status_label.dart';
import '../../domain/entities/asset_moderation_summary.dart';
import '../controllers/admin_providers.dart';
import '../controllers/asset_moderation_controller.dart';
import '../widgets/admin_reason_sheet.dart';

/// Listings pending first approval (`pendingReview`) or already live and
/// suspendable (`published`) — closes the gap Phase 3 flagged ("Revisit
/// this default once admin approval exists") and the previously-
/// undocumented one Phase 11 found alongside it (an owner could set
/// `status` straight to `published` via `assets_update_own`'s RLS with no
/// server-side check — see `enforce_asset_status_transition`,
/// `0012_admin_dashboard.sql`).
class AdminAssetModerationScreen extends ConsumerWidget {
  const AdminAssetModerationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final assetsAsync = ref.watch(pendingAssetsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminAssetModerationTitle)),
      body: assetsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: SkeletonCard(),
        ),
        error: (error, stack) => ErrorStateView(
          failure: Failure.from(error),
          onRetry: () => ref.invalidate(pendingAssetsProvider),
        ),
        data: (assets) {
          if (assets.isEmpty) {
            return EmptyState(title: l10n.adminAssetModerationEmptyTitle, icon: Icons.fact_check_outlined);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: assets.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) => _AssetModerationCard(asset: assets[index]),
          );
        },
      ),
    );
  }
}

class _AssetModerationCard extends ConsumerWidget {
  const _AssetModerationCard({required this.asset});

  final AssetModerationSummary asset;

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(assetModerationControllerProvider.notifier).approve(asset.id);
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? reason = await showAdminReasonSheet(
      context,
      title: l10n.adminRejectAssetTitle,
      label: l10n.adminReasonLabel,
      hint: l10n.adminRejectAssetReasonHint,
    );
    if (reason == null || !context.mounted) return;
    try {
      await ref.read(assetModerationControllerProvider.notifier).reject(assetId: asset.id, reason: reason);
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _suspend(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? reason = await showAdminReasonSheet(
      context,
      title: l10n.adminSuspendAssetTitle,
      label: l10n.adminReasonLabel,
      hint: l10n.adminSuspendAssetReasonHint,
    );
    if (reason == null || !context.mounted) return;
    try {
      await ref
          .read(assetModerationControllerProvider.notifier)
          .suspend(assetId: asset.id, reason: reason);
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  void _showError(BuildContext context, Object error) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final (_, message) = failurePresentation(Failure.from(error), l10n);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bool isSubmitting = ref.watch(assetModerationControllerProvider).isSubmitting;
    final String? imageUrl = StorageUrls.assetImage(asset.primaryImagePath);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: imageUrl != null
                        ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover)
                        : Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.image_not_supported_outlined),
                          ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(asset.title, style: theme.textTheme.titleSmall),
                      Text(asset.ownerDisplayName, style: theme.textTheme.bodySmall),
                      if (asset.displayPrice != null)
                        Text(
                          CurrencyFormatter.format(asset.displayPrice!),
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(assetStatusLabel(asset.status, l10n)),
                  backgroundColor: assetStatusColor(asset.status, context.colors).withOpacity(0.15),
                  labelStyle: TextStyle(color: assetStatusColor(asset.status, context.colors)),
                ),
              ],
            ),
            if (asset.moderationNote != null && asset.moderationNote!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.adminModerationNoteLabel(asset.moderationNote!),
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (asset.status == AssetStatus.pendingReview) ...[
                  TextButton(
                    onPressed: isSubmitting ? null : () => _reject(context, ref),
                    child: Text(l10n.adminRejectAction),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: isSubmitting ? null : () => _approve(context, ref),
                    child: Text(l10n.adminApproveAction),
                  ),
                ] else if (asset.status == AssetStatus.published)
                  OutlinedButton(
                    onPressed: isSubmitting ? null : () => _suspend(context, ref),
                    child: Text(l10n.adminSuspendAction),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
