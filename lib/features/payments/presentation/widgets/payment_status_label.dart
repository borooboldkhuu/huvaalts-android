import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/entities/payment_status.dart';

String paymentStatusLabel(PaymentStatus status, AppLocalizations l10n) {
  return switch (status) {
    PaymentStatus.pending => l10n.paymentStatusPending,
    PaymentStatus.authorized => l10n.paymentStatusPending,
    PaymentStatus.paid => l10n.paymentStatusPaid,
    PaymentStatus.failed => l10n.paymentStatusFailed,
    PaymentStatus.cancelled => l10n.paymentStatusFailed,
    PaymentStatus.refunded => l10n.paymentStatusRefunded,
    PaymentStatus.partiallyRefunded => l10n.paymentStatusRefunded,
  };
}

Color paymentStatusColor(PaymentStatus status, AppColors colors) {
  return switch (status) {
    PaymentStatus.pending => colors.warning,
    PaymentStatus.authorized => colors.warning,
    PaymentStatus.paid => colors.success,
    PaymentStatus.failed => colors.danger,
    PaymentStatus.cancelled => colors.danger,
    PaymentStatus.refunded => colors.secondary,
    PaymentStatus.partiallyRefunded => colors.secondary,
  };
}
