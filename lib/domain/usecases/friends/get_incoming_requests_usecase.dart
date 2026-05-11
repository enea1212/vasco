import '../../entities/friend_request_entity.dart';
import '../../repositories/i_friend_repository.dart';

class GetIncomingRequestsUsecase {
  const GetIncomingRequestsUsecase(this._repo);

  final IFriendRepository _repo;

  Stream<List<FriendRequestEntity>> call(String userId) =>
      _repo.watchIncomingRequests(userId);
}
