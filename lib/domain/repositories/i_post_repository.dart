import '../entities/post_entity.dart';

abstract interface class IPostRepository {
  Stream<List<PostEntity>> watchUserPosts(String userId);
  Stream<List<PostEntity>> watchFeed(String userId);
  Future<void> createPost(PostEntity post);
  Future<void> deletePost(String postId);

  /// Posts where the given user is listed in `pendingCoAuthorIds`.
  Stream<List<PostEntity>> watchPendingCoAuthorRequests(String userId);

  /// Mark the user as an accepted co-author on the post.
  Future<void> acceptCoAuthorRequest(String postId, String userId);

  /// Decline the co-author request — user is removed from pending list.
  Future<void> declineCoAuthorRequest(String postId, String userId);
}
