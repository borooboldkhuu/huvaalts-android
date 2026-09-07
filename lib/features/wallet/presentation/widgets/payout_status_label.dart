import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/entities/payout_status.dart';

String payoutStatusLabel(PayoutStatus status, AppLocalizations l10n) {
  return switch (status) {
    PayoutStatus.pending => l10n.payoutStatusPending,
    PayoutStatus.processing => l10n.payoutStatusProcessing,
    PayoutStatus.paid => l10n.payoutStatusPaid,
    PayoutStatus.failed => l10n.payoutStatusFailed,
  };
}

Color payoutStatusColor(PayoutStatus status, AppColors colors) {
  return switch (status) {
    PayoutStatus.pending => colors.warning,
    PayoutStatus.processing => colors.warning,
    PayoutStatus.paid => colors.success,
    PayoutStatus.failed => colors.danger,
  };
}
