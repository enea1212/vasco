import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class PostRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<void> uploadPost(String userId, String description, gallery) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (image == null) return;

    final file = File(image.path);
    final fileName = 'posts/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';

    final upload = await _storage.ref().child(fileName).putFile(file);
    final url = await upload.ref.getDownloadURL();

    await _db.collection('posts').add({
      'userId': userId,
      'imageUrl': url,
      'description': description,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Ștergerea se face prin Cloud Function pentru a curăța și fișierul din Storage
  Future<void> deletePost(String postId, String imageUrl) async {
    final callable = _functions.httpsCallable('deletePost');
    await callable.call({'postId': postId});
  }

  Future<void> editPost(String postId, String newDescription) async {
    await _db.collection('posts').doc(postId).update({
      'description': newDescription,
    });
  }
}
