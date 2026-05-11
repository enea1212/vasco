// ignore_for_file: avoid_dynamic_calls
import 'dart:async';

import '../../domain/entities/friend_location_entity.dart';
import '../../domain/repositories/i_location_repository.dart';
// injected - see data/datasources/remote/location_remote_datasource.dart

class LocationRepositoryImpl implements ILocationRepository {
  const LocationRepositoryImpl(this._datasource);

  /// LocationRemoteDatasource — typed as dynamic until Fase 2A file is created.
  final dynamic _datasource;

  /// Combines per-friend location streams into a single map.
  ///
  /// NOTE: Full reactive combination (switchMap over friend-list changes) needs
  /// rxdart or orchestration in Faza 3. Current implementation re-subscribes
  /// once on the friend-id list and merges location streams.
  @override
  Stream<Map<String, FriendLocationEntity>> watchFriendLocations(
      String userId) async* {
    final friendIds = await (_datasource.getFriendIds(userId) as Future<List<String>>);

    if (friendIds.isEmpty) {
      yield {};
      return;
    }

    // Collect the latest snapshot from each friend's location stream.
    final current = <String, FriendLocationEntity>{};

    // Merge all per-friend streams into one using Stream.fromFutures pattern.
    // For full reactivity across friend-list changes, replace with rxdart
    // CombineLatestStream in Faza 3.
    final streams = friendIds.map((id) =>
        (_datasource.watchFriendLocation(id) as Stream<Map<String, dynamic>?>)
            .map<MapEntry<String, FriendLocationEntity>>((map) {
          if (map == null) {
            return MapEntry(
                id, const FriendLocationEntity());
          }
          return MapEntry(
            id,
            FriendLocationEntity(
              latitude: (map['lat'] as num?)?.toDouble(),
              longitude: (map['lng'] as num?)?.toDouble(),
              displayName: map['displayName'] as String?,
              photoUrl: map['photoUrl'] as String?,
            ),
          );
        }));

    await for (final entry in _mergeStreams(streams)) {
      current[entry.key] = entry.value;
      yield Map.unmodifiable(current);
    }
  }

  @override
  Future<void> publishLocation(
      String userId, double lat, double lng) async {
    await _datasource.publishLocation(userId, lat, lng);
  }

  @override
  Future<void> deleteLocation(String userId) async {
    await _datasource.deleteLocation(userId);
  }

  @override
  Future<String> getVisibility(String userId) async {
    return await _datasource.getVisibility(userId) as String;
  }

  @override
  Future<void> setVisibility(String userId, String visibility) async {
    await _datasource.setVisibility(userId, visibility);
  }

  /// Naive stream merger: yields events from all streams in arrival order.
  Stream<T> _mergeStreams<T>(Iterable<Stream<T>> streams) async* {
    final controller = StreamController<T>();
    var active = 0;
    for (final s in streams) {
      active++;
      s.listen(
        controller.add,
        onError: controller.addError,
        onDone: () {
          active--;
          if (active == 0) controller.close();
        },
      );
    }
    yield* controller.stream;
  }
}
