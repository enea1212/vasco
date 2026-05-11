import '../../repositories/i_location_repository.dart';

class GetLocationVisibilityUsecase {
  const GetLocationVisibilityUsecase(this._repo);

  final ILocationRepository _repo;

  Future<String> call(String userId) => _repo.getVisibility(userId);
}
