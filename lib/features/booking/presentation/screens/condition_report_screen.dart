import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../../domain/entities/booking.dart';
import '../../domain/entities/condition_report.dart';
import '../../domain/entities/condition_report_stage.dart';
import '../controllers/booking_providers.dart';
import '../controllers/condition_report_providers.dart';
import '../controllers/submit_condition_report_controller.dart';

/// Pickup/return condition report (spec section 25). Reached from Booking
/// Detail once a report is possible for that stage — server-side rules in
/// `validate_and_autoconfirm_condition_report`
/// (`supabase/migrations/0010_condition_reports_reviews_disputes.sql`) are
/// the actual authority on *when* (booking status, paid payment before
/// pickup); this screen doesn't duplicate that logic, it just shows
/// whatever error comes back if the timing was wrong.
class ConditionReportScreen extends ConsumerWidget {
  const ConditionReportScreen({required this.bookingId, required this.stage, super.key});

  final String bookingId;
  final ConditionReportStage stage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bookingAsync = ref.watch(bookingByIdProvider(bookingId));
    final reportAsync =
        ref.watch(conditionReportProvider((bookingId: bookingId, stage: stage)));
    final String? currentUserId = ref.watch(supabaseClientProvider).auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          stage == ConditionReportStage.pickup
              ? l10n.conditionReportPickupTitle
              : l10n.conditionReportReturnTitle,
        ),
      ),
      body: bookingAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: SkeletonCard(),
        ),
        error: (error, stack) => ErrorStateView(
          failure: Failure.from(error),
          onRetry: () => ref.invalidate(bookingByIdProvider(bookingId)),
        ),
        data: (booking) {
          if (booking == null || currentUserId == null) {
            return const SizedBox.shrink();
          }
          return reportAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: SkeletonCard(),
            ),
            error: (error, stack) => ErrorStateView(
              failure: Failure.from(error),
              onRetry: () => ref.invalidate(conditionReportProvider((bookingId: bookingId, stage: stage))),
            ),
            data: (report) {
              if (report == null) {
                return _SubmitConditionReportForm(bookingId: bookingId, stage: stage);
              }
              return _ConditionReportView(booking: booking, report: report, currentUserId: currentUserId);
            },
          );
        },
      ),
    );
  }
}

class _SubmitConditionReportForm extends ConsumerStatefulWidget {
  const _SubmitConditionReportForm({required this.bookingId, required this.stage});

  final String bookingId;
  final ConditionReportStage stage;

  @override
  ConsumerState<_SubmitConditionReportForm> createState() => _SubmitConditionReportFormState();
}

class _SubmitConditionReportFormState extends ConsumerState<_SubmitConditionReportForm> {
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    try {
      await ref.read(submitConditionReportControllerProvider.notifier).submit(
            bookingId: widget.bookingId,
            stage: widget.stage,
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          );
      if (!mounted) return;
      ref.invalidate(conditionReportProvider((bookingId: widget.bookingId, stage: widget.stage)));
      ref.invalidate(bookingByIdProvider(widget.bookingId));
    } catch (e) {
      if (!mounted) return;
      final (_, message) = failurePresentation(Failure.from(e), l10n);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final state = ref.watch(submitConditionReportControllerProvider);
    final controller = ref.read(submitConditionReportControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          widget.stage == ConditionReportStage.pickup
              ? l10n.conditionReportPickupIntro
              : l10n.conditionReportReturnIntro,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(l10n.conditionReportPhotosLabel, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        _PhotosPicker(
          photos: state.photos,
          onAdd: controller.addPhotos,
          onRemove: controller.removePhotoAt,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(l10n.conditionReportNotesLabel, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _notesController,
          maxLines: 4,
          decoration: InputDecoration(hintText: l10n.conditionReportNotesHint),
        ),
        const SizedBox(height: AppSpacing.xxl),
        PrimaryButton(
          label: l10n.conditionReportSubmitAction,
          isLoading: state.isSubmitting,
          onPressed: _submit,
        ),
      ],
    );
  }
}

class _PhotosPicker extends StatelessWidget {
  const _PhotosPicker({required this.photos, required this.onAdd, required this.onRemove});

  final List<(Uint8List bytes, String extension)> photos;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool atLimit = photos.length >= kMaxConditionReportPhotos;

    return SizedBox(
      height: 88,
      child: Row(
        children: [
          GestureDetector(
            onTap: atLimit ? null : onAdd,
            child: Opacity(
              opacity: atLimit ? 0.4 : 1,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: const Icon(Icons.add_photo_alternate_outlined),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (photos.isNotEmpty)
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: Image.memory(
                          photos[index].$1,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => onRemove(index),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ConditionReportView extends ConsumerWidget {
  const _ConditionReportView({
    required this.booking,
    required this.report,
    required this.currentUserId,
  });

  final Booking booking;
  final ConditionReport report;
  final String currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bool needsMyConfirmation = report.needsConfirmationFrom(
      userId: currentUserId,
      renterId: booking.renterId,
      ownerId: booking.ownerId,
    );
    final confirmState = ref.watch(confirmConditionReportControllerProvider);

    Future<void> confirm() async {
      try {
        await ref.read(confirmConditionReportControllerProvider.notifier).confirm(report.id);
        ref.invalidate(
          conditionReportProvider((bookingId: report.bookingId, stage: report.stage)),
        );
        ref.invalidate(bookingByIdProvider(report.bookingId));
      } catch (e) {
        if (!context.mounted) return;
        final (_, message) = failurePresentation(Failure.from(e), l10n);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (report.photoPaths.isNotEmpty) ...[
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: report.photoPaths.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) => ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: _SignedConditionReportPhoto(path: report.photoPaths[index]),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (report.notes != null && report.notes!.isNotEmpty) ...[
          Text(l10n.conditionReportNotesLabel, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(report.notes!, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
        ],
        _ConfirmationRow(
          label: l10n.conditionReportRenterConfirmationLabel,
          confirmed: report.confirmedByRenterAt != null,
        ),
        _ConfirmationRow(
          label: l10n.conditionReportOwnerConfirmationLabel,
          confirmed: report.confirmedByOwnerAt != null,
        ),
        const SizedBox(height: AppSpacing.xxl),
        if (needsMyConfirmation)
          PrimaryButton(
            label: l10n.conditionReportConfirmAction,
            isLoading: confirmState.isSubmitting,
            onPressed: confirm,
          )
        else
          Text(
            report.isFullyConfirmed
                ? l10n.conditionReportFullyConfirmedNotice
                : l10n.conditionReportWaitingOnOtherPartyNotice,
            style: theme.textTheme.bodyMedium,
          ),
      ],
    );
  }
}

class _ConfirmationRow extends StatelessWidget {
  const _ConfirmationRow({required this.label, required this.confirmed});

  final String label;
  final bool confirmed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            confirmed ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: confirmed ? theme.colorScheme.primary : theme.disabledColor,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _SignedConditionReportPhoto extends ConsumerWidget {
  const _SignedConditionReportPhoto({required this.path});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<String> signedUrl = ref.watch(signedConditionReportPhotoUrlProvider(path));
    return signedUrl.when(
      data: (url) => CachedNetworkImage(
        imageUrl: url,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
      ),
      loading: () => const SkeletonLoader(width: 80, height: 80, borderRadius: AppRadius.md),
      error: (_, _) => const SkeletonLoader(width: 80, height: 80, borderRadius: AppRadius.md),
    );
  }
}
