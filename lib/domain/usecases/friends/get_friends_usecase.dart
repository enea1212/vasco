import '../../entities/user_entity.dart';
import '../../repositories/i_friend_repository.dart';

class GetFriendsUsecase {
  const GetFriendsUsecase(this._repo);

  final IFriendRepository _repo;

  Stream<List<UserEntity>> call(String userId) => _repo.watchFriends(userId);
}
