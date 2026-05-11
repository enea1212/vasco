import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../../../domain/entities/friend_location_entity.dart';
import '../../../domain/usecases/location/watch_friend_locations_usecase.dart';
import '../../../domain/usecases/location/publish_location_usecase.dart';
import '../../../domain/usecases/location/delete_location_usecase.dart';
import '../../../domain/usecases/location/get_location_visibility_usecase.dart';
import '../../../domain/usecases/location/set_location_visibility_usecase.dart';

class LocationProvider extends ChangeNotifier {
  LocationProvider(
    this._watchFriendLocations,
    this._publishLocation,
    this._deleteLocation,
    this._getVisibility,
    this._setVisibility,
  );

  final WatchFriendLocationsUsecase _watchFriendLocations;
  final PublishLocationUsecase _publishLocation;
  final DeleteLocationUsecase _deleteLocation;
  // ignore: unused_field
  final GetLocationVisibilityUsecase _getVisibility;
  final SetLocationVisibilityUsecase _setVisibility;

  Map<String, FriendLocationEntity> _friends = {};
  geo.Position? _myPosition;
  StreamSubscription<Map<String, FriendLocationEntity>>? _friendsSub;
  StreamSubscription<geo.Position>? _positionSub;
  String? _currentUserId;

  Map<String, FriendLocationEntity> get friends => Map.unmodifiable(_friends);
  geo.Position? get myPosition => _myPosition;

  Future<void> init(String userId) async {
    if (_currentUserId == userId) return;
    _currentUserId = userId;
    _friendsSub?.cancel();
    _friendsSub = _watchFriendLocations(userId).listen(
      (map) {
        _friends = map;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('[LocationProvider] friend locations stream error: $e');
      },
    );
  }

  Future<void> startPublishing(String userId, String visibility) async {
    if (visibility == 'none') return;
    _positionSub?.cancel();

    if (!await geo.Geolocator.isLocationServiceEnabled()) { return; }
    final permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied ||
        permission == geo.LocationPermission.deniedForever) { return; }

    _positionSub = geo.Geolocator.getPositionStream(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(
      (pos) async {
        _myPosition = pos;
        notifyListeners();
        await _publishLocation(userId, pos.latitude, pos.longitude);
      },
      onError: (e) {
        debugPrint('[LocationProvider] position stream error: $e');
      },
    );
  }

  Future<void> stopPublishing() async {
    await _positionSub?.cancel();
    _positionSub = null;
    if (_currentUserId != null) {
      await _deleteLocation(_currentUserId!);
    }
  }

  Future<void> updateVisibility(String userId, String newVisibility) async {
    await _setVisibility(userId, newVisibility);
    if (newVisibility == 'none') {
      await stopPublishing();
    } else {
      await startPublishing(userId, newVisibility);
    }
  }

  @override
  void dispose() {
    _friendsSub?.cancel();
    _positionSub?.cancel();
    super.dispose();
  }
}
