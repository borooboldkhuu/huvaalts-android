import 'package:freezed_annotation/freezed_annotation.dart';

part 'conversation.freezed.dart';
part 'conversation.g.dart';

/// A `public.conversations` row. This phase only ever creates
/// booking-linked conversations (via `get_or_create_conversation_for_booking`
/// — see `supabase/migrations/0009_chat_notifications.sql`), so
/// [bookingId] is effectively always non-null in practice even though
/// the column itself is nullable (a future asset-only inquiry thread,
/// with only [assetId] set, is a plausible use of the same table this
/// entity doesn't need to rule out).
@freezed
abstract class Conversation with _$Conversation {
  const factory Conversation({
    required String id,
    required String? bookingId,
    required String? assetId,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Conversation;

  factory Conversation.fromJson(Map<String, dynamic> json) => _$ConversationFromJson(json);
}
