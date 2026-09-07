import 'package:freezed_annotation/freezed_annotation.dart';

import 'condition_report_stage.dart';

part 'condition_report.freezed.dart';
part 'condition_report.g.dart';

/// A `public.condition_reports` row (spec section 25). `photoPaths` are
/// `condition-reports` Storage object paths, not URLs — that bucket is
/// private (see `supabase/migrations/0005_storage_buckets.sql`), so
/// display always goes through a signed URL
/// (`StorageUrls.signedConditionReportPhoto`), never a public one.
///
/// `confirmedByRenterAt`/`confirmedByOwnerAt` are set once each — the
/// submitter's own side is auto-confirmed at insert time
/// (`validate_and_autoconfirm_condition_report`), the other party confirms
/// via `confirm_condition_report`. Once both are non-null, a Postgres
/// trigger (`advance_booking_on_condition_report`,
/// `0010_condition_reports_reviews_disputes.sql`) advances the booking's
/// status — this entity never drives that transition client-side.
@freezed
abstract class ConditionReport with _$ConditionReport {
  const factory ConditionReport({
    required String id,
    required String bookingId,
    required ConditionReportStage stage,
    required String submittedBy,
    required List<String> photoPaths,
    required String? notes,
    required DateTime? confirmedByRenterAt,
    required DateTime? confirmedByOwnerAt,
    required DateTime createdAt,
  }) = _ConditionReport;

  factory ConditionReport.fromJson(Map<String, dynamic> json) =>
      _$ConditionReportFromJson(json);
}

extension ConditionReportViewHelpers on ConditionReport {
  bool get isFullyConfirmed => confirmedByRenterAt != null && confirmedByOwnerAt != null;

  /// Whether [userId] (one of the booking's two participants — the caller
  /// is expected to already know that) still needs to confirm this report.
  bool needsConfirmationFrom({
    required String userId,
    required String renterId,
    required String ownerId,
  }) {
    if (userId == renterId) return confirmedByRenterAt == null;
    if (userId == ownerId) return confirmedByOwnerAt == null;
    return false;
  }
}
