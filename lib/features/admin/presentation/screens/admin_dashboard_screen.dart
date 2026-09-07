import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failure.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../domain/entities/wire_topup_reconciliation_result.dart';
import '../controllers/wire_topup_reconciliation_controller.dart';

/// Landing screen for admin users (spec sections 22, 29, 30, 34) — reached
/// from Profile, only shown there when `isAdminProvider` resolves true.
/// Most tiles are just navigation; the actual admin-only enforcement lives
/// server-side in every RPC/Edge Function these screens call (see
/// `AdminRepository`'s header comment) — this screen itself doesn't
/// re-check admin status, since `ProfileScreen` already gates the entry
/// point and every RPC/function re-checks on its own regardless.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  Future<void> _reconcileWireTopups(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.adminReconcileWireTopupsTitle),
            content: Text(l10n.adminReconcileWireTopupsConfirmMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.adminConfirmAction),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;

    await ref.read(wireTopupReconciliationControllerProvider.notifier).reconcile();
    if (!context.mounted) return;

    final WireTopupReconciliationState state = ref.read(wireTopupReconciliationControllerProvider);
    if (state is WireTopupReconciliationDone) {
      final WireTopupReconciliationResult result = state.result;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.adminReconcileWireTopupsTitle),
          content: Text(
            l10n.adminReconcileWireTopupsResultMessage(result.checked, result.credited, result.markedFailed),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.commonClose),
            ),
          ],
        ),
      );
    } else if (state is WireTopupReconciliationFailed) {
      final (_, message) = failurePresentation(Failure.from(state.error), l10n);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
    // Idle/InProgress: unreachable here — reconcile() always ends in
    // Done or Failed before this point.
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool isReconciling =
        ref.watch(wireTopupReconciliationControllerProvider) is WireTopupReconciliationInProgress;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminDashboardTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _AdminTile(
            icon: Icons.fact_check_outlined,
            title: l10n.adminAssetModerationTitle,
            subtitle: l10n.adminAssetModerationSubtitle,
            onTap: () => context.pushNamed(RouteNames.adminAssetModeration),
          ),
          _AdminTile(
            icon: Icons.gavel_outlined,
            title: l10n.adminDisputeQueueTitle,
            subtitle: l10n.adminDisputeQueueSubtitle,
            onTap: () => context.pushNamed(RouteNames.adminDisputes),
          ),
          _AdminTile(
            icon: Icons.payments_outlined,
            title: l10n.adminPayoutQueueTitle,
            subtitle: l10n.adminPayoutQueueSubtitle,
            onTap: () => context.pushNamed(RouteNames.adminPayouts),
          ),
          _AdminTile(
            icon: Icons.flag_outlined,
            title: l10n.adminReportQueueTitle,
            subtitle: l10n.adminReportQueueSubtitle,
            onTap: () => context.pushNamed(RouteNames.adminReports),
          ),
          _AdminTile(
            icon: Icons.percent_outlined,
            title: l10n.adminCommissionSettingsTitle,
            subtitle: l10n.adminCommissionSettingsSubtitle,
            onTap: () => context.pushNamed(RouteNames.adminCommissionSettings),
          ),
          _AdminTile(
            icon: Icons.local_offer_outlined,
            title: l10n.adminPromotionsTitle,
            subtitle: l10n.adminPromotionsSubtitle,
            onTap: () => context.pushNamed(RouteNames.adminPromotions),
          ),
          _AdminTile(
            icon: Icons.image_outlined,
            title: l10n.adminBannersTitle,
            subtitle: l10n.adminBannersSubtitle,
            onTap: () => context.pushNamed(RouteNames.adminBanners),
          ),
          // Not navigation like the tiles above — a one-shot maintenance
          // action (see `reconcile-wire-topups`'s header comment), so it
          // runs in place with a spinner trailing icon instead of the
          // chevron the navigational tiles use.
          _AdminTile(
            icon: Icons.sync_outlined,
            title: l10n.adminReconcileWireTopupsTitle,
            subtitle: l10n.adminReconcileWireTopupsSubtitle,
            trailing: isReconciling
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: isReconciling ? null : () => _reconcileWireTopups(context, ref),
          ),
        ],
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  const _AdminTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: trailing ?? const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
