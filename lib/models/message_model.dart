import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationModel {
  final String id;
  final List<String> participantIds;
  final String lastMessage;
  final DateTime? lastMessageTime;
  final String lastMessageSenderId;
  final Map<String, int> unreadCount;
  final bool isGroup;
  final String? name;

  const ConversationModel({
    required this.id,
    required this.participantIds,
    required this.lastMessage,
    this.lastMessageTime,
    required this.lastMessageSenderId,
    required this.unreadCount,
    this.isGroup = false,
    this.name,
  });

  factory ConversationModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ConversationModel(
      id: doc.id,
      participantIds: List<String>.from(d['participantIds'] ?? []),
      lastMessage: d['lastMessage'] as String? ?? '',
      lastMessageTime: (d['lastMessageTime'] as Timestamp?)?.toDate(),
      lastMessageSenderId: d['lastMessageSenderId'] as String? ?? '',
      unreadCount: Map<String, int>.from(
        (d['unreadCount'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, (v as num).toInt()),
        ),
      ),
      isGroup: d['isGroup'] as bool? ?? false,
      name: d['name'] as String?,
    );
  }

  int unreadFor(String userId) => unreadCount[userId] ?? 0;
}

class MessageModel {
  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
  });

  factory MessageModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      senderId: d['senderId'] as String,
      text: d['text'] as String,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
