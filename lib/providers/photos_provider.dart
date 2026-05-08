import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';

class PhotosProvider with ChangeNotifier {
  List<QueryDocumentSnapshot> _photoDocs = [];
  int _photosCount = 0;
  int _totalLikes = 0;
  String? _currentUserId;

  List<QueryDocumentSnapshot> get photoDocs => _photoDocs;
  int get photosCount => _photosCount;
  int get totalLikes => _totalLikes;

  StreamSubscription<QuerySnapshot>? _photosSubscription;

  Future<void> hitLike(String photoId) async {
    try {
      // Apelăm funcția toggleLike definită în index.js
      await FirebaseFunctions.instance.httpsCallable('toggleLike').call({
        "postId": photoId,
        "collection": "location_photos",
      });

      // Nu este nevoie de notifyListeners() aici, deoarece listenToUserPhotos
      // va detecta automat schimbarea de pe server și va face update la UI.
    } catch (e) {
      debugPrint('Eroare la toggleLike: $e');
    }
  }

  void listenToUserPhotos(String userId) {
    // Evită crearea de mai mulți listeners pentru același user
    if (_currentUserId == userId && _photosSubscription != null) {
      return;
    }

    _photosSubscription?.cancel();
    _currentUserId = userId;

    _photosSubscription = FirebaseFirestore.instance
        .collection('location_photos')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            // Actualizează doar dacă avem date noi
            _photoDocs = snapshot.docs;
            _photosCount = _photoDocs.length;
            _totalLikes = _photoDocs.fold<int>(0, (acc, doc) {
              final d = doc.data() as Map<String, dynamic>;
              return acc + ((d['likesCount'] as num?)?.toInt() ?? 0);
            });
            notifyListeners();
          },
          onError: (error) {
            debugPrint('Error listening to photos: $error');
          },
        );
  }

  @override
  void dispose() {
    _photosSubscription?.cancel();
    _photosSubscription = null;
    _currentUserId = null;
    super.dispose();
  }
}
