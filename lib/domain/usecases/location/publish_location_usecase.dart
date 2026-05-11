import '../../repositories/i_location_repository.dart';

class PublishLocationUsecase {
  const PublishLocationUsecase(this._repo);

  final ILocationRepository _repo;

  Future<void> call(String userId, double lat, double lng) =>
      _repo.publishLocation(userId, lat, lng);
}
