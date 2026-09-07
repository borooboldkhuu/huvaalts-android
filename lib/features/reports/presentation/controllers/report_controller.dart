import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../admin/domain/entities/report_target_type.dart';
import '../../data/repositories/supabase_report_repository.dart';
import '../../domain/repositories/report_repository.dart';

final Provider<ReportRepository> reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return SupabaseReportRepository(ref.watch(supabaseClientProvider));
});

class ReportSubmitState {
  const ReportSubmitState({this.isSubmitting = false});

  final bool isSubmitting;
}

/// Drives [showReportSheet] — a single-shot submit, same shape as
/// `IdentityDetailsController`/`RequestPayoutController`.
class ReportController extends Notifier<ReportSubmitState> {
  @override
  ReportSubmitState build() => const ReportSubmitState();

  Future<void> submit({
    required ReportTargetType targetType,
    required String targetId,
    required String reason,
    String? details,
  }) async {
    state = const ReportSubmitState(isSubmitting: true);
    try {
      await ref.read(reportRepositoryProvider).submit(
            targetType: targetType,
            targetId: targetId,
            reason: reason,
            details: details,
          );
    } finally {
      state = const ReportSubmitState(isSubmitting: false);
    }
  }
}

final NotifierProvider<ReportController, ReportSubmitState> reportControllerProvider =
    NotifierProvider<ReportController, ReportSubmitState>(ReportController.new);
