import 'package:freezed_annotation/freezed_annotation.dart';

import 'reviewer_role.dart';

part 'review.freezed.dart';
part 'review.g.dart';

/// A `public.reviews` row (spec section 27). Only ever insertable once a
/// booking reaches `completed` (`reviews_insert_participant` RLS,
/// `0002_rls_policies.sql`) — that status is finally reachable as of
/// `0010_condition_reports_reviews_disputes.sql`'s pickup/return flow.
/// `categoryScores` is a small fixed set this app defines client-side
/// (communication / accuracy / condition — see `ReviewCategory`), stored
/// as the `jsonb` the column already supports rather than needing its own
/// migration.
@freezed
abstract class Review with _$Review {
  const factory Review({
    required String id,
    required String bookingId,
    required String reviewerId,
    required String revieweeId,
    required ReviewerRole role,
    required int rating,
    required String? comment,
    required Map<String, int> categoryScores,
    required DateTime createdAt,
  }) = _Review;

  factory Review.fromJson(Map<String, dynamic> json) => _$ReviewFromJson(json);
}
