import '../../entities/swipe_entity.dart';
import '../../repositories/i_swipe_repository.dart';

class SwipeUsecase {
  const SwipeUsecase(this._repo);

  final ISwipeRepository _repo;

  /// Returns true if the swipe resulted in a mutual match.
  Future<bool> call(SwipeEntity swipe) => _repo.swipe(swipe);
}
