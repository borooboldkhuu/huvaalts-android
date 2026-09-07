import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/app_notification.dart';
import '../controllers/notification_providers.dart';
import '../widgets/notification_copy.dart';

/// The in-app notification center (spec section 24). No push delivery —
/// see `AppNotification`'s header comment — this is the only place these
/// ever surface this phase.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? userId = ref.watch(authControllerProvider).value?.id;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.notificationsTitle)),
        body: EmptyState(title: l10n.authSignedOut, icon: Icons.notifications_none),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notificationsTitle),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(notificationRepositoryProvider).markAllRead(userId);
              ref.invalidate(notificationsProvider(userId));
              ref.invalidate(unreadNotificationCountProvider(userId));
            },
            child: Text(l10n.notificationsMarkAllReadAction),
          ),
        ],
      ),
      body: _NotificationList(userId: userId),
    );
  }
}

class _NotificationList extends ConsumerWidget {
  const _NotificationList({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final notificationsAsync = ref.watch(notificationsProvider(userId));

    return notificationsAsync.when(
      loading: () => ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: 4,
        itemBuilder: (context, index) =>
            const Padding(padding: EdgeInsets.only(bottom: AppSpacing.md), child: SkeletonCard()),
      ),
      error: (error, stack) => ErrorStateView(
        failure: Failure.from(error),
        onRetry: () => ref.invalidate(notificationsProvider(userId)),
      ),
      data: (notifications) {
        if (notifications.isEmpty) {
          return EmptyState(title: l10n.notificationsEmptyTitle, icon: Icons.notifications_none);
        }
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: notifications.length,
          separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) => _NotificationTile(
            notification: notifications[index],
            userId: userId,
          ),
        );
      },
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification, required this.userId});

  final AppNotification notification;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bool isUnread = notification.readAt == null;
    final (String title, String body) = notificationCopy(notification, l10n);

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () async {
        if (isUnread) {
          await ref.read(notificationRepositoryProvider).markRead(notification.id);
          ref.invalidate(notificationsProvider(userId));
          ref.invalidate(unreadNotificationCountProvider(userId));
        }
        final String? deepLink = notification.deepLink;
        if (deepLink != null && context.mounted) {
          context.push(deepLink);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isUnread ? theme.colorScheme.primary.withOpacity(0.06) : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(notificationIcon(notification.eventType), size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(body, style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 4),
                  Text(AppDateUtils.formatDateTime(notification.createdAt), style: theme.textTheme.labelSmall),
                ],
              ),
            ),
            if (isUnread)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}
