import 'package:cloud_firestore/cloud_firestore.dart';

class SwipeModel {
  final String? id; // ID-ul documentului generat de Firestore
  final String fromUserId; // ID-ul celui care a făcut acțiunea (Tu)
  final String toUserId; // ID-ul profilului pe care ai dat swipe
  final bool isLike; // true pentru Swipe Right (Like), false pentru Swipe Left (Pass)
  final DateTime? timestamp;

  SwipeModel({
    this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.isLike,
    this.timestamp,
  });

  // Transformare din Firestore (JSON) în obiect Dart
  factory SwipeModel.fromMap(Map<String, dynamic> map, String documentId) {
    return SwipeModel(
      id: documentId,
      fromUserId: map['fromUserId'] ?? '',
      toUserId: map['toUserId'] ?? '',
      isLike: map['isLike'] ?? false,
      timestamp: map['timestamp'] != null 
          ? (map['timestamp'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }

  // Transformare din obiect Dart în format pentru Firestore
  Map<String, dynamic> toMap() {
    return {
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'isLike': isLike,
      // Folosim FieldValue.serverTimestamp() pentru precizie maximă direct de pe server
      'timestamp': FieldValue.serverTimestamp(), 
    };
  }
}