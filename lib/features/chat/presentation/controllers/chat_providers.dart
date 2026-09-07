import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/repositories/supabase_chat_repository.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/chat_repository.dart';

final Provider<ChatRepository> chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return SupabaseChatRepository(ref.watch(supabaseClientProvider));
});

final conversationForBookingProvider =
    FutureProvider.family<Conversation, String>((ref, bookingId) {
  return ref.watch(chatRepositoryProvider).getOrCreateConversationForBooking(bookingId);
});

// `autoDispose`: without it, Riverpod never drops this provider once
// created, so the underlying Supabase Realtime channel
// (`SupabaseChatRepository.watchMessages`'s `controller.onCancel`, which
// calls `_client.removeChannel`) never loses its last listener and never
// fires — every conversation ever opened would leak its channel/socket
// subscription for the rest of the app's process lifetime.
final messagesStreamProvider =
    StreamProvider.autoDispose.family<List<Message>, String>((ref, conversationId) {
  return ref.watch(chatRepositoryProvider).watchMessages(conversationId);
});
