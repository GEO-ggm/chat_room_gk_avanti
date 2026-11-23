import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/chat_api.dart';
import '../model/message.dart';

class ChatController extends Notifier<List<Message>> {
  int _localSeq = 0;

  FakeChatApi get _api => ref.read(chatApiProvider);

  @override
  List<Message> build() => ref.read(chatApiProvider).loadHistory();

  bool send(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) return false;

    final message = Message(
      clientId: _newClientId(),
      author: currentUser,
      text: text,
      status: MessageStatus.pending,
      createdAt: DateTime.now(),
    );
    state = [...state, message];
    _deliver(message.clientId, text);
    return true;
  }

  void retry(String clientId) {
    final message = _find(clientId);
    if (message == null || message.status != MessageStatus.failed) return;
    _update(clientId, (m) => m.copyWith(status: MessageStatus.pending));
    _deliver(clientId, message.text);
  }

  /// Удаляет неотправленное сообщение. Как и повтор, доступно только
  /// для статуса failed: отправленные и отправляемые записи не трогаем.
  void delete(String clientId) {
    final message = _find(clientId);
    if (message == null || message.status != MessageStatus.failed) return;
    state = [
      for (final m in state)
        if (m.clientId != clientId) m,
    ];
  }

  Future<void> _deliver(String clientId, String text) async {
    try {
      final serverId = await _api.send(clientId: clientId, text: text);
      if (!ref.mounted) return;
      _update(clientId, (m) => m.copyWith(status: MessageStatus.sent, serverId: serverId));
    } on SendException {
      if (!ref.mounted) return;
      _update(clientId, (m) => m.copyWith(status: MessageStatus.failed));
    }
  }

  Message? _find(String clientId) {
    for (final m in state) {
      if (m.clientId == clientId) return m;
    }
    return null;
  }

  void _update(String clientId, Message Function(Message) change) {
    state = [for (final m in state) m.clientId == clientId ? change(m) : m];
  }

  String _newClientId() => 'c-${DateTime.now().microsecondsSinceEpoch}-${_localSeq++}';
}

final chatControllerProvider = NotifierProvider<ChatController, List<Message>>(ChatController.new);
