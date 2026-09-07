import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../../domain/entities/promotion.dart';
import '../controllers/admin_providers.dart';
import '../controllers/promotion_management_controller.dart';

/// Every promotion, active or not (spec section 30, Phase 12). Closes the
/// last direct-RLS-write admin gap Phase 11's own README flagged but left
/// out of scope (`promotions_admin_write`) — see
/// `supabase/migrations/0013_security_perf_hardening.sql`. There's still
/// no consumer-facing "apply a promo code" flow; this screen is authoring
/// only.
class AdminPromotionsScreen extends ConsumerWidget {
  const AdminPromotionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final promotionsAsync = ref.watch(adminPromotionsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminPromotionsTitle)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.pushNamed(RouteNames.adminPromotionForm),
        child: const Icon(Icons.add),
      ),
      body: promotionsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: SkeletonCard(),
        ),
        error: (error, stack) => ErrorStateView(
          failure: Failure.from(error),
          onRetry: () => ref.invalidate(adminPromotionsProvider),
        ),
        data: (promotions) {
          if (promotions.isEmpty) {
            return EmptyState(
              title: l10n.adminPromotionsEmptyTitle,
              icon: Icons.local_offer_outlined,
              actionLabel: l10n.adminAddPromotionAction,
              onAction: () => context.pushNamed(RouteNames.adminPromotionForm),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.huge,
            ),
            itemCount: promotions.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) => _PromotionCard(promotion: promotions[index]),
          );
        },
      ),
    );
  }
}

class _PromotionCard extends ConsumerWidget {
  const _PromotionCard({required this.promotion});

  final Promotion promotion;

  Future<void> _deactivate(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(promotionManagementControllerProvider.notifier).deactivate(promotion.id);
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
    final bool isSubmitting = ref.watch(promotionManagementControllerProvider).isSubmitting;

    return Card(
      child: ListTile(
        onTap: () => context.pushNamed(RouteNames.adminPromotionForm, extra: promotion),
        title: Text(promotion.title),
        subtitle: Text(
          '${AppDateUtils.formatShortDate(promotion.startsAt)} – '
          '${AppDateUtils.formatShortDate(promotion.endsAt)}'
          '${promotion.discountPercent != null ? ' · ${promotion.discountPercent}%' : ''}',
        ),
        leading: Icon(
          promotion.isActive ? Icons.local_offer : Icons.local_offer_outlined,
          color: promotion.isActive ? theme.colorScheme.primary : theme.colorScheme.secondary,
        ),
        trailing: promotion.isActive
            ? TextButton(
                onPressed: isSubmitting ? null : () => _deactivate(context, ref),
                child: Text(l10n.adminDeactivateAction),
              )
            : Text(l10n.adminPromotionStatusInactive, style: theme.textTheme.bodySmall),
      ),
    );
  }
}
