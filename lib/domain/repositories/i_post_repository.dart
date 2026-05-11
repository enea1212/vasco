import '../entities/post_entity.dart';

abstract interface class IPostRepository {
  Stream<List<PostEntity>> watchUserPosts(String userId);
  Stream<List<PostEntity>> watchFeed(String userId);
  Future<void> createPost(PostEntity post);
  Future<void> deletePost(String postId);
}
