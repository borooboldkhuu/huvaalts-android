import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../../../../shared/widgets/star_rating.dart';
import '../../../booking/domain/entities/booking.dart';
import '../../../booking/presentation/controllers/booking_providers.dart';
import '../../domain/entities/review_category.dart';
import '../../domain/entities/reviewer_role.dart';
import '../controllers/review_providers.dart';
import '../controllers/submit_review_controller.dart';

/// Leave a review for the counterparty on a `completed` booking (spec
/// section 27). Only reachable from Booking Detail once
/// `myReviewForBookingProvider` confirms the signed-in user hasn't
/// already reviewed this booking — `reviews_insert_participant`'s own
/// `booking.status = 'completed'` + `reviews_booking_id_reviewer_id_key`
/// unique constraint (0001/0002) are the actual authority either way.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({required this.bookingId, super.key});

  final String bookingId;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  int _overallRating = 5;
  final Map<ReviewCategory, int> _categoryRatings = {
    for (final c in ReviewCategory.values) c: 5,
  };
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit({required String revieweeId, required ReviewerRole role}) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    try {
      await ref.read(submitReviewControllerProvider.notifier).submit(
            bookingId: widget.bookingId,
            revieweeId: revieweeId,
            role: role,
            rating: _overallRating,
            comment: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
            categoryScores: {
              for (final entry in _categoryRatings.entries) entry.key.key: entry.value,
            },
          );
      if (!mounted) return;
      ref.invalidate(myReviewForBookingProvider(widget.bookingId));
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.reviewSubmittedMessage)));
    } catch (e) {
      if (!mounted) return;
      final (_, message) = failurePresentation(Failure.from(e), l10n);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String _categoryLabel(AppLocalizations l10n, ReviewCategory category) {
    return switch (category) {
      ReviewCategory.communication => l10n.reviewCategoryCommunication,
      ReviewCategory.accuracy => l10n.reviewCategoryAccuracy,
      ReviewCategory.condition => l10n.reviewCategoryCondition,
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bookingAsync = ref.watch(bookingByIdProvider(widget.bookingId));
    final String? currentUserId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
    final submitState = ref.watch(submitReviewControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reviewScreenTitle)),
      body: bookingAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: SkeletonCard(),
        ),
        error: (error, stack) => ErrorStateView(
          failure: Failure.from(error),
          onRetry: () => ref.invalidate(bookingByIdProvider(widget.bookingId)),
        ),
        data: (booking) {
          if (booking == null || currentUserId == null) {
            return const SizedBox.shrink();
          }
          final bool isOwner = booking.isOwner(currentUserId);
          final String revieweeId = isOwner ? booking.renterId : booking.ownerId;
          final ReviewerRole role = isOwner ? ReviewerRole.owner : ReviewerRole.renter;
          final String? revieweeName = isOwner ? booking.renterDisplayName : booking.ownerDisplayName;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                l10n.reviewForCounterpartyLabel(revieweeName ?? ''),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              Center(
                child: StarRating(
                  rating: _overallRating,
                  size: 40,
                  onChanged: (value) => setState(() => _overallRating = value),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(l10n.reviewCategoriesLabel, style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              for (final category in ReviewCategory.values)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_categoryLabel(l10n, category), style: theme.textTheme.bodyMedium),
                      StarRating(
                        rating: _categoryRatings[category] ?? 5,
                        size: 20,
                        onChanged: (value) => setState(() => _categoryRatings[category] = value),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.xl),
              Text(l10n.reviewCommentLabel, style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _commentController,
                maxLines: 4,
                decoration: InputDecoration(hintText: l10n.reviewCommentHint),
              ),
              const SizedBox(height: AppSpacing.xxl),
              PrimaryButton(
                label: l10n.reviewSubmitAction,
                isLoading: submitState.isSubmitting,
                onPressed: () => _submit(revieweeId: revieweeId, role: role),
              ),
            ],
          );
        },
      ),
    );
  }
}
