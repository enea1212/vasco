import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;

class FriendLocationData {
  final double? latitude;
  final double? longitude;
  final String? displayName;
  final String? photoUrl;

  const FriendLocationData({
    this.latitude,
    this.longitude,
    this.displayName,
    this.photoUrl,
  });

  bool get hasLocation => latitude != null && longitude != null;

  FriendLocationData withLocation(double lat, double lng) => FriendLocationData(
    latitude: lat,
    longitude: lng,
    displayName: displayName,
    photoUrl: photoUrl,
  );

  FriendLocationData withoutLocation() => FriendLocationData(
    displayName: displayName,
    photoUrl: photoUrl,
  );
}

class FriendLocationProvider with ChangeNotifier {
  final Map<String, FriendLocationData> _friends = {};
  final Map<String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
  _locationSubs = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _friendsListSub;
  StreamSubscription<geo.Position>? _positionSub;
  String? _currentUserId;
  geo.Position? _myPosition;
  String _locationVisibility = 'all';

  Map<String, FriendLocationData> get friends => Map.unmodifiable(_friends);
  geo.Position? get myPosition => _myPosition;

  void init(String userId) {
    if (_currentUserId == userId) return;
    _stopAll();
    _currentUserId = userId;

    _friendsListSub = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('friends')
        .snapshots()
        .listen(
          (snap) async {
            final currentIds =
                snap.docs.map((d) => d['userId'] as String).toSet();

            for (final id in _locationSubs.keys.toList()) {
              if (!currentIds.contains(id)) {
                _locationSubs[id]?.cancel();
                _locationSubs.remove(id);
                _friends.remove(id);
              }
            }

            for (final doc in snap.docs) {
              final friendId = doc['userId'] as String;
              if (_locationSubs.containsKey(friendId)) continue;

              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(friendId)
                  .get();

              if (!userDoc.exists) continue;
              final data = userDoc.data()!;
              _friends[friendId] = FriendLocationData(
                displayName: data['displayName'] as String?,
                photoUrl: data['photoUrl'] as String?,
              );

              _locationSubs[friendId] = FirebaseFirestore.instance
                  .collection('user_locations')
                  .doc(friendId)
                  .snapshots()
                  .listen(
                    (locDoc) {
                      if (!locDoc.exists) {
                        final existing = _friends[friendId];
                        if (existing != null && existing.hasLocation) {
                          _friends[friendId] = existing.withoutLocation();
                          notifyListeners();
                        }
                      } else {
                        final d = locDoc.data()!;
                        final lat = (d['latitude'] as num).toDouble();
                        final lng = (d['longitude'] as num).toDouble();
                        final existing = _friends[friendId];
                        if (existing != null) {
                          _friends[friendId] = existing.withLocation(lat, lng);
                          notifyListeners();
                        }
                      }
                    },
                    onError: (e) => debugPrint(
                      '[FriendLocationProvider] location error for $friendId: $e',
                    ),
                  );
            }

            notifyListeners();
          },
          onError: (e) =>
              debugPrint('[FriendLocationProvider] friends list error: $e'),
        );
  }

  Future<void> startPublishing(String userId, String visibility) async {
    _locationVisibility = visibility;
    _positionSub?.cancel();
    _positionSub = null;
    if (visibility == 'none') return;

    if (!await geo.Geolocator.isLocationServiceEnabled()) {
      return;
    }
    final perm = await geo.Geolocator.checkPermission();
    if (perm == geo.LocationPermission.denied ||
        perm == geo.LocationPermission.deniedForever) {
      return;
    }

    _positionSub = geo.Geolocator.getPositionStream(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(
      (pos) {
        _myPosition = pos;
        FirebaseFirestore.instance
            .collection('user_locations')
            .doc(userId)
            .set({
              'latitude': pos.latitude,
              'longitude': pos.longitude,
              'updatedAt': FieldValue.serverTimestamp(),
              'sharedGroupId': _locationVisibility,
            }, SetOptions(merge: true));
        notifyListeners();
      },
      onError: (e) =>
          debugPrint('[FriendLocationProvider] position stream error: $e'),
    );
  }

  void stopPublishing() {
    _positionSub?.cancel();
    _positionSub = null;
  }

  Future<void> updateVisibility(String userId, String visibility) async {
    _locationVisibility = visibility;
    if (visibility == 'none') {
      stopPublishing();
    } else {
      await startPublishing(userId, visibility);
    }
  }

  void _stopAll() {
    _friendsListSub?.cancel();
    _friendsListSub = null;
    for (final sub in _locationSubs.values) {
      sub.cancel();
    }
    _locationSubs.clear();
    _positionSub?.cancel();
    _positionSub = null;
    _friends.clear();
    _myPosition = null;
    _currentUserId = null;
  }

  @override
  void dispose() {
    _stopAll();
    super.dispose();
  }
}
