class MatchEntity {
  const MatchEntity({
    required this.id,
    required this.users,
    this.timestamp,
    this.lastMessage,
    this.lastMessageTime,
  });

  final String id;
  final List<String> users;
  final DateTime? timestamp;
  final String? lastMessage;
  final DateTime? lastMessageTime;
}
