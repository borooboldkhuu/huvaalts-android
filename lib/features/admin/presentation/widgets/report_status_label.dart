import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/entities/report_status.dart';
import '../../domain/entities/report_target_type.dart';

String reportStatusLabel(ReportStatus status, AppLocalizations l10n) {
  return switch (status) {
    ReportStatus.open => l10n.adminReportStatusOpen,
    ReportStatus.reviewed => l10n.adminReportStatusReviewed,
    ReportStatus.actioned => l10n.adminReportStatusActioned,
    ReportStatus.dismissed => l10n.adminReportStatusDismissed,
  };
}

Color reportStatusColor(ReportStatus status, AppColors colors) {
  return switch (status) {
    ReportStatus.open => colors.warning,
    ReportStatus.reviewed => colors.accent,
    ReportStatus.actioned => colors.success,
    ReportStatus.dismissed => colors.secondary,
  };
}

String reportTargetTypeLabel(ReportTargetType type, AppLocalizations l10n) {
  return switch (type) {
    ReportTargetType.user => l10n.adminReportTargetUser,
    ReportTargetType.asset => l10n.adminReportTargetAsset,
    ReportTargetType.message => l10n.adminReportTargetMessage,
    ReportTargetType.review => l10n.adminReportTargetReview,
  };
}
