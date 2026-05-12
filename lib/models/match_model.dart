import 'package:cloud_firestore/cloud_firestore.dart';

class MatchModel {
  const MatchModel({
    required this.id,
    required this.users,
    this.timestamp,
    this.lastMessage,
    this.lastMessageTime,
  });

  final String id;
  final List<String> users;
  final DateTime? timestamp;
  final String? lastMessage;
  final DateTime? lastMessageTime;

  factory MatchModel.fromMap(Map<String, dynamic> map, String id) => MatchModel(
        id: id,
        users: List<String>.from(map['users'] as List? ?? []),
        timestamp: (map['timestamp'] as Timestamp?)?.toDate(),
        lastMessage: map['lastMessage'] as String?,
        lastMessageTime: (map['lastMessageTime'] as Timestamp?)?.toDate(),
      );
}
