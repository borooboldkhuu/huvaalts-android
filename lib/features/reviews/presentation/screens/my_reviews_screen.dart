import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../../../../shared/widgets/star_rating.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/review.dart';
import '../controllers/review_providers.dart';

/// Reviews the signed-in user has *received* (spec section 27) — reached
/// by tapping the "Reviews" stat on Profile, the same pattern as tapping
/// "Assets" opens My Assets. `profiles.review_count` (shown there) and
/// this list are both finally populated as of Phase 9's
/// `update_profile_rating_on_review` trigger — before that, every
/// profile's review count sat at its default of 0 because nothing could
/// insert a review.
class MyReviewsScreen extends ConsumerWidget {
  const MyReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? userId = ref.watch(authControllerProvider).value?.id;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.profileReviews)),
        body: EmptyState(title: l10n.authSignedOut, icon: Icons.star_border_rounded),
      );
    }

    final reviewsAsync = ref.watch(reviewsForUserProvider(userId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileReviews)),
      body: reviewsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: SkeletonCard(),
        ),
        error: (error, stack) => ErrorStateView(
          failure: Failure.from(error),
          onRetry: () => ref.invalidate(reviewsForUserProvider(userId)),
        ),
        data: (reviews) {
          if (reviews.isEmpty) {
            return EmptyState(title: l10n.myReviewsEmptyTitle, icon: Icons.star_border_rounded);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: reviews.length,
            separatorBuilder: (_, __) => const Divider(height: AppSpacing.xl),
            itemBuilder: (context, index) => _ReviewTile(review: reviews[index]),
          );
        },
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            StarRating(rating: review.rating, size: 18),
            Text(
              AppDateUtils.formatShortDate(review.createdAt),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        if (review.comment != null && review.comment!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(review.comment!, style: theme.textTheme.bodyMedium),
        ],
      ],
    );
  }
}
