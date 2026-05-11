// ignore_for_file: avoid_dynamic_calls
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/i_user_repository.dart';
// injected - see data/datasources/remote/user_remote_datasource.dart
import '../models/user_model_ext.dart';

class UserRepositoryImpl implements IUserRepository {
  const UserRepositoryImpl(this._datasource);

  /// UserRemoteDatasource — typed as dynamic until Fase 2A file is created.
  final dynamic _datasource;

  @override
  Future<UserEntity?> getUser(String userId) async {
    final map =
        await _datasource.getUser(userId) as Map<String, dynamic>?;
    if (map == null) return null;
    return userModelFromMap(map).toEntity();
  }

  @override
  Stream<UserEntity?> watchUser(String userId) {
    return (_datasource.watchUser(userId) as Stream<Map<String, dynamic>?>)
        .map((map) => map == null ? null : userModelFromMap(map).toEntity());
  }

  @override
  Future<void> saveUser(UserEntity user) async {
    await _datasource.saveUser(_entityToMap(user));
  }

  @override
  Future<void> updateUser(String userId, Map<String, dynamic> fields) async {
    await _datasource.updateUser(userId, fields);
  }

  Map<String, dynamic> _entityToMap(UserEntity e) => {
        'id': e.id,
        'email': e.email,
        if (e.displayName != null) 'displayName': e.displayName,
        if (e.photoUrl != null) 'photoUrl': e.photoUrl,
        if (e.biography != null) 'bio': e.biography,
        'sharedCountriesCount': e.sharedCountriesCount,
        'isPrivate': e.isPrivate,
        if (e.gender != null) 'gender': e.gender,
        if (e.interests != null) 'interests': e.interests,
        if (e.birthDate != null) 'birthDate': e.birthDate,
        if (e.lastActive != null) 'lastActive': e.lastActive,
        if (e.locationGeohash != null || e.locationLat != null)
          'location': {
            if (e.locationGeohash != null) 'geohash': e.locationGeohash,
            if (e.locationLat != null) 'lat': e.locationLat,
            if (e.locationLng != null) 'lng': e.locationLng,
          },
        if (e.preferenceMinAge != null ||
            e.preferenceMaxAge != null ||
            e.preferenceMaxDistance != null ||
            e.preferenceGender != null)
          'preferences': {
            if (e.preferenceMinAge != null) 'minAge': e.preferenceMinAge,
            if (e.preferenceMaxAge != null) 'maxAge': e.preferenceMaxAge,
            if (e.preferenceMaxDistance != null)
              'maxDistance': e.preferenceMaxDistance,
            if (e.preferenceGender != null) 'gender': e.preferenceGender,
          },
      };
}
