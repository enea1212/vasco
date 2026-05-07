class UserModel {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String? biography;
  final int sharedCountriesCount;
  final bool isPrivate;

  UserModel({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.biography,
    this.sharedCountriesCount = 0,
    this.isPrivate = false,
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
    final data = {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
    };

    if (biography != null) {
      data['bio'] = biography;
    }

    return data;
  }
}
