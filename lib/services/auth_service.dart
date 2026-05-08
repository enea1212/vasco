import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:vasco/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _db =
      FirebaseFirestore.instance; // Instanța Firestore

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

  // --- MODIFICARE: CREARE CONT + SALVARE FIRESTORE ---
  Future<UserModel?> createAccount(
    String email,
    String password,
    String name,
  ) async {
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        // 1. Integrarea numelui în Firebase Auth
        await firebaseUser.updateDisplayName(name);
        await firebaseUser.reload();

        final updatedFirebaseUser = _firebaseAuth.currentUser;

        // 2. Crearea modelului nostru de date
        UserModel newUser = UserModel(
          id: updatedFirebaseUser!.uid,
          email: updatedFirebaseUser.email ?? email,
          displayName: name,
          photoUrl: updatedFirebaseUser.photoURL ?? '',
        );

        // 3. SALVARE ÎN FIRESTORE (Colecția 'users')
        final userData = newUser.toMap();
        userData['displayNameLower'] = name.toLowerCase();
        await _db.collection('users').doc(newUser.id).set(userData);

        return newUser;
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // --- MODIFICARE: LOGIN GOOGLE + SALVARE/ACTUALIZARE FIRESTORE ---
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

      final UserCredential userCredential = await _firebaseAuth
          .signInWithCredential(credential);
      final firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        UserModel userModel = UserModel.fromFirebase(firebaseUser);

        // Păstrează valorile existente din Firestore (ex. displayName/bio actualizate de utilizator)
        final userDoc = await _db.collection('users').doc(userModel.id).get();
        final existingData = userDoc.exists
            ? userDoc.data() ?? <String, dynamic>{}
            : <String, dynamic>{};

        final mergedData = <String, dynamic>{
          ...existingData,
          'id': userModel.id,
          'email': userModel.email,
          if ((existingData['displayName'] == null ||
                  existingData['displayName'].toString().isEmpty) &&
              (userModel.displayName != null &&
                  userModel.displayName!.isNotEmpty))
            'displayName': userModel.displayName,
          if ((existingData['photoUrl'] == null ||
                  existingData['photoUrl'].toString().isEmpty) &&
              (userModel.photoUrl != null && userModel.photoUrl!.isNotEmpty))
            'photoUrl': userModel.photoUrl,
          if ((existingData['bio'] == null ||
                  existingData['bio'].toString().isEmpty) &&
              (userModel.biography != null && userModel.biography!.isNotEmpty))
            'bio': userModel.biography,
        };

        mergedData.removeWhere((key, value) => value == null);

        final displayName = mergedData['displayName']?.toString() ?? '';
        if (displayName.isNotEmpty) {
          mergedData['displayNameLower'] = displayName.toLowerCase();
        }

        await _db
            .collection('users')
            .doc(userModel.id)
            .set(mergedData, SetOptions(merge: true));

        return userModel;
      }
      return null;
    } catch (e) {
      throw Exception('Autentificarea cu Google a eșuat.');
    }
  }

  // Restul metodelor rămân neschimbate...
  Future<UserModel?> signInWithEmail(String email, String password) async {
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user != null
          ? UserModel.fromFirebase(userCredential.user!)
          : null;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid != null) {
      await _db.collection('user_locations').doc(uid).delete();
    }
    await _firebaseAuth.signOut();
    await _googleSignIn.signOut();
  }

  Future<void> resetPassword({required String email}) async {
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
        throw Exception(
          'Nu există un utilizator logat pentru a efectua ștergerea.',
        );
      }

      // Creăm acreditările pentru re-autentificare
      AuthCredential credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);

      await user.delete();

      await signOut();
    } on FirebaseAuthException {
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
