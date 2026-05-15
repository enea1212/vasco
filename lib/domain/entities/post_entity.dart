class PostEntity {
  const PostEntity({
    required this.id,
    required this.userId,
    required this.imageUrl,
    required this.description,
    required this.createdAt,
    this.coAuthorIds = const [],
    this.acceptedCoAuthorIds = const [],
    this.pendingCoAuthorIds = const [],
  });

  final String id;
  final String userId;
  final String imageUrl;
  final String description;
  final DateTime createdAt;

  final List<String> coAuthorIds;
  final List<String> acceptedCoAuthorIds;
  final List<String> pendingCoAuthorIds;

  bool isPendingFor(String uid) => pendingCoAuthorIds.contains(uid);
  bool isAcceptedFor(String uid) => acceptedCoAuthorIds.contains(uid);
  bool isOwner(String uid) => userId == uid;
}
