import '../../entities/match_entity.dart';
import '../../repositories/i_swipe_repository.dart';

class WatchMatchesUsecase {
  const WatchMatchesUsecase(this._repo);

  final ISwipeRepository _repo;

  Stream<List<MatchEntity>> call(String userId) =>
      _repo.watchMatches(userId);
}
