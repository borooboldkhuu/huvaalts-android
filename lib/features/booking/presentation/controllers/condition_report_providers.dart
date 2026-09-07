import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/repositories/supabase_condition_report_repository.dart';
import '../../domain/entities/condition_report.dart';
import '../../domain/entities/condition_report_stage.dart';
import '../../domain/repositories/condition_report_repository.dart';

final Provider<ConditionReportRepository> conditionReportRepositoryProvider =
    Provider<ConditionReportRepository>((ref) {
  return SupabaseConditionReportRepository(ref.watch(supabaseClientProvider));
});

typedef ConditionReportKey = ({String bookingId, ConditionReportStage stage});

final conditionReportProvider =
    FutureProvider.family<ConditionReport?, ConditionReportKey>((ref, key) {
  return ref.watch(conditionReportRepositoryProvider).getReport(key.bookingId, key.stage);
});

/// Cached per storage path so an unrelated rebuild of the photo strip
/// (e.g. `conditionReportProvider` being invalidated after a `confirm()`
/// call) doesn't re-request a fresh signed URL and flash every thumbnail
/// back to its skeleton loader — see `_SignedConditionReportPhoto` in
/// `condition_report_screen.dart`. `autoDispose` (rather than caching
/// forever) so a stale entry can't outlive the 10-minute signed URL
/// (`signedPhotoUrl`) once nothing on screen is watching it anymore.
final signedConditionReportPhotoUrlProvider =
    FutureProvider.autoDispose.family<String, String>((ref, path) {
  return ref.watch(conditionReportRepositoryProvider).signedPhotoUrl(path);
});
