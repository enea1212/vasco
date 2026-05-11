import '../../repositories/i_location_repository.dart';

class DeleteLocationUsecase {
  const DeleteLocationUsecase(this._repo);

  final ILocationRepository _repo;

  Future<void> call(String userId) => _repo.deleteLocation(userId);
}
