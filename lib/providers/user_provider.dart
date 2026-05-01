import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:vasco/models/user_model.dart';
import 'dart:async';

class UserProvider with ChangeNotifier {
  UserModel? _user;
  UserModel? get user => _user;

  StreamSubscription<DocumentSnapshot>? _userSubscription;
  String? _currentUid;

  void listenToUser(String uid) {
    // Evită crearea de multiple listeners pentru același user
    if (_currentUid == uid && _userSubscription != null) {
      return;
    }

    // Anulăm o eventuală subscripție veche
    _userSubscription?.cancel();
    _currentUid = uid;

    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        
        // Păstrează valorile existente pentru câmpurile care nu sunt în update
        _user = UserModel(
          id: data['id'] ?? _user?.id ?? uid,
          email: data['email'] ?? _user?.email ?? '',
          displayName: data['displayName'] ?? _user?.displayName,
          photoUrl: data['photoUrl'] ?? _user?.photoUrl,
          biography: data['bio'] ?? _user?.biography ?? "",
          sharedCountriesCount: (data['shared_countries'] as List?)?.length ?? 
                                _user?.sharedCountriesCount ?? 0,
        );
        notifyListeners();
      }
    }, onError: (error) {
      print('Error listening to user: $error');
    });
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _userSubscription = null;
    super.dispose();
  }
}