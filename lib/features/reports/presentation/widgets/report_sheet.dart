import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failure.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../admin/domain/entities/report_target_type.dart';
import '../../../admin/presentation/widgets/report_status_label.dart';
import '../controllers/report_controller.dart';

/// Opens the "report abuse" bottom sheet for [targetType]/[targetId] —
/// the client-facing counterpart to the admin report queue
/// (`AdminReportQueueScreen`), which has had nothing feeding it since
/// Phase 0/1. Call sites: `AssetDetailScreen`'s AppBar (report the
/// listing), the owner card on the same screen (report the user), and
/// `ChatScreen`'s message long-press menu (report a message). Shows its
/// own success/error snackbar and pops itself on success — callers don't
/// need to do anything with the return value.
Future<void> showReportSheet(
  BuildContext context, {
  required ReportTargetType targetType,
  required String targetId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _ReportSheet(targetType: targetType, targetId: targetId),
  );
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({required this.targetType, required this.targetId});

  final ReportTargetType targetType;
  final String targetId;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  final TextEditingController _detailsController = TextEditingController();
  String? _selectedReasonKey;
  String? _reasonError;
  String? _detailsError;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  /// Stable, locale-independent keys for the fixed reason options —
  /// mapped to the actual (localized) text stored as `reports.reason`
  /// only at submit time, so switching the app's language mid-selection
  /// can't leave a stale label picked.
  List<(String key, String label)> _reasonOptions(AppLocalizations l10n) => [
        ('inappropriate_content', l10n.reportReasonInappropriateContent),
        ('fraud', l10n.reportReasonFraud),
        ('harassment', l10n.reportReasonHarassment),
        ('misleading_listing', l10n.reportReasonMisleadingListing),
        ('other', l10n.reportReasonOther),
      ];

  Future<void> _submit(AppLocalizations l10n, List<(String key, String label)> options) async {
    setState(() {
      _reasonError = null;
      _detailsError = null;
    });

    final String? key = _selectedReasonKey;
    if (key == null) {
      setState(() => _reasonError = l10n.adminReasonRequiredError);
      return;
    }
    final String details = _detailsController.text.trim();
    if (key == 'other' && details.isEmpty) {
      setState(() => _detailsError = l10n.reportDetailsRequiredForOtherError);
      return;
    }
    final String reasonLabel = options.firstWhere((o) => o.$1 == key).$2;

    try {
      await ref.read(reportControllerProvider.notifier).submit(
            targetType: widget.targetType,
            targetId: widget.targetId,
            reason: reasonLabel,
            details: details.isEmpty ? null : details,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.reportSubmittedMessage)));
    } catch (error) {
      if (!mounted) return;
      final (_, message) = failurePresentation(Failure.from(error), l10n);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bool isSubmitting = ref.watch(reportControllerProvider).isSubmitting;
    final List<(String key, String label)> options = _reasonOptions(l10n);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.reportSheetTitle(reportTargetTypeLabel(widget.targetType, l10n)),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.reportReasonLabel, style: theme.textTheme.labelLarge),
            ...options.map(
              (option) => RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                value: option.$1,
                groupValue: _selectedReasonKey,
                title: Text(option.$2),
                onChanged: (value) => setState(() {
                  _selectedReasonKey = value;
                  _reasonError = null;
                }),
              ),
            ),
            if (_reasonError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(_reasonError!, style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
              ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _detailsController,
              label: l10n.reportDetailsLabel,
              hintText: l10n.reportDetailsHint,
              maxLines: 3,
              errorText: _detailsError,
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: l10n.reportSubmitAction,
              isLoading: isSubmitting,
              onPressed: () => _submit(l10n, options),
            ),
          ],
        ),
      ),
    );
  }
}
