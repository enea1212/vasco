import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';


// este un state management 
ValueNotifier<AuthService> authService= ValueNotifier(AuthService());

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Get current user
  User? get currentUser => _firebaseAuth.currentUser;
 
  // Sign up with email and password
  Future<UserCredential?> createAccount(String email, String password) async {
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  // Sign in with email and password
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  // Sign in cu Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _firebaseAuth.signInWithCredential(credential);
    } on FirebaseAuthException {
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
      await _googleSignIn.signOut();
    } catch (_) {
      rethrow;
    }
  }


// resetare parola
Future <void>resetPassword({
  required String email,

})async {
  await _firebaseAuth.sendPasswordResetEmail(email: email);
}

// stergere cont 
Future <void>deleteAcount({
  required String email,
  required String password,
})async{
  AuthCredential credential= EmailAuthProvider.credential(email:email,password:password);
 await currentUser!.reauthenticateWithCredential(credential);
 await currentUser!.delete();
 await _firebaseAuth.signOut();


}



  // Check if user is logged in
  Stream<User?> authStateChanges() {
    return _firebaseAuth.authStateChanges();
  }
}
