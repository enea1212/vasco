import '../../tinder_models/swipe_model.dart';
import '../../domain/entities/swipe_entity.dart';

extension SwipeModelToEntity on SwipeModel {
  SwipeEntity toEntity() => SwipeEntity(
        id: id,
        fromUserId: fromUserId,
        toUserId: toUserId,
        isLike: isLike,
        timestamp: timestamp,
      );
}

/// Factory din Map brut primit din datasource.
SwipeModel swipeModelFromMap(Map<String, dynamic> map, String id) =>
    SwipeModel.fromMap(map, id);

/// Conversie entitate → Map pentru scriere în datasource.
Map<String, dynamic> swipeEntityToMap(SwipeEntity e) => {
      'fromUserId': e.fromUserId,
      'toUserId': e.toUserId,
      'isLike': e.isLike,
    };
