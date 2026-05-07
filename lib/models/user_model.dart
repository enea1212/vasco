import 'package:cloud_firestore/cloud_firestore.dart';




class UserModel {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String? biography;
  final int sharedCountriesCount;
  final bool isPrivate;

  // --- Câmpuri Noi pentru Dating & Algoritm ---
  final DateTime? birthDate; // Pentru calcularea vârstei
  final String? gender; // Ex: 'male', 'female', 'other'
  final List<String>? interests; // "TinVec" - interese comune
  final Map<String, dynamic>? location; // Conține 'geohash' și coordonate 'lat', 'lng'
  final Map<String, dynamic>? preferences; // { 'minAge': 18, 'maxAge': 30, 'maxDistance': 50, 'gender': 'female' }
  final DateTime? lastActive; // Pentru prioritizarea userilor activi

  UserModel({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.biography,
    this.sharedCountriesCount = 0,
    this.isPrivate = false,
    this.birthDate,
    this.gender,
    this.interests,
    this.location,
    this.preferences,
    this.lastActive,
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

factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      id: documentId,
      email: map['email'] ?? '',
      displayName: map['displayName'],
      photoUrl: map['photoUrl'],
      biography: map['bio'],
      sharedCountriesCount: map['sharedCountriesCount'] ?? 0,
      
      // Parsare câmpuri noi
      birthDate: map['birthDate'] != null ? (map['birthDate'] as Timestamp).toDate() : null,
      gender: map['gender'],
      interests: map['interests'] != null ? List<String>.from(map['interests']) : null,
      location: map['location'],
      preferences: map['preferences'],
      lastActive: map['lastActive'] != null ? (map['lastActive'] as Timestamp).toDate() : null,
    );
  }








  // Util pentru salvarea în Firestore mai târziu
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> data = {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
    };

    if (biography != null) data['bio'] = biography;
    if (birthDate != null) data['birthDate'] = Timestamp.fromDate(birthDate!);
    if (gender != null) data['gender'] = gender;
    if (interests != null) data['interests'] = interests;
    if (location != null) data['location'] = location;
    if (preferences != null) data['preferences'] = preferences;
    if (lastActive != null) data['lastActive'] = Timestamp.fromDate(lastActive!);

    return data;
  }


  int get age {
    if (birthDate == null) return 0;
    final today = DateTime.now();
    int age = today.year - birthDate!.year;
    if (today.month < birthDate!.month || (today.month == birthDate!.month && today.day < birthDate!.day)) {
      age--;
    }
    return age;
  }
}
