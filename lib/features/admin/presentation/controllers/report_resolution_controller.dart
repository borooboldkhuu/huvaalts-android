import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/report.dart';
import '../../domain/entities/report_status.dart';
import 'admin_providers.dart';

class ReportResolutionState {
  const ReportResolutionState({this.isSubmitting = false});

  final bool isSubmitting;
}

class ReportResolutionController extends Notifier<ReportResolutionState> {
  @override
  ReportResolutionState build() => const ReportResolutionState();

  Future<Report> resolve({required String reportId, required ReportStatus newStatus}) async {
    state = const ReportResolutionState(isSubmitting: true);
    try {
      final Report result =
          await ref.read(adminRepositoryProvider).resolveReport(reportId: reportId, newStatus: newStatus);
      ref.invalidate(adminOpenReportsProvider);
      return result;
    } finally {
      state = const ReportResolutionState(isSubmitting: false);
    }
  }
}

final NotifierProvider<ReportResolutionController, ReportResolutionState>
    reportResolutionControllerProvider =
    NotifierProvider<ReportResolutionController, ReportResolutionState>(ReportResolutionController.new);
