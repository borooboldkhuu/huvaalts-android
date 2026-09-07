import 'package:freezed_annotation/freezed_annotation.dart';

import 'message_kind.dart';

part 'message.freezed.dart';
part 'message.g.dart';

/// A `public.messages` row. `flaggedForReview` is computed server-side by
/// the `flag_suspicious_message` trigger
/// (`supabase/migrations/0009_chat_notifications.sql`) — never trust
/// whatever the client sent for it, and this entity doesn't expose a way
/// to set it either.
@freezed
abstract class Message with _$Message {
  const factory Message({
    required String id,
    required String conversationId,

    /// Null means a system message (spec: `sender_id ... -- null = system message`).
    required String? senderId,
    required MessageKind kind,
    required String? body,
    required String? imagePath,
    required bool flaggedForReview,
    required DateTime createdAt,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) => _$MessageFromJson(json);
}
