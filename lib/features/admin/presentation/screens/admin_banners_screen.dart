import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failure.dart';
import '../../../../shared/entities/app_banner.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../controllers/admin_banner_list_controller.dart';
import '../controllers/admin_providers.dart';

/// Every banner, active or not (mirrors `AdminPromotionsScreen`). The
/// admin-authoring half of the "app-open banner" feature — the
/// user-facing half is the popup `HomeScreen` shows on first render
/// (`app_banner_popup.dart`), which only ever sees `is_active = true`
/// rows, sorted by [AppBanner.sortOrder].
class AdminBannersScreen extends ConsumerWidget {
  const AdminBannersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bannersAsync = ref.watch(adminAppBannersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminBannersTitle)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.pushNamed(RouteNames.adminBannerForm),
        child: const Icon(Icons.add),
      ),
      body: bannersAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: SkeletonCard(),
        ),
        error: (error, stack) => ErrorStateView(
          failure: Failure.from(error),
          onRetry: () => ref.invalidate(adminAppBannersProvider),
        ),
        data: (banners) {
          if (banners.isEmpty) {
            return EmptyState(
              title: l10n.adminBannersEmptyTitle,
              icon: Icons.image_outlined,
              actionLabel: l10n.adminAddBannerAction,
              onAction: () => context.pushNamed(RouteNames.adminBannerForm),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.huge,
            ),
            itemCount: banners.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) => _BannerCard(banner: banners[index]),
          );
        },
      ),
    );
  }
}

class _BannerCard extends ConsumerWidget {
  const _BannerCard({required this.banner});

  final AppBanner banner;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.adminBannerDeleteConfirmTitle),
            content: Text(l10n.adminBannerDeleteConfirmMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.adminBannerDeleteAction),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    try {
      await ref.read(adminBannerListControllerProvider.notifier).delete(banner.id);
    } catch (error) {
      if (context.mounted) {
        final (_, message) = failurePresentation(Failure.from(error), AppLocalizations.of(context));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bool isSubmitting = ref.watch(adminBannerListControllerProvider).isSubmitting;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => context.pushNamed(RouteNames.adminBannerForm, extra: banner),
        contentPadding: const EdgeInsets.all(AppSpacing.sm),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Image.network(
            banner.imageUrl,
            width: 64,
            height: 64,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => Container(
              width: 64,
              height: 64,
              color: theme.colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
        title: Text('#${banner.sortOrder}'),
        subtitle: Text(
          banner.isActive ? l10n.adminBannerStatusActive : l10n.adminBannerStatusInactive,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: isSubmitting ? null : () => _delete(context, ref),
        ),
      ),
    );
  }
}
