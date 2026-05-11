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
    );
