import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Salvează sau actualizează profilul utilizatorului
  Future<void> saveUserProfile(UserModel user) async {
    try {
      // Creează un document în colecția 'users' cu ID-ul unic al utilizatorului
      await _db.collection('users').doc(user.id).set(user.toMap()); 
    } catch (e) {
      print("Eroare la salvarea în Firestore: $e");
    }
  }
}