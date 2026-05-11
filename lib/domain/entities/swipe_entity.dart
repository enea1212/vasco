class SwipeEntity {
  const SwipeEntity({
    this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.isLike,
    this.timestamp,
  });

  final String? id;
  final String fromUserId;
  final String toUserId;
  final bool isLike;
  final DateTime? timestamp;
}
