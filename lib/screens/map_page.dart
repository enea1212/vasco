import 'dart:async';

import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:vasco/helpers/mapbox_helper.dart';
import 'package:vasco/helpers/heatmap_helper.dart';
import 'package:vasco/services/photo_service.dart';
import 'package:vasco/widgets/story_viewer.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/user_provider.dart';

class MapPage extends StatefulWidget {
  const MapPage({Key? key}) : super(key: key);

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  bool _isLoading = true;

  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  CircleAnnotationManager? _circleAnnotationManager;
  PointAnnotation? _userAnnotation;

  String? _geoJsonString;
  Map<String, dynamic>? _geoJsonData;

  geo.Position? _currentPosition;
  StreamSubscription<geo.Position>? _positionStream;
  Uint8List? _cachedProfileImage;

  List<Map<String, String>> _sharedCountries = [];
  bool _showOnlyMine = false;

  final Completer<void> _mapReadyCompleter = Completer<void>();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await Future.wait([_loadGeoJson(), _initLocationAndImage()]);
    if (!mounted) return;
    setState(() => _isLoading = false);
    await _mapReadyCompleter.future;
    if (!mounted) return;
    _startPositionStream();
  }

  Future<void> _initLocationAndImage() async {
    final pos = await _getLocationWithPermission();
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
          desiredAccuracy: geo.LocationAccuracy.high);
    } catch (_) {
      return null;
    }
  }

  void _startPositionStream() {
    _positionStream = geo.Geolocator.getPositionStream(
      locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high, distanceFilter: 2),
    ).listen((geo.Position position) async {
      if (!mounted) return;
      setState(() => _currentPosition = position);
      await _refreshUserAnnotation(position);
    });
  }

  bool _isCurrentCountryUnlocked(geo.Position pos) {
    if (_geoJsonData == null) return false;
    final detected =
        MapboxHelper.detectCountry(pos.latitude, pos.longitude, _geoJsonData!);
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

    final point =
        Point(coordinates: Position(position.longitude, position.latitude));

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

  Future<void> _refreshHeatmapCircles() async {
    if (_circleAnnotationManager == null) return;
    await _circleAnnotationManager!.deleteAll();

    final user = Provider.of<UserProvider>(context, listen: false).user;
    final photos = await MyPhotoService.fetchAllPhotos(
      onlyUserId: _showOnlyMine ? user?.id : null,
    );

    if (photos.isEmpty) return;

    final clusters = <_Cluster>[];
    for (final photo in photos) {
      final lat = (photo['latitude'] as num).toDouble();
      final lng = (photo['longitude'] as num).toDouble();

      bool added = false;
      for (final cluster in clusters) {
        if (MyHeatmapHelper.distanceKm(lat, lng, cluster.lat, cluster.lng) < 0.5) {
          cluster.photos.add(photo);
          added = true;
          break;
        }
      }
      if (!added) {
        clusters.add(_Cluster(lat: lat, lng: lng, photos: [photo]));
      }
    }

    final maxCount =
        clusters.map((c) => c.photos.length).reduce((a, b) => a > b ? a : b);

    for (final cluster in clusters) {
      final intensity = cluster.photos.length / maxCount;
      final color = _heatColor(intensity);

      await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: Position(cluster.lng, cluster.lat)),
          circleRadius: 20.0 + intensity * 40.0,
          circleColor: color.value,
          circleOpacity: 0.55,
          circleBlur: 1.2,
        ),
      );
    }
  }

  Color _heatColor(double t) {
    if (t < 0.33) {
      return Color.lerp(Colors.blue.shade300, Colors.cyan.shade400, t / 0.33)!;
    } else if (t < 0.66) {
      return Color.lerp(
          Colors.cyan.shade400, Colors.yellow.shade600, (t - 0.33) / 0.33)!;
    } else {
      return Color.lerp(
          Colors.yellow.shade600, Colors.red.shade600, (t - 0.66) / 0.34)!;
    }
  }

  void _onMapTap(MapContentGestureContext gestureContext) async {
    final tappedLat = gestureContext.point.coordinates.lat.toDouble();
    final tappedLng = gestureContext.point.coordinates.lng.toDouble();

    final user = Provider.of<UserProvider>(context, listen: false).user;
    final nearbyPhotos = await MyPhotoService.fetchPhotosNear(
      latitude: tappedLat,
      longitude: tappedLng,
      radiusKm: 1.0,
      onlyUserId: _showOnlyMine ? user?.id : null,
    );

    if (nearbyPhotos.isEmpty) return;
    if (!mounted) return;

    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => StoryViewer(photos: nearbyPhotos),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Future<Uint8List> _buildProfileImage() async {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    final photoUrl = user?.photoUrl;

    const int size = 96;
    final recorder = ui.PictureRecorder();
    final canvas =
        Canvas(recorder, Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()));
    final paint = Paint()..isAntiAlias = true;

    paint.color = Colors.white;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, paint);
    paint.color = Colors.blue.shade400;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 3, paint);

    if (photoUrl != null && photoUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(photoUrl));
        if (response.statusCode == 200) {
          final codec = await ui.instantiateImageCodec(response.bodyBytes,
              targetWidth: size, targetHeight: size);
          final frame = await codec.getNextFrame();
          final img = frame.image;
          final clipPath = Path()
            ..addOval(Rect.fromCircle(
                center: const Offset(size / 2, size / 2),
                radius: size / 2 - 4));
          canvas.save();
          canvas.clipPath(clipPath);
          canvas.drawImageRect(
              img,
              Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
              const Rect.fromLTRB(4, 4, size - 4, size - 4),
              paint);
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
            center: Offset(size / 2, size / 2 + 20), width: 40, height: 30),
        3.14159,
        3.14159,
        true,
        paint);
  }



  Future<void> _loadSharedCountriesAndColor() async {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null || _mapboxMap == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.id)
        .get();
    final data = doc.data();
    if (data != null && data['shared_countries'] != null) {
      final List<dynamic> list = data['shared_countries'];
      _sharedCountries =
          list.map((e) => Map<String, String>.from(e)).toList();
      await MapboxHelper.colorCountries(_mapboxMap, _sharedCountries);
      if (_currentPosition != null) {
        await _refreshUserAnnotation(_currentPosition!);
      }
    }

    await _refreshHeatmapCircles();
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    _pointAnnotationManager =
        await mapboxMap.annotations.createPointAnnotationManager();
    _circleAnnotationManager =
        await mapboxMap.annotations.createCircleAnnotationManager();

    mapboxMap.setOnMapTapListener(_onMapTap);

    if (!_mapReadyCompleter.isCompleted) _mapReadyCompleter.complete();

    await MapboxHelper.initFeatureState(mapboxMap);

    await mapboxMap.flyTo(
      CameraOptions(
          center: Point(coordinates: Position(0, 20)), zoom: 1.0),
      MapAnimationOptions(duration: 800),
    );

    await _loadSharedCountriesAndColor();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                MapWidget(
                  styleUri:
                      "mapbox://styles/eneawss/cmnw92pjy000p01s78vso81m0",
                  gestureRecognizers:
                      <Factory<OneSequenceGestureRecognizer>>{
                    Factory<OneSequenceGestureRecognizer>(
                        () => EagerGestureRecognizer()),
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
                            offset: Offset(0, 2))
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _toggleBtn('Toți', !_showOnlyMine),
                        _toggleBtn('Ale mele', _showOnlyMine),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _toggleBtn(String label, bool active) {
    return GestureDetector(
      onTap: () async {
        setState(() => _showOnlyMine = label == 'Ale mele');
        await _refreshHeatmapCircles();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.blue.shade700 : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.grey.shade600,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _Cluster {
  final double lat;
  final double lng;
  final List<Map<String, dynamic>> photos;
  _Cluster({required this.lat, required this.lng, required this.photos});
}