import 'dart:typed_data';

import '../entities/condition_report.dart';
import '../entities/condition_report_stage.dart';

abstract interface class ConditionReportRepository {
  /// Null if that stage hasn't been reported yet.
  Future<ConditionReport?> getReport(String bookingId, ConditionReportStage stage);

  /// Uploads [photos] to the private `condition-reports` bucket (best
  /// effort per photo, same "one failing doesn't fail the whole submit"
  /// posture as `SupabaseAssetRepository.createAsset`'s image loop), then
  /// inserts the report row. Server-side validation (booking must be in
  /// the right status; pickup requires an already-paid payment) happens
  /// in `validate_and_autoconfirm_condition_report` — see that trigger's
  /// header comment.
  Future<ConditionReport> submitReport({
    required String bookingId,
    required ConditionReportStage stage,
    required List<(Uint8List bytes, String fileExtension)> photos,
    String? notes,
  });

  /// The *other* participant's confirmation — calls `confirm_condition_report`.
  Future<ConditionReport> confirmReport(String reportId);

  /// A short-lived signed URL for a private `condition-reports` photo path.
  Future<String> signedPhotoUrl(String path);
}
