class ConversationEntity {
  const ConversationEntity({
    required this.id,
    required this.participantIds,
    required this.lastMessage,
    this.lastMessageTime,
    required this.lastMessageSenderId,
    required this.unreadCount,
    this.isGroup = false,
    this.name,
  });

  final String id;
  final List<String> participantIds;
  final String lastMessage;
  final DateTime? lastMessageTime;
  final String lastMessageSenderId;
  final Map<String, int> unreadCount;
  final bool isGroup;
  final String? name;
}

class MessageEntity {
  const MessageEntity({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;
}
