import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';

class SupabaseNotificationRepository implements NotificationRepository {
  SupabaseNotificationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<AppNotification>> getNotifications(String userId) async {
    try {
      final List<Map<String, dynamic>> rows = await _client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return rows.map(_fromRow).toList();
    } on PostgrestException catch (e) {
      throw UnknownException(message: e.message, cause: e);
    }
  }

  @override
  Future<void> markRead(String notificationId) async {
    try {
      await _client
          .from('notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', notificationId);
    } on PostgrestException catch (e) {
      throw UnknownException(message: e.message, cause: e);
    }
  }

  @override
  Future<void> markAllRead(String userId) async {
    try {
      await _client
          .from('notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('user_id', userId)
          .filter('read_at', 'is', null);
    } on PostgrestException catch (e) {
      throw UnknownException(message: e.message, cause: e);
    }
  }

  @override
  Stream<int> watchUnreadCount(String userId) {
    final StreamController<int> controller = StreamController<int>.broadcast();
    RealtimeChannel? channel;

    // Re-fetches the full list and counts client-side on every change
    // rather than relying on a server-side count query — simpler, and
    // fine at the notification volumes a single user accrues (same
    // "not paginated" reasoning as `getNotifications`/`WalletRepository`).
    Future<void> recompute() async {
      try {
        final List<AppNotification> all = await getNotifications(userId);
        final int unread = all.where((n) => n.readAt == null).length;
        if (!controller.isClosed) controller.add(unread);
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    controller.onListen = () {
      recompute();
      channel = _client
          .channel('notifications-$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) => recompute(),
          )
          .subscribe();
    };
    controller.onCancel = () {
      final RealtimeChannel? c = channel;
      if (c != null) _client.removeChannel(c);
    };

    return controller.stream;
  }

  AppNotification _fromRow(Map<String, dynamic> row) {
    return AppNotification(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      eventType: row['event_type'] as String,
      title: row['title'] as String,
      body: row['body'] as String,
      deepLink: row['deep_link'] as String?,
      readAt: row['read_at'] == null ? null : DateTime.parse(row['read_at'] as String),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
