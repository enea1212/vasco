import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/post_model.dart';
import '../../domain/entities/post_entity.dart';

extension PostModelToEntity on PostModel {
  PostEntity toEntity() => PostEntity(
        id: id,
        userId: userId,
        imageUrl: imageUrl,
        description: description,
        createdAt: createdAt,
        coAuthorIds: coAuthorIds,
        acceptedCoAuthorIds: acceptedCoAuthorIds,
        pendingCoAuthorIds: pendingCoAuthorIds,
      );
}

/// Factory din Map brut primit din datasource.
PostModel postModelFromMap(Map<String, dynamic> map, String id) => PostModel(
      id: id,
      userId: map['userId'] as String,
      imageUrl: map['imageUrl'] as String,
      description: map['description'] as String? ?? '',
      createdAt:
          (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      coAuthorIds: _stringList(map['coAuthorIds']),
      acceptedCoAuthorIds: _stringList(map['acceptedCoAuthorIds']),
      pendingCoAuthorIds: _stringList(map['pendingCoAuthorIds']),
    );

List<String> _stringList(dynamic raw) {
  if (raw is List) {
    return raw.whereType<String>().toList();
  }
  return const [];
}
