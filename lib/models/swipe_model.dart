import 'package:cloud_firestore/cloud_firestore.dart';

class SwipeModel {
  const SwipeModel({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.isLike,
    required this.timestamp,
  });

  final String id;
  final String fromUserId;
  final String toUserId;
  final bool isLike;
  final DateTime timestamp;

  factory SwipeModel.fromMap(Map<String, dynamic> map, String id) => SwipeModel(
        id: id,
        fromUserId: map['fromUserId'] as String? ?? '',
        toUserId: map['toUserId'] as String? ?? '',
        isLike: map['isLike'] as bool? ?? false,
        timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
}
