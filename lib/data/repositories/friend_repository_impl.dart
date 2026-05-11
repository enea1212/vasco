// ignore_for_file: avoid_dynamic_calls
import '../../domain/entities/friend_request_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/i_friend_repository.dart';
// injected - see data/datasources/remote/friend_remote_datasource.dart
import '../models/friend_request_model_ext.dart';
import '../models/user_model_ext.dart';

class FriendRepositoryImpl implements IFriendRepository {
  const FriendRepositoryImpl(this._datasource);

  /// FriendRemoteDatasource — typed as dynamic until Fase 2A file is created.
  final dynamic _datasource;

  @override
  Stream<List<UserEntity>> watchFriends(String userId) {
    return (_datasource.watchFriends(userId)
            as Stream<List<Map<String, dynamic>>>)
        .map((maps) =>
            maps.map((m) => userModelFromMap(m).toEntity()).toList());
  }

  @override
  Stream<List<FriendRequestEntity>> watchIncomingRequests(String userId) {
    return (_datasource.watchIncomingRequests(userId)
            as Stream<List<Map<String, dynamic>>>)
        .map((maps) => maps
            .map((m) =>
                friendRequestModelFromMap(m, m['id'] as String? ?? '').toEntity())
            .toList());
  }

  @override
  Future<String> getRelationshipStatus(
      String currentUserId, String otherUserId) async {
    return await _datasource.getRelationshipStatus(
        currentUserId, otherUserId) as String;
  }

  @override
  Future<List<UserEntity>> searchUsers(
      String query, String currentUserId) async {
    final maps = await _datasource.searchUsers(query, currentUserId)
        as List<Map<String, dynamic>>;
    return maps.map((m) => userModelFromMap(m).toEntity()).toList();
  }

  @override
  Future<void> sendFriendRequest(String fromUserId, String toUserId) async {
    await _datasource.sendFriendRequest(fromUserId, toUserId);
  }

  @override
  Future<void> cancelFriendRequest(String fromUserId, String toUserId) async {
    await _datasource.cancelFriendRequest(fromUserId, toUserId);
  }

  @override
  Future<void> acceptFriendRequest(
      String requestId, String fromUserId, String toUserId) async {
    await _datasource.acceptFriendRequest(requestId, fromUserId, toUserId);
  }

  @override
  Future<void> declineFriendRequest(String requestId) async {
    await _datasource.declineFriendRequest(requestId);
  }

  @override
  Future<void> removeFriend(String currentUserId, String friendId) async {
    await _datasource.removeFriend(currentUserId, friendId);
  }
}
