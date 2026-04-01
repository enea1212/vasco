import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String id;
  final String userId;
  final String imageUrl;
  final String description;
  final DateTime createdAt;

  PostModel({
    required this.id,
    required this.userId,
    required this.imageUrl,
    required this.description,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'imageUrl': imageUrl,
      'description': description,
      'createdAt': createdAt,
    };
  }
}