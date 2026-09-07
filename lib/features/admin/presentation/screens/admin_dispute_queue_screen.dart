import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../../../disputes/domain/entities/dispute.dart';
import '../../../disputes/domain/entities/dispute_status.dart';
import '../../../disputes/presentation/widgets/dispute_status_label.dart';
import '../controllers/admin_providers.dart';
import '../controllers/booking_refund_controller.dart';
import '../controllers/dispute_resolution_controller.dart';
import '../widgets/admin_reason_sheet.dart';

/// Disputes not yet finally resolved (`open`/`underReview`/`escalated`).
/// This screen is the only path left to change a dispute's status —
/// `disputes_update_admin`'s direct-RLS-write policy was dropped in
/// `0012_admin_dashboard.sql` in favor of the audited
/// `admin_resolve_dispute` RPC this calls.
class AdminDisputeQueueScreen extends ConsumerWidget {
  const AdminDisputeQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final disputesAsync = ref.watch(adminOpenDisputesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminDisputeQueueTitle)),
      body: disputesAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: SkeletonCard(),
        ),
        error: (error, stack) => ErrorStateView(
          failure: Failure.from(error),
          onRetry: () => ref.invalidate(adminOpenDisputesProvider),
        ),
        data: (disputes) {
          if (disputes.isEmpty) {
            return EmptyState(title: l10n.adminDisputeQueueEmptyTitle, icon: Icons.gavel_outlined);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: disputes.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) => _DisputeCard(dispute: disputes[index]),
          );
        },
      ),
    );
  }
}

class _DisputeCard extends ConsumerWidget {
  const _DisputeCard({required this.dispute});

  final Dispute dispute;

  Future<void> _resolve(BuildContext context, WidgetRef ref, DisputeStatus newStatus) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? notes = await showAdminReasonSheet(
      context,
      title: l10n.adminResolveDisputeTitle,
      label: l10n.disputeResolutionNotesLabel,
      hint: l10n.adminResolutionNotesHint,
      required: false,
    );
    if (notes == null || !context.mounted) return;
    try {
      await ref.read(disputeResolutionControllerProvider.notifier).resolve(
            disputeId: dispute.id,
            newStatus: newStatus,
            resolutionNotes: notes.isEmpty ? null : notes,
          );
    } catch (error) {
      if (context.mounted) {
        final (_, message) = failurePresentation(Failure.from(error), l10n);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  Future<void> _refund(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.adminRefundBookingTitle),
            content: Text(l10n.adminRefundConfirmMessage),
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

    final String? reason = await showAdminReasonSheet(
      context,
      title: l10n.adminRefundBookingTitle,
      label: l10n.adminReasonLabel,
      hint: l10n.adminRefundReasonHint,
      required: false,
    );
    if (reason == null || !context.mounted) return;

    try {
      await ref.read(bookingRefundControllerProvider.notifier).refund(
            bookingId: dispute.bookingId,
            reason: reason.isEmpty ? null : reason,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.adminRefundSuccessMessage)));
      }
    } catch (error) {
      if (!context.mounted) return;
      final String message = switch (error) {
        ValidationException(message: 'no_paid_payment') => l10n.adminRefundNoPaidPaymentError,
        ConflictException(message: 'already_refunded') => l10n.adminRefundAlreadyRefundedError,
        ConflictException(message: 'owner_balance_insufficient_for_reversal') =>
          l10n.adminRefundOwnerBalanceInsufficientError,
        _ => failurePresentation(Failure.from(error), l10n).$2,
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bool isSubmitting = ref.watch(disputeResolutionControllerProvider).isSubmitting;
    final bool isRefunding = ref.watch(bookingRefundControllerProvider).isSubmitting;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(disputeCategoryLabel(dispute.category, l10n), style: theme.textTheme.titleSmall),
                Chip(
                  label: Text(disputeStatusLabel(dispute.status, l10n)),
                  backgroundColor: disputeStatusColor(dispute.status, context.colors).withOpacity(0.15),
                  labelStyle: TextStyle(color: disputeStatusColor(dispute.status, context.colors)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(dispute.description, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(AppDateUtils.formatDateTime(dispute.createdAt), style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                TextButton(
                  onPressed: isSubmitting ? null : () => _resolve(context, ref, DisputeStatus.rejected),
                  child: Text(l10n.adminRejectAction),
                ),
                OutlinedButton(
                  onPressed: isSubmitting ? null : () => _resolve(context, ref, DisputeStatus.underReview),
                  child: Text(l10n.disputeStatusUnderReview),
                ),
                OutlinedButton(
                  onPressed: isSubmitting ? null : () => _resolve(context, ref, DisputeStatus.escalated),
                  child: Text(l10n.disputeStatusEscalated),
                ),
                OutlinedButton(
                  onPressed: isRefunding ? null : () => _refund(context, ref),
                  child: Text(l10n.adminRefundRenterAction),
                ),
                FilledButton(
                  onPressed: isSubmitting ? null : () => _resolve(context, ref, DisputeStatus.resolved),
                  child: Text(l10n.adminResolveAction),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
