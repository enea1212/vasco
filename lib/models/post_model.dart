class PostModel {
  final String id;
  final String userId;
  final String imageUrl;
  final String description;
  final DateTime createdAt;
  final List<String> coAuthorIds;
  final List<String> acceptedCoAuthorIds;
  final List<String> pendingCoAuthorIds;

  PostModel({
    required this.id,
    required this.userId,
    required this.imageUrl,
    required this.description,
    required this.createdAt,
    this.coAuthorIds = const [],
    this.acceptedCoAuthorIds = const [],
    this.pendingCoAuthorIds = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'imageUrl': imageUrl,
      'description': description,
      'createdAt': createdAt,
      'coAuthorIds': coAuthorIds,
      'acceptedCoAuthorIds': acceptedCoAuthorIds,
      'pendingCoAuthorIds': pendingCoAuthorIds,
    };
  }
}
