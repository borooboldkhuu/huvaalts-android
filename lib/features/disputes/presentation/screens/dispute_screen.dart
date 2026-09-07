import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failure.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../../domain/entities/dispute.dart';
import '../../domain/entities/dispute_category.dart';
import '../controllers/dispute_providers.dart';
import '../controllers/submit_dispute_controller.dart';
import '../widgets/dispute_status_label.dart';

/// File a dispute on a booking, or view the one already raised (spec
/// section 26). Resolving a dispute is an admin action
/// (`disputes_update_admin`, Phase 11's moderation UI doesn't exist yet)
/// — this screen is read-only once a dispute exists, it never lets a
/// participant change its status themselves.
class DisputeScreen extends ConsumerWidget {
  const DisputeScreen({required this.bookingId, super.key});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final disputeAsync = ref.watch(latestDisputeForBookingProvider(bookingId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.disputeScreenTitle)),
      body: disputeAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: SkeletonCard(),
        ),
        error: (error, stack) => ErrorStateView(
          failure: Failure.from(error),
          onRetry: () => ref.invalidate(latestDisputeForBookingProvider(bookingId)),
        ),
        data: (dispute) {
          if (dispute != null && dispute.status.isActive) {
            return _DisputeStatusView(dispute: dispute);
          }
          // No dispute yet, or the last one was resolved/rejected — a new
          // one can be raised (validate_dispute_insert only blocks a
          // second *open* dispute, not a fresh one after resolution).
          return _SubmitDisputeForm(bookingId: bookingId);
        },
      ),
    );
  }
}

class _SubmitDisputeForm extends ConsumerStatefulWidget {
  const _SubmitDisputeForm({required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<_SubmitDisputeForm> createState() => _SubmitDisputeFormState();
}

class _SubmitDisputeFormState extends ConsumerState<_SubmitDisputeForm> {
  DisputeCategory _category = DisputeCategory.itemDamaged;
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String description = _descriptionController.text.trim();
    if (description.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.disputeDescriptionRequiredError)));
      return;
    }
    try {
      await ref.read(submitDisputeControllerProvider.notifier).submit(
            bookingId: widget.bookingId,
            category: _category,
            description: description,
          );
      if (!mounted) return;
      ref.invalidate(latestDisputeForBookingProvider(widget.bookingId));
    } catch (e) {
      if (!mounted) return;
      final (_, message) = failurePresentation(Failure.from(e), l10n);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(submitDisputeControllerProvider);
    final controller = ref.read(submitDisputeControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(l10n.disputeIntro, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.xl),
        Text(l10n.disputeCategoryLabel, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<DisputeCategory>(
          value: _category,
          items: [
            for (final category in DisputeCategory.values)
              DropdownMenuItem(
                value: category,
                child: Text(disputeCategoryLabel(category, l10n)),
              ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _category = value);
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(l10n.disputeDescriptionLabel, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _descriptionController,
          maxLines: 5,
          decoration: InputDecoration(hintText: l10n.disputeDescriptionHint),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(l10n.disputeEvidenceLabel, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        _EvidencePicker(
          evidence: state.evidence,
          onAdd: controller.addEvidence,
          onRemove: controller.removeEvidenceAt,
        ),
        const SizedBox(height: AppSpacing.xxl),
        PrimaryButton(
          label: l10n.disputeSubmitAction,
          isLoading: state.isSubmitting,
          onPressed: _submit,
        ),
      ],
    );
  }
}

class _EvidencePicker extends StatelessWidget {
  const _EvidencePicker({required this.evidence, required this.onAdd, required this.onRemove});

  final List<(Uint8List bytes, String extension)> evidence;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool atLimit = evidence.length >= kMaxDisputeEvidencePhotos;

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
          if (evidence.isNotEmpty)
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: evidence.length,
                separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Image.memory(
                        evidence[index].$1,
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
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DisputeStatusView extends ConsumerWidget {
  const _DisputeStatusView({required this.dispute});

  final Dispute dispute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
          decoration: BoxDecoration(
            color: disputeStatusColor(dispute.status, context.colors).withOpacity(0.12),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            disputeStatusLabel(dispute.status, l10n),
            style: theme.textTheme.labelMedium
                ?.copyWith(color: disputeStatusColor(dispute.status, context.colors)),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(disputeCategoryLabel(dispute.category, l10n), style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(dispute.description, style: theme.textTheme.bodyMedium),
        if (dispute.evidencePaths.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: dispute.evidencePaths.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) => ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: _SignedEvidencePhoto(path: dispute.evidencePaths[index]),
              ),
            ),
          ),
        ],
        if (dispute.resolutionNotes != null && dispute.resolutionNotes!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Text(l10n.disputeResolutionNotesLabel, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(dispute.resolutionNotes!, style: theme.textTheme.bodyMedium),
        ],
      ],
    );
  }
}

class _SignedEvidencePhoto extends ConsumerWidget {
  const _SignedEvidencePhoto({required this.path});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<String>(
      future: ref.read(disputeRepositoryProvider).signedEvidenceUrl(path),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SkeletonLoader(width: 80, height: 80, borderRadius: AppRadius.md);
        }
        return CachedNetworkImage(
          imageUrl: snapshot.data!,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
        );
      },
    );
  }
}
