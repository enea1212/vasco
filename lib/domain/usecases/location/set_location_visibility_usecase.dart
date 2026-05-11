import '../../repositories/i_location_repository.dart';

class SetLocationVisibilityUsecase {
  const SetLocationVisibilityUsecase(this._repo);

  final ILocationRepository _repo;

  Future<void> call(String userId, String visibility) =>
      _repo.setVisibility(userId, visibility);
}
