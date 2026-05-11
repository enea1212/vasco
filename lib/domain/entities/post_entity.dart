class PostEntity {
  const PostEntity({
    required this.id,
    required this.userId,
    required this.imageUrl,
    required this.description,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String imageUrl;
  final String description;
  final DateTime createdAt;
}
