import '../../repositories/i_friend_repository.dart';

class SendFriendRequestUsecase {
  const SendFriendRequestUsecase(this._repo);

  final IFriendRepository _repo;

  Future<void> call(String fromUserId, String toUserId) =>
      _repo.sendFriendRequest(fromUserId, toUserId);
}
