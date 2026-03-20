import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:vasco/models/user_model.dart';



//Acesta este "Executantul". El nu știe nimic despre interfața grafică,
// butoane sau erori afișate pe ecran.Responsabilitate: Comunică direct cu 
//Firebase Auth și Google Sign-In.Rol principal: Să trimită datele la server 
//și să returneze rezultatul (sau o eroare tehnică).





//ValueNotifier<AuthService> authService= ValueNotifier(AuthService());

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Get current user

 UserModel? get currentUser {
    final user = _firebaseAuth.currentUser;
    return user != null ? UserModel.fromFirebase(user) : null;
  }

Stream<UserModel?> get onAuthStateChanged {
    return _firebaseAuth.authStateChanges().map((firebaseUser) {
      return firebaseUser != null ? UserModel.fromFirebase(firebaseUser) : null;
    });
  }
  // Sign up with email and password
Future<UserModel?> createAccount(String email, String password, String name) async {
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Integrarea numelui conform planului [cite: 17]
      await userCredential.user?.updateDisplayName(name);
      await userCredential.user?.reload();
      
      final updatedUser = _firebaseAuth.currentUser;
      return updatedUser != null ? UserModel.fromFirebase(updatedUser) : null;
    } catch (e) {
      rethrow;
    }
  }
  // Sign in with email and password
Future<UserModel?> signInWithEmail(String email, String password) async {
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Conversia din Firebase User în modelul nostru personalizat UserModel
      if (userCredential.user != null) {
        return UserModel.fromFirebase(userCredential.user!);
      }
      
      return null;
    } on FirebaseAuthException {
      // Re-aruncăm eroarea pentru a fi prinsă de blocul catch din UI (cel cu showDialog)
      rethrow;
    } catch (e) {
      // Prindem orice altă eroare neprevăzută
      throw Exception('A apărut o eroare neașteptată la autentificare.');
    }
  }

  // Sign in cu Google

  Future<UserModel?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

    
      final UserCredential userCredential = 
          await _firebaseAuth.signInWithCredential(credential);

      // Convertim User-ul Firebase în modelul nostru personalizat UserModel
      if (userCredential.user != null) {
        return UserModel.fromFirebase(userCredential.user!);
      }
      
      return null;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
     
      throw Exception('Autentificarea cu Google a eșuat.');
    }
  }

  // Sign out
Future<void> signOut() async {
    try {
      // Deconectare de la Firebase Auth
      await _firebaseAuth.signOut();
      
      // Deconectare de la Google (important pentru a permite 
      // utilizatorului să aleagă alt cont la următoarea logare)
      await _googleSignIn.signOut();
    } catch (e) {
      // Aruncăm o eroare personalizată pentru a fi prinsă de UI dacă este necesar
      throw Exception('Eroare la deconectare: ${e.toString()}');
    }
  }

// resetare parola
Future <void>resetPassword({
  required String email,

})async {
  await _firebaseAuth.sendPasswordResetEmail(email: email);
}

// stergere cont 
Future<void> deleteAccount({
    required String email,
    required String password,
  }) async {
    try {
      // Avem nevoie de user-ul curent de la Firebase pentru operațiuni administrative
      final user = _firebaseAuth.currentUser;
      
      if (user == null) {
        throw Exception('Nu există un utilizator logat pentru a efectua ștergerea.');
      }

      // Creăm acreditările pentru re-autentificare
      AuthCredential credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      
      await user.reauthenticateWithCredential(credential);

      
      await user.delete();

      
      await signOut();
      
    } on FirebaseAuthException catch (e) {
      // Tratăm erori specifice (ex: parolă greșită la re-autentificare)
      throw Exception('A apărut o eroare la ștergerea contului.');
    } 
    
  }



Stream<UserModel?> authStateChanges() {
    return _firebaseAuth.authStateChanges().map((firebaseUser) {
      // Dacă firebaseUser nu este null, îl convertim în UserModel folosind factory-ul creat
      return firebaseUser != null ? UserModel.fromFirebase(firebaseUser) : null;
    });
  }
}
