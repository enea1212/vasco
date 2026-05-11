import '../../entities/user_entity.dart';
import '../../repositories/i_friend_repository.dart';

class SearchUsersUsecase {
  const SearchUsersUsecase(this._repo);

  final IFriendRepository _repo;

  Future<List<UserEntity>> call(String query, String currentUserId) =>
      _repo.searchUsers(query, currentUserId);
}
