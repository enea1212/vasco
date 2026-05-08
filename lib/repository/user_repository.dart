import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class UserRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Salvează sau actualizează profilul utilizatorului
  Future<void> saveUserProfile(UserModel user) async {
    try {
      // Creează un document în colecția 'users' cu ID-ul unic al utilizatorului
      await _db.collection('users').doc(user.id).set(user.toMap());
    } catch (e) {
      debugPrint("Eroare la salvarea în Firestore: $e");
    }
  }

  Future<void> updateUserProfile(
    String userId,
    Map<String, dynamic> data,
  ) async {
    await _db.collection('users').doc(userId).update(data);
  }

  Future<UserModel> getUserData(String userId) async {
    var doc = await _db.collection('users').doc(userId).get();
    return UserModel(
      id: doc['id'],
      email: doc['email'],
      displayName: doc['displayName'],
      photoUrl: doc['photoUrl'],
      biography: doc['bio'],
    );
  }
}
