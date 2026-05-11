import '../../entities/user_entity.dart';
import '../../repositories/i_swipe_repository.dart';

class GetCandidatesUsecase {
  const GetCandidatesUsecase(this._repo);

  final ISwipeRepository _repo;

  Future<List<UserEntity>> call(String userId) =>
      _repo.getCandidates(userId);
}
