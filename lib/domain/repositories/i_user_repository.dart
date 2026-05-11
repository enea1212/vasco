import '../entities/user_entity.dart';

abstract interface class IUserRepository {
  Future<UserEntity?> getUser(String userId);
  Stream<UserEntity?> watchUser(String userId);
  Future<void> saveUser(UserEntity user);
  Future<void> updateUser(String userId, Map<String, dynamic> fields);
}
