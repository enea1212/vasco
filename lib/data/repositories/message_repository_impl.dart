// ignore_for_file: avoid_dynamic_calls
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/i_message_repository.dart';
// injected - see data/datasources/remote/message_remote_datasource.dart
import '../models/message_model_ext.dart';

class MessageRepositoryImpl implements IMessageRepository {
  const MessageRepositoryImpl(this._datasource);

  /// MessageRemoteDatasource — typed as dynamic until Fase 2A file is created.
  final dynamic _datasource;

  @override
  Stream<List<ConversationEntity>> watchConversations(String userId) {
    return (_datasource.watchConversations(userId)
            as Stream<List<Map<String, dynamic>>>)
        .map((maps) => maps
            .map((m) =>
                conversationModelFromMap(m, m['id'] as String? ?? '').toEntity())
            .toList());
  }

  @override
  Stream<List<MessageEntity>> watchMessages(String conversationId) {
    return (_datasource.watchMessages(conversationId)
            as Stream<List<Map<String, dynamic>>>)
        .map((maps) => maps
            .map((m) =>
                messageModelFromMap(m, m['id'] as String? ?? '').toEntity())
            .toList());
  }

  @override
  Future<void> sendMessage(
      String conversationId, MessageEntity message) async {
    await _datasource.sendMessage(conversationId, _messageToMap(message));
  }

  @override
  Future<void> markAsRead(String conversationId, String userId) async {
    await _datasource.markAsRead(conversationId, userId);
  }

  Map<String, dynamic> _messageToMap(MessageEntity m) => {
        'senderId': m.senderId,
        'text': m.text,
        'createdAt': m.createdAt,
      };
}
