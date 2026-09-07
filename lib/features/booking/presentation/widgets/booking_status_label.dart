import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/entities/booking_status.dart';

/// Localized label + a status color, kept together (like
/// `asset_option_labels.dart`) so the booking detail screen and the
/// booking list screens can't render a status with mismatched wording or
/// color for the same underlying value.
String bookingStatusLabel(BookingStatus status, AppLocalizations l10n) {
  return switch (status) {
    BookingStatus.pending => l10n.bookingStatusPending,
    BookingStatus.confirmed => l10n.bookingStatusConfirmed,
    BookingStatus.rejected => l10n.bookingStatusRejected,
    BookingStatus.cancelled => l10n.bookingStatusCancelled,
    BookingStatus.active => l10n.bookingStatusActive,
    BookingStatus.completed => l10n.bookingStatusCompleted,
    BookingStatus.disputed => l10n.bookingStatusDisputed,
  };
}

Color bookingStatusColor(BookingStatus status, AppColors colors) {
  return switch (status) {
    BookingStatus.pending => colors.warning,
    BookingStatus.confirmed => colors.accent,
    BookingStatus.active => colors.accent,
    BookingStatus.completed => colors.success,
    BookingStatus.rejected => colors.danger,
    BookingStatus.cancelled => colors.secondary,
    BookingStatus.disputed => colors.danger,
  };
}
