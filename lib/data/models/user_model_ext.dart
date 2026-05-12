import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/user_model.dart';
import '../../domain/entities/user_entity.dart';

extension UserModelToEntity on UserModel {
  UserEntity toEntity() => UserEntity(
        id: id,
        email: email,
        displayName: displayName,
        photoUrl: photoUrl,
        biography: biography,
        sharedCountriesCount: sharedCountriesCount,
        isPrivate: isPrivate,
        birthDate: birthDate,
        gender: gender,
        interests: interests,
        locationGeohash: location?['geohash'] as String?,
        locationLat: (location?['lat'] as num?)?.toDouble(),
        locationLng: (location?['lng'] as num?)?.toDouble(),
        preferenceMinAge: (preferences?['minAge'] as num?)?.toInt(),
        preferenceMaxAge: (preferences?['maxAge'] as num?)?.toInt(),
        preferenceMaxDistance:
            (preferences?['maxDistance'] as num?)?.toDouble(),
        preferenceGender: preferences?['gender'] as String?,
        lastActive: lastActive,
      );
}

/// Factory din Map<String, dynamic> brut (output din datasource).
/// Necesită câmpul 'id' prezent în map sau transmis separat.
UserModel userModelFromMap(Map<String, dynamic> map) {
  final id = map['id'] as String? ?? '';
  return UserModel(
    id: id,
    email: map['email'] as String? ?? '',
    displayName: map['displayName'] as String?,
    photoUrl: map['photoUrl'] as String?,
    biography: map['bio'] as String?,
    sharedCountriesCount: (map['shared_countries'] as List?)?.length ??
        (map['sharedCountriesCount'] as num?)?.toInt() ?? 0,
    isPrivate: map['isPrivate'] as bool? ?? false,
    birthDate: map['birthDate'] != null
        ? (map['birthDate'] as Timestamp).toDate()
        : null,
    gender: map['gender'] as String?,
    interests: map['interests'] != null
        ? List<String>.from(map['interests'] as List)
        : null,
    location: map['location'] as Map<String, dynamic>?,
    preferences: map['preferences'] as Map<String, dynamic>?,
    lastActive: map['lastActive'] != null
        ? (map['lastActive'] as Timestamp).toDate()
        : null,
  );
}
