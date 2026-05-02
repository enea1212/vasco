import 'package:cloud_firestore/cloud_firestore.dart';

class MatchModel {
  final String id; // ID-ul documentului (care va fi folosit probabil și ca ID de Chat Room)
  final List<String> users; // Lista cu cele 2 ID-uri ale userilor (ex: [user1_id, user2_id])
  final DateTime? timestamp; // Când s-a format match-ul
  final String? lastMessage; // Util pentru a afișa un preview în lista de conversații
  final DateTime? lastMessageTime;

  MatchModel({
    required this.id,
    required this.users,
    this.timestamp,
    this.lastMessage,
    this.lastMessageTime,
  });

  // Din Firestore în Dart
  factory MatchModel.fromMap(Map<String, dynamic> map, String documentId) {
    return MatchModel(
      id: documentId,
      // Extragem array-ul de string-uri în siguranță
      users: map['users'] != null ? List<String>.from(map['users']) : [],
      timestamp: map['timestamp'] != null 
          ? (map['timestamp'] as Timestamp).toDate() 
          : DateTime.now(),
      lastMessage: map['lastMessage'],
      lastMessageTime: map['lastMessageTime'] != null 
          ? (map['lastMessageTime'] as Timestamp).toDate() 
          : null,
    );
  }

  // Din Dart în Firestore
  Map<String, dynamic> toMap() {
    return {
      'users': users,
      'timestamp': timestamp == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(timestamp!),
      'lastMessage': lastMessage,
      if (lastMessageTime != null) 'lastMessageTime': Timestamp.fromDate(lastMessageTime!),
    };
  }
}