import 'package:freezed_annotation/freezed_annotation.dart';

import 'dispute_category.dart';
import 'dispute_status.dart';

part 'dispute.freezed.dart';
part 'dispute.g.dart';

/// A `public.disputes` row (spec section 26). Raising one flips the
/// booking's status to `disputed` and blocks new condition reports on it
/// (`mark_booking_disputed`, `validate_and_autoconfirm_condition_report` —
/// `0010_condition_reports_reviews_disputes.sql`); resolving/rejecting one
/// restores whatever status the booking had before. `evidencePaths` are
/// private `dispute-evidence` Storage object paths, same signed-URL-only
/// access pattern as condition report photos.
@freezed
abstract class Dispute with _$Dispute {
  const factory Dispute({
    required String id,
    required String bookingId,
    required String raisedBy,
    required DisputeCategory category,
    required String description,
    required List<String> evidencePaths,
    required DisputeStatus status,
    required String? resolutionNotes,
    required String? resolvedBy,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Dispute;

  factory Dispute.fromJson(Map<String, dynamic> json) => _$DisputeFromJson(json);
}
