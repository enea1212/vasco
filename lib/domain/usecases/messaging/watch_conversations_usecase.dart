import '../../entities/message_entity.dart';
import '../../repositories/i_message_repository.dart';

class WatchConversationsUsecase {
  const WatchConversationsUsecase(this._repo);

  final IMessageRepository _repo;

  Stream<List<ConversationEntity>> call(String userId) =>
      _repo.watchConversations(userId);
}
