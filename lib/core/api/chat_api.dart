import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../feature/chat/model/message.dart';

const chatId = 'room1';
const currentUser = 'me';

class SendException implements Exception {
  const SendException(this.message);
  final String message;
  @override
  String toString() => 'SendException: $message';
}

class FakeChatApi {
  FakeChatApi({this.delay = const Duration(milliseconds: 800)});

  final Duration delay;
  final Map<String, int> _attempts = {};
  int _nextServerId = 100;

  List<Message> loadHistory() {
    final base = DateTime.now().subtract(const Duration(hours: 1));
    const seed = [
      ('m1', 'Анна', 'Привет! Это room1.'),
      ('m2', 'Борис', 'Привет, Анна.'),
      ('m3', 'Анна', 'Созвон в 15:00 в силе?'),
      ('m4', currentUser, 'Да, буду.'),
      ('m5', 'Борис', 'Я тоже подключусь.'),
      ('m6', 'Анна', 'Отлично, ссылку скину позже.'),
      ('m7', currentUser, 'Спасибо!'),
    ];
    return [
      for (final (i, (id, author, text)) in seed.indexed)
        Message(
          clientId: id,
          serverId: id,
          author: author,
          text: text,
          status: MessageStatus.sent,
          createdAt: base.add(Duration(minutes: i * 5)),
        ),
    ];
  }

  Future<String> send({required String clientId, required String text}) async {
    final attempt = _attempts.update(clientId, (n) => n + 1, ifAbsent: () => 1);
    await Future<void>.delayed(delay);
    if (attempt == 1) {
      throw const SendException('Сеть недоступна');
    }
    return 's${_nextServerId++}';
  }
}

final chatApiProvider = Provider<FakeChatApi>((ref) => FakeChatApi());
