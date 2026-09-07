import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/features/chat/domain/entities/conversation.dart';
import 'package:huvalts/features/chat/domain/entities/message.dart';
import 'package:huvalts/features/chat/domain/entities/message_kind.dart';
import 'package:huvalts/features/chat/domain/repositories/chat_repository.dart';
import 'package:huvalts/features/chat/presentation/controllers/chat_providers.dart';
import 'package:huvalts/features/chat/presentation/controllers/send_message_controller.dart';

Message _message({String id = 'message-1', String body = 'hello'}) {
  return Message(
    id: id,
    conversationId: 'conversation-1',
    senderId: 'user-1',
    kind: MessageKind.text,
    body: body,
    imagePath: null,
    flaggedForReview: false,
    createdAt: DateTime(2026, 8, 17),
  );
}

class _FakeChatRepository implements ChatRepository {
  ({String conversationId, String body})? lastSendArgs;
  Object? errorToThrow;

  @override
  Future<Conversation> getOrCreateConversationForBooking(String bookingId) async {
    return Conversation(
      id: 'conversation-1',
      bookingId: bookingId,
      assetId: 'asset-1',
      createdAt: DateTime(2026, 8, 17),
      updatedAt: DateTime(2026, 8, 17),
    );
  }

  @override
  Stream<List<Message>> watchMessages(String conversationId) => Stream.value(const []);

  @override
  Future<Message> sendMessage({required String conversationId, required String body}) async {
    lastSendArgs = (conversationId: conversationId, body: body);
    if (errorToThrow != null) throw errorToThrow!;
    return _message(body: body);
  }

  @override
  Future<void> markRead(String conversationId) async {}
}

void main() {
  test('submit forwards conversationId and body, returns the sent message', () async {
    final fake = _FakeChatRepository();
    final container = ProviderContainer(
      overrides: [chatRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    final controller = container.read(sendMessageControllerProvider.notifier);
    final message = await controller.submit(conversationId: 'conversation-1', body: 'Сайн байна уу');

    expect(message.body, 'Сайн байна уу');
    expect(fake.lastSendArgs?.conversationId, 'conversation-1');
    expect(fake.lastSendArgs?.body, 'Сайн байна уу');
    expect(controller.state.isSubmitting, isFalse, reason: 'must reset after completing');
  });

  test('isSubmitting is true only while the call is in flight', () async {
    final fake = _FakeChatRepository();
    final container = ProviderContainer(
      overrides: [chatRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    final controller = container.read(sendMessageControllerProvider.notifier);
    expect(controller.state.isSubmitting, isFalse);

    final future = controller.submit(conversationId: 'conversation-1', body: 'hi');
    expect(controller.state.isSubmitting, isTrue);

    await future;
    expect(controller.state.isSubmitting, isFalse);
  });

  test('rethrows on failure and still resets isSubmitting', () async {
    final fake = _FakeChatRepository()..errorToThrow = Exception('network_error');
    final container = ProviderContainer(
      overrides: [chatRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    final controller = container.read(sendMessageControllerProvider.notifier);

    await expectLater(
      controller.submit(conversationId: 'conversation-1', body: 'hi'),
      throwsException,
    );
    expect(controller.state.isSubmitting, isFalse);
  });
}
