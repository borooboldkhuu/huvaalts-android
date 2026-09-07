import '../entities/review.dart';
import '../entities/reviewer_role.dart';

abstract interface class ReviewRepository {
  /// Null if the signed-in user hasn't reviewed this booking yet. Backs
  /// Booking Detail's "leave a review" vs. "you already reviewed this"
  /// distinction — `reviews_booking_id_reviewer_id_key`'s unique
  /// constraint (0001) is the authoritative guard either way.
  Future<Review?> getMyReviewForBooking(String bookingId);

  /// Reviews *received* by [userId], newest first — backs a profile's
  /// review list.
  Future<List<Review>> getReviewsForUser(String userId);

  Future<Review> submitReview({
    required String bookingId,
    required String revieweeId,
    required ReviewerRole role,
    required int rating,
    String? comment,
    Map<String, int> categoryScores,
  });
}
