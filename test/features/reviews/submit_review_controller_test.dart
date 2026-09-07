import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/features/reviews/domain/entities/review.dart';
import 'package:huvalts/features/reviews/domain/entities/reviewer_role.dart';
import 'package:huvalts/features/reviews/domain/repositories/review_repository.dart';
import 'package:huvalts/features/reviews/presentation/controllers/review_providers.dart';
import 'package:huvalts/features/reviews/presentation/controllers/submit_review_controller.dart';

Review _review({int rating = 5}) {
  return Review(
    id: 'review-1',
    bookingId: 'booking-1',
    reviewerId: 'renter-1',
    revieweeId: 'owner-1',
    role: ReviewerRole.renter,
    rating: rating,
    comment: null,
    categoryScores: const {},
    createdAt: DateTime(2026, 8, 17),
  );
}

class _FakeReviewRepository implements ReviewRepository {
  Map<String, dynamic>? lastSubmitArgs;
  Object? errorToThrow;

  @override
  Future<Review?> getMyReviewForBooking(String bookingId) async => null;

  @override
  Future<List<Review>> getReviewsForUser(String userId) async => const [];

  @override
  Future<Review> submitReview({
    required String bookingId,
    required String revieweeId,
    required ReviewerRole role,
    required int rating,
    String? comment,
    Map<String, int> categoryScores = const {},
  }) async {
    lastSubmitArgs = {
      'bookingId': bookingId,
      'revieweeId': revieweeId,
      'role': role,
      'rating': rating,
      'comment': comment,
      'categoryScores': categoryScores,
    };
    if (errorToThrow != null) throw errorToThrow!;
    return _review(rating: rating);
  }
}

void main() {
  test('submit forwards every field and returns the created review', () async {
    final fake = _FakeReviewRepository();
    final container = ProviderContainer(
      overrides: [reviewRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    final controller = container.read(submitReviewControllerProvider.notifier);
    final review = await controller.submit(
      bookingId: 'booking-1',
      revieweeId: 'owner-1',
      role: ReviewerRole.renter,
      rating: 4,
      comment: 'Great experience',
      categoryScores: const {'communication': 5},
    );

    expect(review.rating, 4);
    expect(fake.lastSubmitArgs?['bookingId'], 'booking-1');
    expect(fake.lastSubmitArgs?['revieweeId'], 'owner-1');
    expect(fake.lastSubmitArgs?['role'], ReviewerRole.renter);
    expect(fake.lastSubmitArgs?['rating'], 4);
    expect(fake.lastSubmitArgs?['comment'], 'Great experience');
    expect(controller.state.isSubmitting, isFalse);
  });

  test('isSubmitting is true only while the call is in flight', () async {
    final fake = _FakeReviewRepository();
    final container = ProviderContainer(
      overrides: [reviewRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    final controller = container.read(submitReviewControllerProvider.notifier);
    expect(controller.state.isSubmitting, isFalse);

    final future = controller.submit(
      bookingId: 'booking-1',
      revieweeId: 'owner-1',
      role: ReviewerRole.renter,
      rating: 5,
    );
    expect(controller.state.isSubmitting, isTrue);

    await future;
    expect(controller.state.isSubmitting, isFalse);
  });

  test('rethrows on failure and still resets isSubmitting', () async {
    final fake = _FakeReviewRepository()..errorToThrow = Exception('already_reviewed');
    final container = ProviderContainer(
      overrides: [reviewRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    final controller = container.read(submitReviewControllerProvider.notifier);

    await expectLater(
      controller.submit(
        bookingId: 'booking-1',
        revieweeId: 'owner-1',
        role: ReviewerRole.renter,
        rating: 5,
      ),
      throwsException,
    );
    expect(controller.state.isSubmitting, isFalse);
  });
}
