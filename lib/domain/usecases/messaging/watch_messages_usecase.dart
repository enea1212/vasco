import '../../entities/message_entity.dart';
import '../../repositories/i_message_repository.dart';

class WatchMessagesUsecase {
  const WatchMessagesUsecase(this._repo);

  final IMessageRepository _repo;

  Stream<List<MessageEntity>> call(String conversationId) =>
      _repo.watchMessages(conversationId);
}
