import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/friend_request_model.dart';
import '../../domain/entities/friend_request_entity.dart';

extension FriendRequestModelToEntity on FriendRequestModel {
  FriendRequestEntity toEntity() => FriendRequestEntity(
        id: id,
        fromUserId: fromUserId,
        toUserId: toUserId,
        status: _parseStatus(status),
        createdAt: createdAt,
      );
}

FriendRequestStatus _parseStatus(String raw) {
  switch (raw) {
    case 'accepted':
      return FriendRequestStatus.accepted;
    case 'declined':
      return FriendRequestStatus.declined;
    default:
      return FriendRequestStatus.pending;
  }
}

/// Factory din Map brut primit din datasource.
FriendRequestModel friendRequestModelFromMap(
    Map<String, dynamic> map, String id) =>
    FriendRequestModel(
      id: id,
      fromUserId: map['fromUserId'] as String? ?? '',
      toUserId: map['toUserId'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      createdAt:
          (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
