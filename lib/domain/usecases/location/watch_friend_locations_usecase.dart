import '../../entities/friend_location_entity.dart';
import '../../repositories/i_location_repository.dart';

class WatchFriendLocationsUsecase {
  const WatchFriendLocationsUsecase(this._repo);

  final ILocationRepository _repo;

  Stream<Map<String, FriendLocationEntity>> call(String userId) =>
      _repo.watchFriendLocations(userId);
}
