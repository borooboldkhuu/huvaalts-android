import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/repositories/supabase_review_repository.dart';
import '../../domain/entities/review.dart';
import '../../domain/repositories/review_repository.dart';

final Provider<ReviewRepository> reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return SupabaseReviewRepository(ref.watch(supabaseClientProvider));
});

final myReviewForBookingProvider =
    FutureProvider.family<Review?, String>((ref, bookingId) {
  return ref.watch(reviewRepositoryProvider).getMyReviewForBooking(bookingId);
});

final reviewsForUserProvider =
    FutureProvider.family<List<Review>, String>((ref, userId) {
  return ref.watch(reviewRepositoryProvider).getReviewsForUser(userId);
});
