import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class PostRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> uploadPost(String userId, String description, gallery) async {
    final ImagePicker picker = ImagePicker();
    // 1. Selectează poza
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (image == null) return;

    File file = File(image.path);
    String fileName = 'posts/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';

    try {
      // 2. Upload în Firebase Storage
      TaskSnapshot upload = await _storage.ref().child(fileName).putFile(file);
      String url = await upload.ref.getDownloadURL();

      // 3. Salvare în Firestore
      await _db.collection('posts').add({
        'userId': userId,
        'imageUrl': url,
        'description': description,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Eroare la upload: $e");
      rethrow;
    }
  }

Future<void> deletePost(String postId, String imageUrl) async {
    try {
      // Șterge documentul din baza de date Firestore
      await _db.collection('posts').doc(postId).delete();

      // Șterge fișierul fizic din Firebase Storage folosind URL-ul
      await _storage.refFromURL(imageUrl).delete();
      
      print("Postare ștearsă cu succes.");
    } catch (e) {
      print("Eroare la ștergere: $e");
      rethrow;
    }
  }
  Future<void> editPost(String postId, String newDescription) async {
    try {
      // Actualizează doar câmpul 'description' în Firestore
      await _db.collection('posts').doc(postId).update({
        'description': newDescription,
      });
      
      print("Postare actualizată cu succes.");
    } catch (e) {
      print("Eroare la editare: $e");
      rethrow;
    }
  }


}