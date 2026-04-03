class UserModel {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String? biography;

  UserModel({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
     this.biography,
  });

  // Transformă obiectul User de la Firebase în modelul nostru local
  factory UserModel.fromFirebase(dynamic firebaseUser) {
    return UserModel(
      id: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: firebaseUser.displayName,
      photoUrl: firebaseUser.photoURL,
    );
  }

  // Util pentru salvarea în Firestore mai târziu
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'biography':biography
    };
  }
}