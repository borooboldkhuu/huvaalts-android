import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../../domain/entities/report.dart';
import '../../domain/entities/report_status.dart';
import '../controllers/admin_providers.dart';
import '../controllers/report_resolution_controller.dart';
import '../widgets/report_status_label.dart';

/// Open abuse/content reports (`public.reports`, spec section 30) —
/// existed since Phase 0/1 with an insert-only client policy; this is the
/// first admin action ever wired to it (`admin_resolve_report`,
/// `0012_admin_dashboard.sql`).
class AdminReportQueueScreen extends ConsumerWidget {
  const AdminReportQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final reportsAsync = ref.watch(adminOpenReportsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminReportQueueTitle)),
      body: reportsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: SkeletonCard(),
        ),
        error: (error, stack) => ErrorStateView(
          failure: Failure.from(error),
          onRetry: () => ref.invalidate(adminOpenReportsProvider),
        ),
        data: (reports) {
          if (reports.isEmpty) {
            return EmptyState(title: l10n.adminReportQueueEmptyTitle, icon: Icons.flag_outlined);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: reports.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) => _ReportCard(report: reports[index]),
          );
        },
      ),
    );
  }
}

class _ReportCard extends ConsumerWidget {
  const _ReportCard({required this.report});

  final Report report;

  Future<void> _resolve(BuildContext context, WidgetRef ref, ReportStatus newStatus) async {
    try {
      await ref
          .read(reportResolutionControllerProvider.notifier)
          .resolve(reportId: report.id, newStatus: newStatus);
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
    final bool isSubmitting = ref.watch(reportResolutionControllerProvider).isSubmitting;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(reportTargetTypeLabel(report.targetType, l10n), style: theme.textTheme.titleSmall),
                Chip(
                  label: Text(reportStatusLabel(report.status, l10n)),
                  backgroundColor: reportStatusColor(report.status, context.colors).withOpacity(0.15),
                  labelStyle: TextStyle(color: reportStatusColor(report.status, context.colors)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(report.reason, style: theme.textTheme.bodyMedium),
            if (report.details != null && report.details!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(report.details!, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(AppDateUtils.formatDateTime(report.createdAt), style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                TextButton(
                  onPressed: isSubmitting ? null : () => _resolve(context, ref, ReportStatus.dismissed),
                  child: Text(l10n.adminReportStatusDismissed),
                ),
                OutlinedButton(
                  onPressed: isSubmitting ? null : () => _resolve(context, ref, ReportStatus.reviewed),
                  child: Text(l10n.adminReportStatusReviewed),
                ),
                FilledButton(
                  onPressed: isSubmitting ? null : () => _resolve(context, ref, ReportStatus.actioned),
                  child: Text(l10n.adminReportStatusActioned),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
