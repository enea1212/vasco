import '../../repositories/i_friend_repository.dart';

class RemoveFriendUsecase {
  const RemoveFriendUsecase(this._repo);

  final IFriendRepository _repo;

  Future<void> call(String currentUserId, String friendId) =>
      _repo.removeFriend(currentUserId, friendId);
}
