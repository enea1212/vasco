import '../../repositories/i_friend_repository.dart';

class AcceptFriendRequestUsecase {
  const AcceptFriendRequestUsecase(this._repo);

  final IFriendRepository _repo;

  Future<void> call(String requestId, String fromUserId, String toUserId) =>
      _repo.acceptFriendRequest(requestId, fromUserId, toUserId);
}
