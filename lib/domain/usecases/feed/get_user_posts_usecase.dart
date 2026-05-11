import '../../entities/post_entity.dart';
import '../../repositories/i_post_repository.dart';

class GetUserPostsUsecase {
  const GetUserPostsUsecase(this._repo);

  final IPostRepository _repo;

  Stream<List<PostEntity>> call(String userId) => _repo.watchUserPosts(userId);
}
