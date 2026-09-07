import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_notification.freezed.dart';
part 'app_notification.g.dart';

/// A `public.notifications` row. Named `AppNotification`, not
/// `Notification` — Flutter's `widgets.dart` already exports a
/// `Notification` base class (the bubbling-event one, e.g.
/// `ScrollNotification`), and this project avoids that class of
/// collision everywhere (see `AssetImage`'s doc comment for the
/// precedent).
///
/// [title]/[body] are a plain-English fallback only — the client renders
/// localized copy keyed off [eventType] when it recognizes one (see
/// `notification_copy.dart`), the same pattern `BookingStatus`/
/// `PaymentStatus` use, and only falls back to these columns otherwise.
/// In-app only: there is no push delivery (no Firebase Cloud Messaging
/// wiring — see README "Known issues"), so a notification is only ever
/// seen if the user opens this screen.
@freezed
abstract class AppNotification with _$AppNotification {
  const factory AppNotification({
    required String id,
    required String userId,
    required String eventType,
    required String title,
    required String body,
    required String? deepLink,
    required DateTime? readAt,
    required DateTime createdAt,
  }) = _AppNotification;

  factory AppNotification.fromJson(Map<String, dynamic> json) => _$AppNotificationFromJson(json);
}
