import '../../entities/message_entity.dart';
import '../../repositories/i_message_repository.dart';

class SendMessageUsecase {
  const SendMessageUsecase(this._repo);

  final IMessageRepository _repo;

  Future<void> call(String conversationId, MessageEntity message) =>
      _repo.sendMessage(conversationId, message);
}
