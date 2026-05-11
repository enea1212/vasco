import '../entities/message_entity.dart';

abstract interface class IMessageRepository {
  Stream<List<ConversationEntity>> watchConversations(String userId);
  Stream<List<MessageEntity>> watchMessages(String conversationId);
  Future<void> sendMessage(String conversationId, MessageEntity message);
  Future<void> markAsRead(String conversationId, String userId);
}
