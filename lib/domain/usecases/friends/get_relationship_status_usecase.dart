import '../../repositories/i_friend_repository.dart';

class GetRelationshipStatusUsecase {
  const GetRelationshipStatusUsecase(this._repo);

  final IFriendRepository _repo;

  Future<String> call(String currentUserId, String otherUserId) =>
      _repo.getRelationshipStatus(currentUserId, otherUserId);
}
