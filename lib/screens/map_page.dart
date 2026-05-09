import 'dart:async';

import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:vasco/helpers/mapbox_helper.dart';
import 'package:vasco/services/photo_service.dart';
import 'package:vasco/services/location_groups_service.dart';
import 'package:vasco/widgets/story_viewer.dart';
import 'package:vasco/screens/user_profile_screen.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vasco/models/user_model.dart';
import '../providers/user_provider.dart';

class MapPage extends StatefulWidget {
  final String? userId;
  const MapPage({super.key, this.userId});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  bool _isLoading = true;

  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  PointAnnotation? _userAnnotation;

  String? _geoJsonString;
  Map<String, dynamic>? _geoJsonData;

  geo.Position? _currentPosition;
  StreamSubscription<geo.Position>? _positionStream;
  Uint8List? _cachedProfileImage;

  List<Map<String, String>> _sharedCountries = [];
  bool _heatmapVisible = true;

  final Map<String, PointAnnotation> _friendAnnotations = {};
  final Map<String, StreamSubscription<dynamic>> _friendLocationSubs = {};
  final Map<String, Uint8List> _friendAvatarCache = {};
  final Map<String, Map<String, String?>> _friendData = {};
  final Map<String, Point> _friendMapPoints = {};
  StreamSubscription<dynamic>? _friendsListSub;
  StreamSubscription<DocumentSnapshot>? _userDocSub;
  String _locationVisibility = 'all';
  String? _currentUserIdForLocationCleanup;
  UserModel? _currentUser;

  final Completer<void> _mapReadyCompleter = Completer<void>();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _currentUser = Provider.of<UserProvider>(context).user;
    _currentUserIdForLocationCleanup ??= _currentUser?.id;
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _userDocSub?.cancel();
    _friendsListSub?.cancel();
    for (final sub in _friendLocationSubs.values) {
      sub.cancel();
    }
    if (widget.userId == null) {
      final uid = _currentUserIdForLocationCleanup;
      if (uid != null) {
        FirebaseFirestore.instance
            .collection('user_locations')
            .doc(uid)
            .delete();
      }
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (widget.userId != null) {
      await _loadGeoJson();
    } else {
      await Future.wait([_loadGeoJson(), _initLocationAndImage()]);
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
    await _mapReadyCompleter.future;
    if (!mounted) return;
    if (widget.userId == null) _startPositionStream();
  }

  Future<void> _initLocationAndImage() async {
    await _maybeShowFirstLaunchDialog();
    if (!mounted) return;
    final pos = await _getLocationWithPermission();
    if (!mounted) return;
    if (pos == null) return;
    _currentPosition = pos;
    _cachedProfileImage = await _buildProfileImage();
  }

  Future<void> _loadGeoJson() async {
    _geoJsonString = await rootBundle.loadString('assets/custom.geo.json');
    _geoJsonData = json.decode(_geoJsonString!) as Map<String, dynamic>;
  }

  Future<geo.Position?> _getLocationWithPermission() async {
    if (!await geo.Geolocator.isLocationServiceEnabled()) return null;
    geo.LocationPermission perm = await geo.Geolocator.checkPermission();
    if (perm == geo.LocationPermission.denied) {
      perm = await geo.Geolocator.requestPermission();
      if (perm == geo.LocationPermission.denied) return null;
    }
    if (perm == geo.LocationPermission.deniedForever) return null;
    try {
      return await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  void _startPositionStream() {
    _positionStream =
        geo.Geolocator.getPositionStream(
          locationSettings: const geo.LocationSettings(
            accuracy: geo.LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen(
          (geo.Position position) async {
            if (!mounted) return;
            setState(() => _currentPosition = position);
            await _refreshUserAnnotation(position);
            _publishMyLocation(position);
          },
          onError: (error, stackTrace) {
            debugPrint('[MapPage] position stream error: $error');
          },
        );
  }

  void _publishMyLocation(geo.Position pos) {
    if (_locationVisibility == 'none') return;
    final user = _currentUser;
    if (user == null) return;
    FirebaseFirestore.instance.collection('user_locations').doc(user.id).set({
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'updatedAt': FieldValue.serverTimestamp(),
      'sharedGroupId': _locationVisibility,
    }, SetOptions(merge: true));
  }

  bool _isCurrentCountryUnlocked(geo.Position pos) {
    if (_geoJsonData == null) return false;
    final detected = MapboxHelper.detectCountry(
      pos.latitude,
      pos.longitude,
      _geoJsonData!,
    );
    if (detected == null) return false;
    return _sharedCountries.any((c) => c['value'] == detected['value']);
  }

  Future<void> _refreshUserAnnotation(geo.Position position) async {
    if (_pointAnnotationManager == null || _cachedProfileImage == null) return;

    final unlocked = _isCurrentCountryUnlocked(position);

    if (!unlocked) {
      if (_userAnnotation != null) {
        await _pointAnnotationManager!.delete(_userAnnotation!);
        _userAnnotation = null;
      }
      return;
    }

    final point = Point(
      coordinates: Position(position.longitude, position.latitude),
    );

    if (_userAnnotation == null) {
      _userAnnotation = await _pointAnnotationManager!.create(
        PointAnnotationOptions(
          geometry: point,
          image: _cachedProfileImage,
          iconSize: 1.0,
          iconAnchor: IconAnchor.CENTER,
        ),
      );
    } else {
      _userAnnotation!.geometry = point;
      await _pointAnnotationManager!.update(_userAnnotation!);
    }
  }

  void _startWatchingFriends() {
    if (widget.userId != null) return;
    final user = _currentUser;
    if (user == null) return;

    _friendsListSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.id)
        .collection('friends')
        .snapshots()
        .listen(
          (snap) async {
            if (!mounted) return;
            final currentIds = snap.docs
                .map((d) => d['userId'] as String)
                .toSet();

            // Cancel subs for removed friends and delete their annotations
            for (final id in _friendLocationSubs.keys.toList()) {
              if (!currentIds.contains(id)) {
                await _friendLocationSubs[id]?.cancel();
                _friendLocationSubs.remove(id);
                _friendAvatarCache.remove(id);
                _friendData.remove(id);
                _friendMapPoints.remove(id);
                final ann = _friendAnnotations.remove(id);
                if (ann != null) await _pointAnnotationManager?.delete(ann);
              }
            }

            // Subscribe to new friends
            for (final doc in snap.docs) {
              final friendId = doc['userId'] as String;
              if (_friendLocationSubs.containsKey(friendId)) continue;

              // Fetch profile
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(friendId)
                  .get();
              if (!userDoc.exists || !mounted) continue;
              final data = userDoc.data()!;
              final photoUrl = data['photoUrl'] as String?;
              final displayName = data['displayName'] as String?;

              _friendData[friendId] = {
                'displayName': displayName,
                'photoUrl': photoUrl,
              };
              _friendAvatarCache[friendId] = await _buildFriendAvatar(
                photoUrl,
                displayName,
              );

              _friendLocationSubs[friendId] = FirebaseFirestore.instance
                  .collection('user_locations')
                  .doc(friendId)
                  .snapshots()
                  .listen(
                    (locDoc) async {
                      if (!mounted) return;
                      if (!locDoc.exists) {
                        final ann = _friendAnnotations.remove(friendId);
                        if (ann != null) {
                          await _pointAnnotationManager?.delete(ann);
                        }
                        return;
                      }
                      final lat = (locDoc['latitude'] as num).toDouble();
                      final lng = (locDoc['longitude'] as num).toDouble();
                      await _updateFriendAnnotation(friendId, lat, lng);
                    },
                    onError: (error, stackTrace) {
                      debugPrint(
                        '[MapPage] friend location stream error for $friendId: $error',
                      );
                    },
                  );
            }
          },
          onError: (error, stackTrace) {
            debugPrint('[MapPage] friends list stream error: $error');
          },
        );
  }

  Future<Uint8List> _buildFriendAvatar(
    String? photoUrl,
    String? displayName,
  ) async {
    const int size = 80;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    );
    final paint = Paint()..isAntiAlias = true;

    paint.color = Colors.white;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, paint);
    paint.color = const Color(0xFF22C55E); // green border
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 2, paint);

    if (photoUrl != null && photoUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(photoUrl));
        if (response.statusCode == 200) {
          final codec = await ui.instantiateImageCodec(
            response.bodyBytes,
            targetWidth: size,
            targetHeight: size,
          );
          final frame = await codec.getNextFrame();
          final img = frame.image;
          canvas.save();
          canvas.clipPath(
            Path()..addOval(
              Rect.fromCircle(
                center: const Offset(size / 2, size / 2),
                radius: size / 2 - 4,
              ),
            ),
          );
          canvas.drawImageRect(
            img,
            Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
            const Rect.fromLTRB(4, 4, size - 4, size - 4),
            paint,
          );
          canvas.restore();
        } else {
          _drawFallbackIcon(canvas, size);
        }
      } catch (_) {
        _drawFallbackIcon(canvas, size);
      }
    } else {
      _drawFallbackIcon(canvas, size);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _updateFriendAnnotation(
    String friendId,
    double lat,
    double lng,
  ) async {
    if (_pointAnnotationManager == null) return;
    final avatar = _friendAvatarCache[friendId];
    if (avatar == null) return;
    final point = Point(coordinates: Position(lng, lat));
    _friendMapPoints[friendId] = point;
    if (_friendAnnotations.containsKey(friendId)) {
      _friendAnnotations[friendId]!.geometry = point;
      await _pointAnnotationManager!.update(_friendAnnotations[friendId]!);
    } else {
      _friendAnnotations[friendId] = await _pointAnnotationManager!.create(
        PointAnnotationOptions(
          geometry: point,
          image: avatar,
          iconSize: 0.9,
          iconAnchor: IconAnchor.BOTTOM,
        ),
      );
    }
  }

  Future<void> _refreshHeatmapLayer() async {
    if (_mapboxMap == null) return;

    try {
      if (await _mapboxMap!.style.styleLayerExists("photos-heatmap")) {
        await _mapboxMap!.style.removeStyleLayer("photos-heatmap");
      }
      if (await _mapboxMap!.style.styleSourceExists("photos-source")) {
        await _mapboxMap!.style.removeStyleSource("photos-source");
      }
    } catch (_) {}

    if (!mounted) return;
    final user = _currentUser;
    final filterUserId = widget.userId ?? user?.id;
    final photos = await MyPhotoService.fetchAllPhotos(
      onlyUserId: filterUserId,
    );

    if (photos.isEmpty) return;

    final features = photos.map((photo) {
      final lat = (photo['latitude'] as num).toDouble();
      final lng = (photo['longitude'] as num).toDouble();
      return {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [lng, lat],
        },
        'properties': {},
      };
    }).toList();

    await _mapboxMap!.style.addSource(
      GeoJsonSource(
        id: "photos-source",
        data: jsonEncode({'type': 'FeatureCollection', 'features': features}),
      ),
    );

    await _mapboxMap!.style.addStyleLayer(
      jsonEncode({
        'id': 'photos-heatmap',
        'type': 'heatmap',
        'source': 'photos-source',
        'paint': {
          'heatmap-radius': [
            'interpolate',
            ['linear'],
            ['zoom'],
            0,
            4,
            8,
            25,
            13,
            55,
            16,
            90,
          ],
          'heatmap-intensity': [
            'interpolate',
            ['linear'],
            ['zoom'],
            0,
            0.8,
            13,
            2.0,
          ],
          'heatmap-opacity': 0.88,
          'heatmap-color': [
            'interpolate',
            ['linear'],
            ['heatmap-density'],
            0,
            'rgba(0,0,0,0)',
            0.10,
            'rgba(65,105,225,0.35)',
            0.25,
            'rgba(0,191,255,0.60)',
            0.45,
            'rgba(0,230,180,0.75)',
            0.65,
            'rgba(220,240,0,0.85)',
            0.82,
            'rgba(255,150,0,0.92)',
            1.0,
            'rgb(255,20,0)',
          ],
        },
      }),
      null,
    );
  }

  void _onMapTap(MapContentGestureContext gestureContext) async {
    final tapScreen = gestureContext.touchPosition;
    final user = _currentUser;

    // Check if tapped on a friend avatar (44px hit area)
    for (final entry in _friendMapPoints.entries) {
      try {
        final friendScreen = await _mapboxMap!.pixelForCoordinate(entry.value);
        final dx = (tapScreen.x - friendScreen.x).abs();
        final dy = (tapScreen.y - friendScreen.y).abs();
        if (dx < 44 && dy < 44) {
          if (!mounted) return;
          final data = _friendData[entry.key];
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => UserProfileScreen(
                userId: entry.key,
                initialDisplayName: data?['displayName'],
                initialPhotoUrl: data?['photoUrl'],
              ),
            ),
          );
          return;
        }
      } catch (_) {}
    }

    final tappedLat = gestureContext.point.coordinates.lat.toDouble();
    final tappedLng = gestureContext.point.coordinates.lng.toDouble();

    final filterUserId = widget.userId ?? user?.id;
    final nearbyPhotos = await MyPhotoService.fetchPhotosNear(
      latitude: tappedLat,
      longitude: tappedLng,
      radiusKm: 1.0,
      onlyUserId: filterUserId,
    );

    if (nearbyPhotos.isEmpty) return;
    if (!mounted) return;

    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, _, _) => StoryViewer(photos: nearbyPhotos),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Future<Uint8List> _buildProfileImage() async {
    final user = _currentUser;
    final photoUrl = user?.photoUrl;

    const int size = 96;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    );
    final paint = Paint()..isAntiAlias = true;

    paint.color = Colors.white;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, paint);
    paint.color = Colors.blue.shade400;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 3, paint);

    if (photoUrl != null && photoUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(photoUrl));
        if (response.statusCode == 200) {
          final codec = await ui.instantiateImageCodec(
            response.bodyBytes,
            targetWidth: size,
            targetHeight: size,
          );
          final frame = await codec.getNextFrame();
          final img = frame.image;
          final clipPath = Path()
            ..addOval(
              Rect.fromCircle(
                center: const Offset(size / 2, size / 2),
                radius: size / 2 - 4,
              ),
            );
          canvas.save();
          canvas.clipPath(clipPath);
          canvas.drawImageRect(
            img,
            Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
            const Rect.fromLTRB(4, 4, size - 4, size - 4),
            paint,
          );
          canvas.restore();
        } else {
          _drawFallbackIcon(canvas, size);
        }
      } catch (_) {
        _drawFallbackIcon(canvas, size);
      }
    } else {
      _drawFallbackIcon(canvas, size);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  void _drawFallbackIcon(Canvas canvas, int size) {
    final paint = Paint()
      ..color = Colors.white
      ..isAntiAlias = true;
    canvas.drawCircle(Offset(size / 2, size / 2 - 8), 16, paint);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size / 2, size / 2 + 20),
        width: 40,
        height: 30,
      ),
      3.14159,
      3.14159,
      true,
      paint,
    );
  }

  Future<void> _loadSharedCountriesAndColor() async {
    final user = _currentUser;
    final targetId = widget.userId ?? user?.id;
    if (targetId == null || _mapboxMap == null) return;

    if (widget.userId == null) {
      // Harta proprie: stream real-time — se recolorează instant la schimbări
      _userDocSub?.cancel();
      _userDocSub = FirebaseFirestore.instance
          .collection('users')
          .doc(targetId)
          .snapshots()
          .listen(
            (doc) async {
              if (!doc.exists || !mounted) return;
              final data = doc.data();
              if (data == null) return;
              final raw = data['shared_countries'];
              final newCountries = raw != null
                  ? (raw as List<dynamic>)
                        .map((e) => Map<String, String>.from(e))
                        .toList()
                  : <Map<String, String>>[];
              if (_mapboxMap == null) return;
              _sharedCountries = newCountries;
              await MapboxHelper.colorCountries(_mapboxMap, _sharedCountries);
              if (_currentPosition != null) {
                await _refreshUserAnnotation(_currentPosition!);
              }
            },
            onError: (error, stackTrace) {
              debugPrint('[MapPage] user document stream error: $error');
            },
          );
    } else {
      // Harta altui utilizator: citire unică
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(targetId)
          .get();
      final data = doc.data();
      if (data != null && data['shared_countries'] != null) {
        final List<dynamic> list = data['shared_countries'];
        _sharedCountries = list
            .map((e) => Map<String, String>.from(e))
            .toList();
        await MapboxHelper.colorCountries(_mapboxMap, _sharedCountries);
      }
    }

    await _refreshHeatmapLayer();

    if (widget.userId == null) {
      final uid = user?.id;
      if (uid != null) {
        _locationVisibility = await LocationGroupsService.getVisibility(uid);
      }
      _startWatchingFriends();
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    _pointAnnotationManager = await mapboxMap.annotations
        .createPointAnnotationManager();

    mapboxMap.setOnMapTapListener(_onMapTap);

    if (!_mapReadyCompleter.isCompleted) _mapReadyCompleter.complete();

    await MapboxHelper.initFeatureState(mapboxMap);

    await mapboxMap.flyTo(
      CameraOptions(center: Point(coordinates: Position(0, 20)), zoom: 1.0),
      MapAnimationOptions(duration: 800),
    );

    await _loadSharedCountriesAndColor();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.travel_explore_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Se încarcă harta...',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const SizedBox(
                    width: 120,
                    child: LinearProgressIndicator(
                      color: Color(0xFF4F46E5),
                      backgroundColor: Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                MapWidget(
                  styleUri: "mapbox://styles/eneawss/cmnw92pjy000p01s78vso81m0",
                  gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                    Factory<OneSequenceGestureRecognizer>(
                      () => EagerGestureRecognizer(),
                    ),
                  },
                  onMapCreated: _onMapCreated,
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 12,
                  left: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: widget.userId != null
                        ? IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios_rounded,
                              size: 20,
                              color: Color(0xFF111827),
                            ),
                            onPressed: () => Navigator.pop(context),
                          )
                        : IconButton(
                            icon: Icon(
                              _heatmapVisible
                                  ? Icons.layers
                                  : Icons.layers_clear,
                              size: 22,
                              color: _heatmapVisible
                                  ? const Color(0xFF4F46E5)
                                  : Colors.grey.shade400,
                            ),
                            onPressed: _toggleHeatmapVisibility,
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _maybeShowFirstLaunchDialog() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('map_permission_dialog_shown') ?? false) return;
    await prefs.setBool('map_permission_dialog_shown', true);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.travel_explore_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Permisiuni necesare',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pentru a folosi harta avem nevoie de câteva permisiuni.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 20),
              _permissionRow(
                Icons.location_on_rounded,
                const Color(0xFFEEF2FF),
                const Color(0xFF4F46E5),
                'Locație',
                'Îți afișăm poziția pe hartă și o partajăm în timp real.',
              ),
              const SizedBox(height: 12),
              _permissionRow(
                Icons.people_rounded,
                const Color(0xFFF0FDF4),
                const Color(0xFF16A34A),
                'Prieteni',
                'Locația ta va fi vizibilă prietenilor tăi pe hartă.',
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Permite',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _permissionRow(
    IconData icon,
    Color bg,
    Color color,
    String title,
    String subtitle,
  ) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Color(0xFF111827),
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _toggleHeatmapVisibility() async {
    setState(() => _heatmapVisible = !_heatmapVisible);
    if (_mapboxMap == null) return;
    try {
      if (await _mapboxMap!.style.styleLayerExists("photos-heatmap")) {
        await _mapboxMap!.style.setStyleLayerProperty(
          "photos-heatmap",
          "heatmap-opacity",
          jsonEncode(_heatmapVisible ? 0.88 : 0.0),
        );
      }
    } catch (_) {}
  }
}
