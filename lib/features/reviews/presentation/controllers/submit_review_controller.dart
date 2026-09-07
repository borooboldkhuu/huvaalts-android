import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/review.dart';
import '../../domain/entities/reviewer_role.dart';
import 'review_providers.dart';

class SubmitReviewState {
  const SubmitReviewState({this.isSubmitting = false});

  final bool isSubmitting;
}

/// Mirrors `SendMessageController`/`RequestPayoutController`'s
/// success/in-flight/failure shape — no other form state belongs here,
/// the screen owns rating/comment/category-score selection itself.
class SubmitReviewController extends Notifier<SubmitReviewState> {
  @override
  SubmitReviewState build() => const SubmitReviewState();

  Future<Review> submit({
    required String bookingId,
    required String revieweeId,
    required ReviewerRole role,
    required int rating,
    String? comment,
    Map<String, int> categoryScores = const {},
  }) async {
    state = const SubmitReviewState(isSubmitting: true);
    try {
      final Review review = await ref.read(reviewRepositoryProvider).submitReview(
            bookingId: bookingId,
            revieweeId: revieweeId,
            role: role,
            rating: rating,
            comment: comment,
            categoryScores: categoryScores,
          );
      state = const SubmitReviewState();
      return review;
    } catch (_) {
      state = const SubmitReviewState();
      rethrow;
    }
  }
}

final NotifierProvider<SubmitReviewController, SubmitReviewState> submitReviewControllerProvider =
    NotifierProvider<SubmitReviewController, SubmitReviewState>(SubmitReviewController.new);
