import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthStateProvider extends ChangeNotifier {
  AuthStateProvider() {
    _sub = FirebaseAuth.instance.authStateChanges().listen((user) {
      _userId = user?.uid;
      notifyListeners();
    });
  }

  StreamSubscription<User?>? _sub;
  String? _userId;

  String? get userId => _userId;
  bool get isLoggedIn => _userId != null;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
