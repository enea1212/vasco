import '../../repositories/i_user_repository.dart';

class UpdateProfileUsecase {
  const UpdateProfileUsecase(this._repo);

  final IUserRepository _repo;

  Future<void> call(String userId, Map<String, dynamic> fields) =>
      _repo.updateUser(userId, fields);
}
