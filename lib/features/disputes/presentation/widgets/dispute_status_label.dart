import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/entities/dispute_category.dart';
import '../../domain/entities/dispute_status.dart';

String disputeStatusLabel(DisputeStatus status, AppLocalizations l10n) {
  return switch (status) {
    DisputeStatus.open => l10n.disputeStatusOpen,
    DisputeStatus.underReview => l10n.disputeStatusUnderReview,
    DisputeStatus.resolved => l10n.disputeStatusResolved,
    DisputeStatus.rejected => l10n.disputeStatusRejected,
    DisputeStatus.escalated => l10n.disputeStatusEscalated,
  };
}

Color disputeStatusColor(DisputeStatus status, AppColors colors) {
  return switch (status) {
    DisputeStatus.open || DisputeStatus.underReview || DisputeStatus.escalated => colors.warning,
    DisputeStatus.resolved => colors.success,
    DisputeStatus.rejected => colors.danger,
  };
}

String disputeCategoryLabel(DisputeCategory category, AppLocalizations l10n) {
  return switch (category) {
    DisputeCategory.itemDamaged => l10n.disputeCategoryItemDamaged,
    DisputeCategory.itemNotAsDescribed => l10n.disputeCategoryItemNotAsDescribed,
    DisputeCategory.lateReturn => l10n.disputeCategoryLateReturn,
    DisputeCategory.noShow => l10n.disputeCategoryNoShow,
    DisputeCategory.paymentIssue => l10n.disputeCategoryPaymentIssue,
    DisputeCategory.other => l10n.disputeCategoryOther,
  };
}
