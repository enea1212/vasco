import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:vasco/models/user_model.dart';

class UserProvider with ChangeNotifier {
  UserModel? _user;
  UserModel? get user => _user;

  void listenToUser(String uid) {
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        _user = UserModel(
          id: data['id'],
          email: data['email'],
          displayName: data['displayName'],
          photoUrl: data['photoUrl'],
          biography: data['bio'] ?? "",
        );
        notifyListeners();
      }
    });
  }
}