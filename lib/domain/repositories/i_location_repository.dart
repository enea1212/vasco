import '../entities/friend_location_entity.dart';

abstract interface class ILocationRepository {
  Stream<Map<String, FriendLocationEntity>> watchFriendLocations(
      String userId);
  Future<void> publishLocation(String userId, double lat, double lng);
  Future<void> deleteLocation(String userId);
  Future<String> getVisibility(String userId);
  Future<void> setVisibility(String userId, String visibility);
}
