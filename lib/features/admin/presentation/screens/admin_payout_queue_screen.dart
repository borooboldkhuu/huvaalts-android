import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../../../wallet/domain/entities/payout.dart';
import '../../../wallet/domain/entities/payout_status.dart';
import '../../../wallet/presentation/widgets/payout_status_label.dart';
import '../controllers/admin_providers.dart';
import '../controllers/payout_processing_controller.dart';
import '../widgets/admin_reason_sheet.dart';

/// Payouts still awaiting action (`pending`/`processing`). Phase 7 only
/// ever built the request side of this — `admin_process_payout`
/// (`0012_admin_dashboard.sql`) is what finally moves one further, and
/// only actually deducts `wallets.available_balance` on the
/// `processing → paid` transition (money hasn't left until it's
/// confirmed sent, not merely "being processed").
class AdminPayoutQueueScreen extends ConsumerWidget {
  const AdminPayoutQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final payoutsAsync = ref.watch(adminPendingPayoutsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminPayoutQueueTitle)),
      body: payoutsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: SkeletonCard(),
        ),
        error: (error, stack) => ErrorStateView(
          failure: Failure.from(error),
          onRetry: () => ref.invalidate(adminPendingPayoutsProvider),
        ),
        data: (payouts) {
          if (payouts.isEmpty) {
            return EmptyState(title: l10n.adminPayoutQueueEmptyTitle, icon: Icons.payments_outlined);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: payouts.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) => _PayoutCard(payout: payouts[index]),
          );
        },
      ),
    );
  }
}

class _PayoutCard extends ConsumerWidget {
  const _PayoutCard({required this.payout});

  final Payout payout;

  Future<void> _process(BuildContext context, WidgetRef ref, PayoutStatus newStatus) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    String? destinationReference;
    if (newStatus == PayoutStatus.paid) {
      destinationReference = await showAdminReasonSheet(
        context,
        title: l10n.adminMarkPayoutPaidTitle,
        label: l10n.adminDestinationReferenceLabel,
        hint: l10n.adminDestinationReferenceHint,
        required: false,
      );
      if (destinationReference == null || !context.mounted) return;
    }
    try {
      await ref.read(payoutProcessingControllerProvider.notifier).process(
            payoutId: payout.id,
            newStatus: newStatus,
            destinationReference:
                destinationReference != null && destinationReference.isNotEmpty
                    ? destinationReference
                    : null,
          );
    } catch (error) {
      if (context.mounted) {
        final (_, message) = failurePresentation(Failure.from(error), l10n);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bool isSubmitting = ref.watch(payoutProcessingControllerProvider).isSubmitting;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(CurrencyFormatter.format(payout.amount), style: theme.textTheme.titleMedium),
                Chip(
                  label: Text(payoutStatusLabel(payout.status, l10n)),
                  backgroundColor: payoutStatusColor(payout.status, context.colors).withOpacity(0.15),
                  labelStyle: TextStyle(color: payoutStatusColor(payout.status, context.colors)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(AppDateUtils.formatDateTime(payout.requestedAt), style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (payout.status == PayoutStatus.pending) ...[
                  TextButton(
                    onPressed: isSubmitting ? null : () => _process(context, ref, PayoutStatus.failed),
                    child: Text(l10n.payoutStatusFailed),
                  ),
                  FilledButton(
                    onPressed: isSubmitting ? null : () => _process(context, ref, PayoutStatus.processing),
                    child: Text(l10n.adminMarkProcessingAction),
                  ),
                ] else if (payout.status == PayoutStatus.processing) ...[
                  TextButton(
                    onPressed: isSubmitting ? null : () => _process(context, ref, PayoutStatus.failed),
                    child: Text(l10n.payoutStatusFailed),
                  ),
                  FilledButton(
                    onPressed: isSubmitting ? null : () => _process(context, ref, PayoutStatus.paid),
                    child: Text(l10n.adminMarkPaidAction),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
