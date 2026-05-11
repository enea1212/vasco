class UserEntity {
  const UserEntity({
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
    this.locationGeohash,
    this.locationLat,
    this.locationLng,
    this.preferenceMinAge,
    this.preferenceMaxAge,
    this.preferenceMaxDistance,
    this.preferenceGender,
    this.lastActive,
  });

  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String? biography;
  final int sharedCountriesCount;
  final bool isPrivate;
  final DateTime? birthDate;
  final String? gender;
  final List<String>? interests;
  final String? locationGeohash;
  final double? locationLat;
  final double? locationLng;
  final int? preferenceMinAge;
  final int? preferenceMaxAge;
  final double? preferenceMaxDistance;
  final String? preferenceGender;
  final DateTime? lastActive;

  int get age {
    if (birthDate == null) return 0;
    final today = DateTime.now();
    int a = today.year - birthDate!.year;
    if (today.month < birthDate!.month ||
        (today.month == birthDate!.month && today.day < birthDate!.day)) {
      a--;
    }
    return a;
  }

  UserEntity copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    String? biography,
    int? sharedCountriesCount,
    bool? isPrivate,
    DateTime? birthDate,
    String? gender,
    List<String>? interests,
    String? locationGeohash,
    double? locationLat,
    double? locationLng,
    int? preferenceMinAge,
    int? preferenceMaxAge,
    double? preferenceMaxDistance,
    String? preferenceGender,
    DateTime? lastActive,
  }) {
    return UserEntity(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      biography: biography ?? this.biography,
      sharedCountriesCount: sharedCountriesCount ?? this.sharedCountriesCount,
      isPrivate: isPrivate ?? this.isPrivate,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      interests: interests ?? this.interests,
      locationGeohash: locationGeohash ?? this.locationGeohash,
      locationLat: locationLat ?? this.locationLat,
      locationLng: locationLng ?? this.locationLng,
      preferenceMinAge: preferenceMinAge ?? this.preferenceMinAge,
      preferenceMaxAge: preferenceMaxAge ?? this.preferenceMaxAge,
      preferenceMaxDistance:
          preferenceMaxDistance ?? this.preferenceMaxDistance,
      preferenceGender: preferenceGender ?? this.preferenceGender,
      lastActive: lastActive ?? this.lastActive,
    );
  }
}
