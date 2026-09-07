import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../domain/entities/app_notification.dart';

/// Localized (title, body) for a known `event_type` — falls back to the
/// row's own plain-English `title`/`body` for anything this client
/// doesn't recognize (e.g. a future event type added server-side before
/// the app updates). See `AppNotification`'s header comment for why the
/// DB columns are a fallback rather than the primary copy.
(String, String) notificationCopy(AppNotification notification, AppLocalizations l10n) {
  return switch (notification.eventType) {
    'new_message' => (
        l10n.notificationNewMessageTitle,
        notification.body.isEmpty ? l10n.notificationNewMessageBody : notification.body,
      ),
    'booking_pending' => (l10n.notificationBookingPendingTitle, ''),
    'booking_confirmed' => (l10n.notificationBookingConfirmedTitle, ''),
    'booking_rejected' => (l10n.notificationBookingRejectedTitle, ''),
    'booking_cancelled' => (l10n.notificationBookingCancelledTitle, notification.body),
    'payment_succeeded' => (l10n.notificationPaymentSucceededTitle, ''),
    'payment_received' => (l10n.notificationPaymentReceivedTitle, ''),
    'payment_failed' => (l10n.notificationPaymentFailedTitle, ''),
    _ => (notification.title, notification.body),
  };
}

IconData notificationIcon(String eventType) {
  return switch (eventType) {
    'new_message' => Icons.chat_bubble_outline,
    'booking_pending' ||
    'booking_confirmed' ||
    'booking_rejected' ||
    'booking_cancelled' =>
      Icons.event_note_outlined,
    'payment_succeeded' || 'payment_received' || 'payment_failed' => Icons.payments_outlined,
    _ => Icons.notifications_none,
  };
}
