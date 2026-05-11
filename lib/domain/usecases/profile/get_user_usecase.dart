import '../../entities/user_entity.dart';
import '../../repositories/i_user_repository.dart';

class GetUserUsecase {
  const GetUserUsecase(this._repo);

  final IUserRepository _repo;

  Stream<UserEntity?> call(String userId) => _repo.watchUser(userId);
}
