import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api/chat_api.dart';
import 'logic/chat_provider.dart';
import 'model/message.dart';

class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(chatControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(chatId)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[messages.length - 1 - index];
                  return MessageBubble(key: ValueKey(message.clientId), message: message);
                },
              ),
            ),
            const Divider(height: 1),
            const MessageInput(),
          ],
        ),
      ),
    );
  }
}

class MessageBubble extends ConsumerWidget {
  const MessageBubble({super.key, required this.message});

  final Message message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMyMessage = message.author == currentUser;
    final isFailed = message.status == MessageStatus.failed;
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: isMyMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        // Тап по иконке ошибки или по самому сообщению открывает шторку действий.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: isFailed ? () => _showFailedActions(context, ref) : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (message.status case MessageStatus.failed) ...[
                Icon(Icons.error_outline, size: 18, color: scheme.error),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: 72,
                    maxWidth: MediaQuery.sizeOf(context).width * 0.8,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: isMyMessage ? scheme.primaryContainer : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                      // IntrinsicWidth + stretch: пузырь по ширине самого широкого
                      // ребёнка, а строка времени прижимается к правому краю.
                      child: IntrinsicWidth(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!isMyMessage)
                              Text(message.author, style: Theme.of(context).textTheme.labelMedium),
                            Text(message.text),
                            const SizedBox(height: 2),
                            _MessageFooter(message: message, showStatus: isMyMessage),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showFailedActions(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(chatControllerProvider.notifier);
    final action = await showModalBottomSheet<_FailedAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Повторить отправку'),
              onTap: () => Navigator.pop(context, _FailedAction.retry),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
              title: Text('Удалить', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () => Navigator.pop(context, _FailedAction.delete),
            ),
          ],
        ),
      ),
    );
    switch (action) {
      case _FailedAction.retry:
        controller.retry(message.clientId);
      case _FailedAction.delete:
        controller.delete(message.clientId);
      case null:
        break;
    }
  }
}

enum _FailedAction { retry, delete }

/// Нижняя строка пузыря: время отправки и (для своих сообщений) статус.
class _MessageFooter extends StatelessWidget {
  const _MessageFooter({required this.message, required this.showStatus});

  final Message message;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    final time = TimeOfDay.fromDateTime(message.createdAt);
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('$hh:$mm', style: theme.textTheme.labelSmall?.copyWith(color: color)),
        if (showStatus) ...[
          const SizedBox(width: 4),
          // Фиксированный размер, чтобы при смене статуса строка не «прыгала».
          SizedBox.square(
            dimension: 14,
            child: switch (message.status) {
              MessageStatus.pending => Padding(
                padding: const EdgeInsets.all(2),
                child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
              ),
              MessageStatus.sent => Icon(Icons.done, size: 14, color: color),
              // Ошибка показывается иконкой слева от пузыря.
              MessageStatus.failed => const SizedBox.shrink(),
            },
          ),
        ],
      ],
    );
  }
}

class MessageInput extends ConsumerStatefulWidget {
  const MessageInput({super.key});

  @override
  ConsumerState<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends ConsumerState<MessageInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final created = ref.read(chatControllerProvider.notifier).send(_controller.text);
    if (created) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                hintText: 'Сообщение',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onTapOutside: (event) => FocusManager.instance.primaryFocus?.unfocus(),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, _) => IconButton(
              tooltip: 'Отправить',
              icon: const Icon(Icons.send),
              onPressed: value.text.trim().isEmpty ? null : _submit,
            ),
          ),
        ],
      ),
    );
  }
}
