import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/app/localization/app_localizations.dart';
import 'package:huvalts/features/notifications/domain/entities/app_notification.dart';
import 'package:huvalts/features/notifications/presentation/widgets/notification_copy.dart';

AppNotification _notification({
  String eventType = 'new_message',
  String title = 'DB title',
  String body = '',
}) {
  return AppNotification(
    id: 'notification-1',
    userId: 'user-1',
    eventType: eventType,
    title: title,
    body: body,
    deepLink: '/booking/booking-1',
    readAt: null,
    createdAt: DateTime(2026, 8, 17),
  );
}

void main() {
  final l10n = AppLocalizations(const Locale('mn'));

  test('known event types get localized copy, not the raw DB fallback', () {
    final (title, _) = notificationCopy(_notification(eventType: 'booking_confirmed'), l10n);
    expect(title, l10n.notificationBookingConfirmedTitle);
    expect(title, isNot('DB title'));
  });

  test('new_message falls back to a generic body when the stored body is empty', () {
    final (title, body) = notificationCopy(_notification(eventType: 'new_message', body: ''), l10n);
    expect(title, l10n.notificationNewMessageTitle);
    expect(body, l10n.notificationNewMessageBody);
  });

  test('new_message uses the stored preview when non-empty', () {
    final (_, body) = notificationCopy(
      _notification(eventType: 'new_message', body: 'Сайн байна уу'),
      l10n,
    );
    expect(body, 'Сайн байна уу');
  });

  test('unrecognized event types fall back to the row\'s own title/body', () {
    final (title, body) = notificationCopy(
      _notification(eventType: 'some_future_event', title: 'Fallback title', body: 'Fallback body'),
      l10n,
    );
    expect(title, 'Fallback title');
    expect(body, 'Fallback body');
  });

  test('icon mapping covers every known event type without throwing', () {
    for (final type in [
      'new_message',
      'booking_pending',
      'booking_confirmed',
      'booking_rejected',
      'booking_cancelled',
      'payment_succeeded',
      'payment_received',
      'payment_failed',
      'unknown_type',
    ]) {
      expect(notificationIcon(type), isNotNull);
    }
  });
}
