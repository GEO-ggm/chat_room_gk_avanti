enum MessageStatus { pending, sent, failed }

class Message {
  const Message({
    required this.clientId,
    required this.author,
    required this.text,
    required this.status,
    required this.createdAt,
    this.serverId,
  });

  final String clientId;
  final String? serverId;
  final String author;
  final String text;
  final MessageStatus status;
  final DateTime createdAt;

  Message copyWith({MessageStatus? status, String? serverId}) => Message(
        clientId: clientId,
        serverId: serverId ?? this.serverId,
        author: author,
        text: text,
        status: status ?? this.status,
        createdAt: createdAt,
      );
}
