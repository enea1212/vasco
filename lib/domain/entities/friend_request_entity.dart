enum FriendRequestStatus { pending, accepted, declined }

class FriendRequestEntity {
  const FriendRequestEntity({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String fromUserId;
  final String toUserId;
  final FriendRequestStatus status;
  final DateTime createdAt;
}
