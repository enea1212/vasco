import '../../repositories/i_post_repository.dart';

class DeclineCoAuthorRequestUsecase {
  const DeclineCoAuthorRequestUsecase(this._repo);

  final IPostRepository _repo;

  Future<void> call(String postId, String userId) =>
      _repo.declineCoAuthorRequest(postId, userId);
}
