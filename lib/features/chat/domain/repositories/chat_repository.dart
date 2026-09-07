import '../entities/conversation.dart';
import '../entities/message.dart';

abstract interface class ChatRepository {
  /// Idempotent — returns the booking's existing conversation if one
  /// already exists, otherwise creates it (with both the renter and
  /// owner as members) via the `get_or_create_conversation_for_booking`
  /// RPC. Throws if the caller isn't a participant on the booking.
  Future<Conversation> getOrCreateConversationForBooking(String bookingId);

  /// Emits the full message list (oldest first) on every change — an
  /// initial fetch, then a running append as new messages arrive over
  /// Supabase Realtime. Never completes on its own; cancel the
  /// subscription (dispose the provider) to stop listening.
  Stream<List<Message>> watchMessages(String conversationId);

  Future<Message> sendMessage({required String conversationId, required String body});

  /// Updates the caller's own `conversation_members.last_read_at`. Silent
  /// no-op if the caller isn't signed in — read-tracking failing quietly
  /// shouldn't block anything else in the chat UI.
  Future<void> markRead(String conversationId);
}
