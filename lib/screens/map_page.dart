import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../helpers/mapbox_helper.dart';
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

  // Harta
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  PointAnnotation? _userAnnotation;

  // GeoJSON
  String? _geoJsonString;
  bool _geoJsonLoaded = false;
  Map<String, dynamic>? _geoJsonData;

  // Locație & imagine
  geo.Position? _currentPosition;
  StreamSubscription<geo.Position>? _positionStream;
  Uint8List? _cachedProfileImage;

  // Țări share-uite
  List<Map<String, String>> _sharedCountries = [];

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

  // ─────────────────────────────────────────────
  // Bootstrap
  // ─────────────────────────────────────────────

  Future<void> _bootstrap() async {
    await Future.wait([
      _loadGeoJson(),
      _initLocationAndImage(),
    ]);

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
    _geoJsonLoaded = true;
  }

  // ─────────────────────────────────────────────
  // Locație
  // ─────────────────────────────────────────────

  Future<geo.Position?> _getLocationWithPermission() async {
    bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) return null;
    }

    if (permission == geo.LocationPermission.deniedForever) return null;

    try {
      return await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
    } catch (e) {
      return null;
    }
  }

  void _startPositionStream() {
    _positionStream = geo.Geolocator.getPositionStream(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: 2,
      ),
    ).listen((geo.Position position) async {
      if (!mounted) return;
      setState(() => _currentPosition = position);
      await _refreshUserAnnotation(position);
    });
  }

  // ─────────────────────────────────────────────
  // Annotation — apare doar dacă țara e deblocată
  // ─────────────────────────────────────────────

  bool _isCurrentCountryUnlocked(geo.Position pos) {
    if (_geoJsonData == null) return false;
    final detected = MapboxHelper.detectCountry(pos.latitude, pos.longitude, _geoJsonData!);
    if (detected == null) return false;
    return _sharedCountries.any((c) => c['value'] == detected['value']);
  }

  Future<void> _refreshUserAnnotation(geo.Position position) async {
    if (_pointAnnotationManager == null || _cachedProfileImage == null) return;

    final unlocked = _isCurrentCountryUnlocked(position);

    if (!unlocked) {
      // Șterge annotation-ul dacă există
      if (_userAnnotation != null) {
        await _pointAnnotationManager!.delete(_userAnnotation!);
        _userAnnotation = null;
      }
      return;
    }

    final point = Point(coordinates: Position(position.longitude, position.latitude));

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

  // ─────────────────────────────────────────────
  // Imagine profil
  // ─────────────────────────────────────────────

  Future<Uint8List> _buildProfileImage() async {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    final photoUrl = user?.photoUrl;

    const int size = 96;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()));
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
              response.bodyBytes, targetWidth: size, targetHeight: size);
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
            paint,
          );
          canvas.restore();
        } else {
          _drawFallbackIcon(canvas, size);
        }
      } catch (e) {
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

  // ─────────────────────────────────────────────
  // Share & colorare țări
  // ─────────────────────────────────────────────

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

      // Dacă avem deja locație, actualizăm annotation-ul
      if (_currentPosition != null) {
        await _refreshUserAnnotation(_currentPosition!);
      }
    }
  }

  Future<void> _shareLocationAndColorCountry() async {
    if (!_geoJsonLoaded || _geoJsonData == null || _mapboxMap == null) return;

    final pos = await _getLocationWithPermission();
    if (pos == null) return;

    final detected =
        MapboxHelper.detectCountry(pos.latitude, pos.longitude, _geoJsonData!);

    if (detected != null) {
      final user =
          Provider.of<UserProvider>(context, listen: false).user;
      if (user != null) {
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.id);
        await docRef.set({
          'shared_countries': FieldValue.arrayUnion([detected]),
        }, SetOptions(merge: true));

        if (!_sharedCountries.any((c) => c['value'] == detected['value'])) {
          _sharedCountries.add(detected);
        }
      }

      await MapboxHelper.colorCountries(_mapboxMap, _sharedCountries);

      // Acum că țara e deblocată, adaugă annotation-ul
      if (_currentPosition != null) {
        await _refreshUserAnnotation(_currentPosition!);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Țară detectată: ${detected['value']}')));
      }
    }
  }

  // ─────────────────────────────────────────────
  // Callback hartă
  // ─────────────────────────────────────────────

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _pointAnnotationManager =
        await mapboxMap.annotations.createPointAnnotationManager();

    if (!_mapReadyCompleter.isCompleted) _mapReadyCompleter.complete();

    await MapboxHelper.initFeatureState(mapboxMap);

    await mapboxMap.flyTo(
      CameraOptions(
          center: Point(coordinates: Position(0, 20)), zoom: 1.0),
      MapAnimationOptions(duration: 800),
    );

    await _loadSharedCountriesAndColor();
  }

  // ─────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────

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
                  gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                    Factory<OneSequenceGestureRecognizer>(
                        () => EagerGestureRecognizer()),
                  },
                  onMapCreated: _onMapCreated,
                ),
                Positioned(
                  right: 16,
                  top: 16,
                  child: FloatingActionButton.extended(
                    heroTag: 'share_location',
                    icon: const Icon(Icons.location_on),
                    label: const Text('Share Location'),
                    onPressed: _shareLocationAndColorCountry,
                  ),
                ),
              ],
            ),
    );
  }
}