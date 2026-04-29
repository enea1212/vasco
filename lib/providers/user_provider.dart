import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:vasco/models/user_model.dart';
import 'dart:async';
class UserProvider with ChangeNotifier {
  UserModel? _user;
  UserModel? get user => _user;
  
 
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  void listenToUser(String uid) {
    // Anulăm o eventuală subscripție veche înainte de a începe una nouă
    _userSubscription?.cancel();

    _userSubscription = FirebaseFirestore.instance
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
          sharedCountriesCount: (data['shared_countries'] as List?)?.length ?? 0,
        );
        notifyListeners();
      }
    });
  }



}