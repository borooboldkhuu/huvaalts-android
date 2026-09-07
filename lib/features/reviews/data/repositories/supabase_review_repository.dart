import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/review.dart';
import '../../domain/entities/reviewer_role.dart';
import '../../domain/repositories/review_repository.dart';

class SupabaseReviewRepository implements ReviewRepository {
  SupabaseReviewRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Review?> getMyReviewForBooking(String bookingId) async {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final Map<String, dynamic>? row = await _client
          .from('reviews')
          .select()
          .eq('booking_id', bookingId)
          .eq('reviewer_id', userId)
          .maybeSingle();
      if (row == null) return null;
      return _fromRow(row);
    } on PostgrestException catch (e) {
      throw UnknownException(message: e.message, cause: e);
    }
  }

  @override
  Future<List<Review>> getReviewsForUser(String userId) async {
    try {
      final List<Map<String, dynamic>> rows = await _client
          .from('reviews')
          .select()
          .eq('reviewee_id', userId)
          .order('created_at', ascending: false);
      return rows.map(_fromRow).toList();
    } on PostgrestException catch (e) {
      throw UnknownException(message: e.message, cause: e);
    }
  }

  @override
  Future<Review> submitReview({
    required String bookingId,
    required String revieweeId,
    required ReviewerRole role,
    required int rating,
    String? comment,
    Map<String, int> categoryScores = const {},
  }) async {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const UnauthorizedException(message: 'auth_required');
    }
    try {
      final Map<String, dynamic> row = await _client
          .from('reviews')
          .insert({
            'booking_id': bookingId,
            'reviewer_id': userId,
            'reviewee_id': revieweeId,
            'role': role.id,
            'rating': rating,
            'comment': comment,
            'category_scores': categoryScores,
          })
          .select()
          .single();
      return _fromRow(row);
    } on PostgrestException catch (e) {
      throw _mapInsertError(e);
    }
  }

  /// `reviews_insert_participant` (0002) raises Postgres's generic
  /// row-level-security-violation error (not a `RAISE EXCEPTION` with a
  /// friendly message, since it's a plain RLS `with check` clause, not a
  /// function) when the booking isn't `completed` yet or the caller isn't
  /// a participant — matched by Postgres error code `42501` rather than
  /// by message text. A duplicate review comes back as `23505` (unique
  /// violation on `reviews_booking_id_reviewer_id_key`).
  AppException _mapInsertError(PostgrestException e) {
    return switch (e.code) {
      '42501' => const ForbiddenException(message: 'booking_not_completed_or_not_participant'),
      '23505' => const ConflictException(message: 'already_reviewed'),
      _ => UnknownException(message: e.message, cause: e),
    };
  }

  Review _fromRow(Map<String, dynamic> row) {
    final Map<String, dynamic> rawScores =
        (row['category_scores'] as Map<String, dynamic>?) ?? const {};
    return Review(
      id: row['id'] as String,
      bookingId: row['booking_id'] as String,
      reviewerId: row['reviewer_id'] as String,
      revieweeId: row['reviewee_id'] as String,
      role: ReviewerRole.fromId(row['role'] as String),
      rating: row['rating'] as int,
      comment: row['comment'] as String?,
      categoryScores: rawScores.map((key, value) => MapEntry(key, (value as num).toInt())),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
