import '../entities/friend_request_entity.dart';
import '../entities/user_entity.dart';

abstract interface class IFriendRepository {
  Stream<List<UserEntity>> watchFriends(String userId);
  Stream<List<FriendRequestEntity>> watchIncomingRequests(String userId);
  Future<String> getRelationshipStatus(
      String currentUserId, String otherUserId);
  Future<List<UserEntity>> searchUsers(String query, String currentUserId);
  Future<void> sendFriendRequest(String fromUserId, String toUserId);
  Future<void> cancelFriendRequest(String fromUserId, String toUserId);
  Future<void> acceptFriendRequest(
      String requestId, String fromUserId, String toUserId);
  Future<void> declineFriendRequest(String requestId);
  Future<void> removeFriend(String currentUserId, String friendId);
}
