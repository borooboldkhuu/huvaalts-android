import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/repositories/supabase_notification_repository.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';

final Provider<NotificationRepository> notificationRepositoryProvider =
    Provider<NotificationRepository>((ref) {
  return SupabaseNotificationRepository(ref.watch(supabaseClientProvider));
});

final notificationsProvider =
    FutureProvider.family<List<AppNotification>, String>((ref, userId) {
  return ref.watch(notificationRepositoryProvider).getNotifications(userId);
});

// `autoDispose`: same reasoning as `messagesStreamProvider` in
// `chat_providers.dart` — without it this provider (and the Realtime
// channel `SupabaseNotificationRepository.watchUnreadCount` opens) is
// never released for the lifetime of the app process.
final unreadNotificationCountProvider =
    StreamProvider.autoDispose.family<int, String>((ref, userId) {
  return ref.watch(notificationRepositoryProvider).watchUnreadCount(userId);
});
