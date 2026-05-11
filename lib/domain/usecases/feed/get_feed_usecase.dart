import '../../entities/post_entity.dart';
import '../../repositories/i_post_repository.dart';

class GetFeedUsecase {
  const GetFeedUsecase(this._repo);

  final IPostRepository _repo;

  Stream<List<PostEntity>> call(String userId) => _repo.watchFeed(userId);
}
