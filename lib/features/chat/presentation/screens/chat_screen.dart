import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../admin/domain/entities/report_target_type.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../reports/presentation/widgets/report_sheet.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../controllers/chat_providers.dart';
import '../controllers/send_message_controller.dart';

/// Per-booking chat (spec sections 23, 32). Reachable from Booking
/// Detail's "Мессеж" action. Text-only this phase — sending an image
/// needs the same Storage wiring the asset-create form uses for photos,
/// deferred (see README "Known issues"); `flaggedForReview` is rendered
/// but not acted on (no admin review queue exists until Phase 11).
class ChatScreen extends ConsumerWidget {
  const ChatScreen({required this.bookingId, super.key});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final conversationAsync = ref.watch(conversationForBookingProvider(bookingId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.chatTitle)),
      body: conversationAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => ErrorStateView(
          failure: Failure.from(error),
          onRetry: () => ref.invalidate(conversationForBookingProvider(bookingId)),
        ),
        data: (conversation) => _ChatThread(conversation: conversation),
      ),
    );
  }
}

class _ChatThread extends ConsumerStatefulWidget {
  const _ChatThread({required this.conversation});

  final Conversation conversation;

  @override
  ConsumerState<_ChatThread> createState() => _ChatThreadState();
}

class _ChatThreadState extends ConsumerState<_ChatThread> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Best-effort — a failed read-receipt update shouldn't block the chat.
    ref.read(chatRepositoryProvider).markRead(widget.conversation.id).catchError((_) {});
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final String body = _controller.text.trim();
    if (body.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    try {
      await ref
          .read(sendMessageControllerProvider.notifier)
          .submit(conversationId: widget.conversation.id, body: body);
      _controller.clear();
    } catch (e) {
      if (!mounted) return;
      final AppLocalizations l10n = AppLocalizations.of(context);
      final (_, message) = failurePresentation(Failure.from(e), l10n);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? currentUserId = ref.watch(authControllerProvider).value?.id;
    final messagesAsync = ref.watch(messagesStreamProvider(widget.conversation.id));

    return Column(
      children: [
        Expanded(
          child: messagesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => ErrorStateView(
              failure: Failure.from(error),
              onRetry: () => ref.invalidate(messagesStreamProvider(widget.conversation.id)),
            ),
            data: (messages) {
              if (messages.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Text(l10n.chatEmptyTitle, textAlign: TextAlign.center),
                  ),
                );
              }
              return ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final Message message = messages[messages.length - 1 - index];
                  final bool isMine = message.senderId != null && message.senderId == currentUserId;
                  return _MessageBubble(message: message, isMine: isMine);
                },
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    // Mirrors `messages_body_length`
                    // (`0018_security_and_consistency_hardening.sql`) — the
                    // server is the actual enforcement point; this just
                    // stops a user from typing past the limit only to have
                    // the send silently fail.
                    maxLength: 2000,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(hintText: l10n.chatComposerHint),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  onPressed: _isSending ? null : _send,
                  icon: _isSending
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final Message message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (message.senderId == null) {
      // System message — centered, no bubble.
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Center(
          child: Text(
            message.body ?? '',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final Color bubbleColor =
        isMine ? theme.colorScheme.primary : theme.colorScheme.primary.withOpacity(0.08);
    final Color textColor = isMine ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;

    final Widget bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message.body ?? '', style: theme.textTheme.bodyMedium?.copyWith(color: textColor)),
          const SizedBox(height: 2),
          Text(
            AppDateUtils.formatDateTime(message.createdAt),
            style: theme.textTheme.labelSmall?.copyWith(color: textColor.withOpacity(0.7)),
          ),
          if (message.flaggedForReview) ...[
            const SizedBox(height: 2),
            Text(
              l10n.chatFlaggedNotice,
              style: theme.textTheme.labelSmall?.copyWith(color: textColor.withOpacity(0.7)),
            ),
          ],
        ],
      ),
    );

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      // Reporting your own message makes no sense (mirrors the
      // `isOwnListing`/`isMine` gating already used for the asset-detail
      // report entry points) — only the other participant's bubbles get a
      // long-press handler at all.
      child: isMine
          ? bubble
          : GestureDetector(
              onLongPress: () => showReportSheet(
                context,
                targetType: ReportTargetType.message,
                targetId: message.id,
              ),
              child: bubble,
            ),
    );
  }
}
