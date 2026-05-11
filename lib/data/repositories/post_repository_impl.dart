// ignore_for_file: avoid_dynamic_calls
import '../../domain/entities/post_entity.dart';
import '../../domain/repositories/i_post_repository.dart';
// injected - see data/datasources/remote/post_remote_datasource.dart
import '../models/post_model_ext.dart';

class PostRepositoryImpl implements IPostRepository {
  const PostRepositoryImpl(this._datasource);

  /// PostRemoteDatasource — typed as dynamic until Fase 2A file is created.
  final dynamic _datasource;

  @override
  Stream<List<PostEntity>> watchUserPosts(String userId) {
    return (_datasource.watchUserPosts(userId)
            as Stream<List<Map<String, dynamic>>>)
        .map(_mapsToEntities);
  }

  @override
  Stream<List<PostEntity>> watchFeed(String userId) {
    return (_datasource.watchFeed(userId)
            as Stream<List<Map<String, dynamic>>>)
        .map(_mapsToEntities);
  }

  @override
  Future<void> createPost(PostEntity post) async {
    await _datasource.createPost(_entityToMap(post));
  }

  @override
  Future<void> deletePost(String postId) async {
    await _datasource.deletePost(postId);
  }

  List<PostEntity> _mapsToEntities(List<Map<String, dynamic>> maps) =>
      maps
          .map((m) => postModelFromMap(m, m['id'] as String).toEntity())
          .toList();

  Map<String, dynamic> _entityToMap(PostEntity e) => {
        'id': e.id,
        'userId': e.userId,
        'imageUrl': e.imageUrl,
        'description': e.description,
        'createdAt': e.createdAt,
      };
}
