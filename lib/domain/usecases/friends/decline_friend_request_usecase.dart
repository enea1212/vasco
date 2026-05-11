import '../../repositories/i_friend_repository.dart';

class DeclineFriendRequestUsecase {
  const DeclineFriendRequestUsecase(this._repo);

  final IFriendRepository _repo;

  Future<void> call(String requestId) =>
      _repo.declineFriendRequest(requestId);
}
