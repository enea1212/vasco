import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/message_model.dart';
import '../../domain/entities/message_entity.dart';

extension ConversationModelToEntity on ConversationModel {
  ConversationEntity toEntity() => ConversationEntity(
        id: id,
        participantIds: participantIds,
        lastMessage: lastMessage,
        lastMessageTime: lastMessageTime,
        lastMessageSenderId: lastMessageSenderId,
        unreadCount: unreadCount,
        isGroup: isGroup,
        name: name,
      );
}

extension MessageModelToEntity on MessageModel {
  MessageEntity toEntity() => MessageEntity(
        id: id,
        senderId: senderId,
        text: text,
        createdAt: createdAt,
      );
}

/// Factory din Map brut per conversație.
ConversationModel conversationModelFromMap(
    Map<String, dynamic> map, String id) =>
    ConversationModel(
      id: id,
      participantIds:
          List<String>.from(map['participantIds'] as List? ?? []),
      lastMessage: map['lastMessage'] as String? ?? '',
      lastMessageTime:
          (map['lastMessageTime'] as Timestamp?)?.toDate(),
      lastMessageSenderId:
          map['lastMessageSenderId'] as String? ?? '',
      unreadCount: Map<String, int>.from(
        ((map['unreadCount'] as Map<String, dynamic>?) ?? {})
            .map((k, v) => MapEntry(k, (v as num).toInt())),
      ),
      isGroup: map['isGroup'] as bool? ?? false,
      name: map['name'] as String?,
    );

/// Factory din Map brut per mesaj.
MessageModel messageModelFromMap(Map<String, dynamic> map, String id) =>
    MessageModel(
      id: id,
      senderId: map['senderId'] as String,
      text: map['text'] as String,
      createdAt:
          (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
