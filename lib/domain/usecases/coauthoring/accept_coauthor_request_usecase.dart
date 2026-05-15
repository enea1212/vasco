import '../../repositories/i_post_repository.dart';

class AcceptCoAuthorRequestUsecase {
  const AcceptCoAuthorRequestUsecase(this._repo);

  final IPostRepository _repo;

  Future<void> call(String postId, String userId) =>
      _repo.acceptCoAuthorRequest(postId, userId);
}
