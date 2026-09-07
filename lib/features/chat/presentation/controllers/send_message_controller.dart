import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/message.dart';
import 'chat_providers.dart';

class SendMessageState {
  const SendMessageState({this.isSubmitting = false});

  final bool isSubmitting;
}

/// Mirrors `BookingRequestController`/`RequestPayoutController` — a small
/// action-only controller so the submit-in-flight/failure paths are
/// unit-testable against a fake `ChatRepository`.
class SendMessageController extends Notifier<SendMessageState> {
  @override
  SendMessageState build() => const SendMessageState();

  Future<Message> submit({required String conversationId, required String body}) async {
    state = const SendMessageState(isSubmitting: true);
    try {
      return await ref.read(chatRepositoryProvider).sendMessage(
            conversationId: conversationId,
            body: body,
          );
    } finally {
      state = const SendMessageState(isSubmitting: false);
    }
  }
}

final NotifierProvider<SendMessageController, SendMessageState> sendMessageControllerProvider =
    NotifierProvider<SendMessageController, SendMessageState>(SendMessageController.new);
