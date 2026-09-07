import '../entities/app_notification.dart';

abstract interface class NotificationRepository {
  /// Most recent first. Not paginated — see the same note on
  /// `WalletRepository.getTransactions`.
  Future<List<AppNotification>> getNotifications(String userId);

  Future<void> markRead(String notificationId);

  Future<void> markAllRead(String userId);

  /// Live unread count — an initial fetch, then updates on every insert
  /// or `read_at` change to this user's own notifications over Supabase
  /// Realtime. Backs the Home app bar's bell badge.
  Stream<int> watchUnreadCount(String userId);
}
