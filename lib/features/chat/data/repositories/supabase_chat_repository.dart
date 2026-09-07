import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/message_kind.dart';
import '../../domain/repositories/chat_repository.dart';

class SupabaseChatRepository implements ChatRepository {
  SupabaseChatRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Conversation> getOrCreateConversationForBooking(String bookingId) async {
    try {
      final dynamic response = await _client.rpc<dynamic>(
        'get_or_create_conversation_for_booking',
        params: {'p_booking_id': bookingId},
      );
      return _conversationFromRow((response as Map).cast<String, dynamic>());
    } on PostgrestException catch (e) {
      throw _mapRpcError(e);
    }
  }

  @override
  Stream<List<Message>> watchMessages(String conversationId) {
    final StreamController<List<Message>> controller = StreamController<List<Message>>.broadcast();
    List<Message> current = [];
    RealtimeChannel? channel;

    Future<void> init() async {
      try {
        final List<Map<String, dynamic>> rows = await _client
            .from('messages')
            .select()
            .eq('conversation_id', conversationId)
            .order('created_at');
        current = rows.map(_messageFromRow).toList();
        if (!controller.isClosed) controller.add(List.unmodifiable(current));
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }

      // Verified against the supabase_flutter v2 Realtime API shape (not
      // exercised against a live project in this sandbox — see README
      // "Known issues" on the general "not actually run" caveat). If the
      // SDK's channel/filter API has moved since, this is the one spot
      // that needs updating; `watchMessages`'s return shape doesn't
      // change either way.
      channel = _client
          .channel('messages-$conversationId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'conversation_id',
              value: conversationId,
            ),
            callback: (payload) {
              final Message message = _messageFromRow(payload.newRecord);
              if (current.any((m) => m.id == message.id)) return;
              current = [...current, message];
              if (!controller.isClosed) controller.add(List.unmodifiable(current));
            },
          )
          .subscribe();
    }

    controller.onListen = init;
    controller.onCancel = () {
      final RealtimeChannel? c = channel;
      if (c != null) _client.removeChannel(c);
    };

    return controller.stream;
  }

  @override
  Future<Message> sendMessage({required String conversationId, required String body}) async {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const UnauthorizedException(message: 'auth_required');
    }
    try {
      final Map<String, dynamic> row = await _client
          .from('messages')
          .insert({
            'conversation_id': conversationId,
            'sender_id': userId,
            'kind': 'text',
            'body': body,
          })
          .select()
          .single();
      return _messageFromRow(row);
    } on PostgrestException catch (e) {
      throw UnknownException(message: e.message, cause: e);
    }
  }

  @override
  Future<void> markRead(String conversationId) async {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _client
          .from('conversation_members')
          .update({'last_read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('conversation_id', conversationId)
          .eq('user_id', userId);
    } on PostgrestException catch (e) {
      throw UnknownException(message: e.message, cause: e);
    }
  }

  AppException _mapRpcError(PostgrestException e) {
    return switch (e.message) {
      'auth_required' => const UnauthorizedException(message: 'auth_required'),
      'not_authorized' => const ForbiddenException(message: 'not_authorized'),
      'booking_not_found' => const NotFoundException(message: 'booking_not_found'),
      _ => UnknownException(message: e.message, cause: e),
    };
  }

  Conversation _conversationFromRow(Map<String, dynamic> row) {
    return Conversation(
      id: row['id'] as String,
      bookingId: row['booking_id'] as String?,
      assetId: row['asset_id'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  Message _messageFromRow(Map<String, dynamic> row) {
    return Message(
      id: row['id'] as String,
      conversationId: row['conversation_id'] as String,
      senderId: row['sender_id'] as String?,
      kind: MessageKind.fromId(row['kind'] as String? ?? 'text'),
      body: row['body'] as String?,
      imagePath: row['image_path'] as String?,
      flaggedForReview: row['flagged_for_review'] as bool? ?? false,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
