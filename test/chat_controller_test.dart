import 'package:chat_room/core/api/chat_api.dart';
import 'package:chat_room/feature/chat/logic/chat_provider.dart';
import 'package:chat_room/feature/chat/model/message.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(overrides: [
      chatApiProvider.overrideWithValue(
        FakeChatApi(delay: const Duration(milliseconds: 10)),
      ),
    ]);
    addTearDown(container.dispose);
  });

  List<Message> messages() => container.read(chatControllerProvider);
  ChatController controller() => container.read(chatControllerProvider.notifier);

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 30));

  test('история room1 содержит 5–10 сообщений', () {
    expect(messages().length, inInclusiveRange(5, 10));
  });

  test('пустое и пробельное сообщение не отправляется', () {
    final before = messages().length;
    expect(controller().send(''), isFalse);
    expect(controller().send('   \n'), isFalse);
    expect(messages().length, before);
  });

  test('ошибка → повтор → успех: тот же clientId, без дублей', () async {
    final before = messages().length;
    controller().send('Привет');

    final created = messages().last;
    expect(messages().length, before + 1);
    expect(created.status, MessageStatus.pending);

    await settle();
    expect(messages().last.status, MessageStatus.failed);

    controller().retry(created.clientId);
    expect(messages().last.status, MessageStatus.pending);

    // Повтор во время отправки игнорируется.
    controller().retry(created.clientId);

    await settle();
    final result = messages().last;
    expect(result.status, MessageStatus.sent);
    expect(result.clientId, created.clientId);
    expect(result.serverId, isNotNull);
    expect(messages().length, before + 1);
    expect(messages().where((m) => m.clientId == created.clientId).length, 1);
  });

  test('удаление failed-сообщения убирает только его', () async {
    final before = messages().length;
    controller().send('Удалить меня');
    final created = messages().last;

    // Пока идёт отправка, удалить нельзя.
    controller().delete(created.clientId);
    expect(messages().length, before + 1);

    await settle();
    expect(messages().last.status, MessageStatus.failed);

    controller().delete(created.clientId);
    expect(messages().length, before);
    expect(messages().any((m) => m.clientId == created.clientId), isFalse);
  });

  test('отправленное сообщение удалить нельзя', () {
    final before = messages().length;
    controller().delete(messages().first.clientId);
    expect(messages().length, before);
  });

  test('повтор для отправленного сообщения ничего не делает', () {
    final sent = messages().first;
    controller().retry(sent.clientId);
    expect(messages().first.status, MessageStatus.sent);
  });
}
