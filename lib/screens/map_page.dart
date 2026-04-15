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

class _MapPageState extends State<MapPage> with TickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoading = true;

  // Tab 1 — Friends map
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  PointAnnotation? _userAnnotation;

  // Tab 2 — Heat map
  MapboxMap? _mapboxMapTab2;

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

  // Completer pentru a ști când harta Tab 1 e gata
  final Completer<void> _mapReadyCompleter = Completer<void>();

  bool _tab1CenteredOnce = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() async {
    if (!mounted) return;
    setState(() {}); // rebuild ca IndexedStack să schimbe indexul
    if (_tabController.index == 0 && !_tabController.indexIsChanging) {
      await _centerOnCurrentLocation();
      // Dacă există poziție și imagine, dar nu există annotation, recreează-l
      if (_currentPosition != null && _cachedProfileImage != null && _userAnnotation == null && _mapboxMap != null && _pointAnnotationManager != null) {
        await _updateUserAnnotation(_currentPosition!);
      }
    }
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

    if (_currentPosition == null || _cachedProfileImage == null) {
      debugPrint('[DEBUG] bootstrap: locație sau imagine lipsă');
      return;
    }

    await _mapReadyCompleter.future;
    if (!mounted) return;

    await _tryCenterAndMarker();
    if (!mounted) return;
    await _updateUserAnnotation(_currentPosition!);
    if (!mounted) return;

    _startPositionStream();
    _tab1CenteredOnce = true;
  }

  Future<void> _initLocationAndImage() async {
    final pos = await _getLocationWithPermission();
    if (pos == null) {
      debugPrint('[DEBUG] _initLocationAndImage: pos este NULL');
      return;
    }
    debugPrint('[DEBUG] _initLocationAndImage: pos=${pos.latitude}, ${pos.longitude}');
    _currentPosition = pos;
    _cachedProfileImage = await _buildProfileImage();
    // Dacă harta este deja creată și annotation-ul lipsește, recreează-l
    if (_mapboxMap != null && _pointAnnotationManager != null && _userAnnotation == null) {
      await _updateUserAnnotation(_currentPosition!);
    }
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
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Serviciul de localizare este dezactivat!')),
        );
      }
      return null;
    }

    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permisiunea de localizare a fost refuzată!')),
          );
        }
        return null;
      }
    }

    if (permission == geo.LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Permisiunea de localizare este blocată permanent. Activează din Setări.'),
          ),
        );
      }
      return null;
    }

    try {
      return await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
    } catch (e) {
      debugPrint('[DEBUG] Error getting position: $e');
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
      await _updateUserAnnotation(position);
    });
  }

  // ─────────────────────────────────────────────
  // Centrare & marker Tab 1
  // ─────────────────────────────────────────────

  Future<void> _centerOnCurrentLocation() async {
    final pos = await _getLocationWithPermission();
    if (pos == null) return;
    if (!mounted) return;
    setState(() => _currentPosition = pos);
    await _tryCenterAndMarker();
    if (!mounted) return;
    await _updateUserAnnotation(pos);
  }

  Future<void> _tryCenterAndMarker() async {
    if (_mapboxMap == null || _currentPosition == null) return;
    await _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(
            _currentPosition!.longitude,
            _currentPosition!.latitude,
          ),
        ),
        zoom: 14,
      ),
      MapAnimationOptions(duration: 500),
    );
  }

  // ─────────────────────────────────────────────
  // Annotation (poza utilizatorului)
  // ─────────────────────────────────────────────

  Future<void> _updateUserAnnotation(geo.Position position) async {
    if (_pointAnnotationManager == null) return;
    if (_cachedProfileImage == null) return;

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
      debugPrint(
          '[DEBUG] Annotation creat la: ${position.latitude}, ${position.longitude}');
    } else {
      _userAnnotation!.geometry = point;
      await _pointAnnotationManager!.update(_userAnnotation!);
      debugPrint(
          '[DEBUG] Annotation mutat la: ${position.latitude}, ${position.longitude}');
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
            ..addOval(Rect.fromCircle(
              center: const Offset(size / 2, size / 2),
              radius: size / 2 - 4,
            ));
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
        debugPrint('[DEBUG] Could not load profile image: $e');
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

  // ─────────────────────────────────────────────
  // Tab 2 — Share locație & colorare țări
  // ─────────────────────────────────────────────

  Future<void> _loadSharedCountriesAndColor() async {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null) return;
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(user.id).get();
    final data = doc.data();
    if (data != null && data['shared_countries'] != null) {
      final List<dynamic> list = data['shared_countries'];
      _sharedCountries =
          list.map((e) => Map<String, String>.from(e)).toList();
      await _colorAllSharedCountries();
    }
  }

  Future<void> _colorAllSharedCountries() async {
    await MapboxHelper.colorCountries(_mapboxMapTab2, _sharedCountries);
  }

  Future<void> _shareLocationAndColorCountry() async {
    if (!_geoJsonLoaded || _geoJsonData == null || _mapboxMapTab2 == null) return;

    final pos = await _getLocationWithPermission();
    if (pos == null) return;
    if (!mounted) return;

    final double lat = pos.latitude;
    final double lng = pos.longitude;
    final detected = MapboxHelper.detectCountry(lat, lng, _geoJsonData!);

    if (detected != null) {
      final user = Provider.of<UserProvider>(context, listen: false).user;
      if (user != null) {
        final docRef =
            FirebaseFirestore.instance.collection('users').doc(user.id);
        await docRef.set({
          'shared_countries': FieldValue.arrayUnion([detected]),
        }, SetOptions(merge: true));
        _sharedCountries.add(detected);
      }
      await MapboxHelper.colorCountries(_mapboxMapTab2, _sharedCountries);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Țara detectată și salvată: ${detected['value']}')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nu s-a putut detecta țara!')),
        );
      }
    }
  }

  // ─────────────────────────────────────────────
  // Callbacks hartă
  // ─────────────────────────────────────────────

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _userAnnotation = null;

    _pointAnnotationManager =
        await mapboxMap.annotations.createPointAnnotationManager();
    debugPrint('[DEBUG] _onMapCreated: manager pronto');

    if (!_mapReadyCompleter.isCompleted) {
      _mapReadyCompleter.complete();
    }

    if (_cachedProfileImage == null) {
      _cachedProfileImage = await _buildProfileImage();
    }

    if (_currentPosition != null) {
      if (!mounted) return;
      await _tryCenterAndMarker();
      if (!mounted) return;
      await _updateUserAnnotation(_currentPosition!);
    } else {
      final pos = await _getLocationWithPermission();
      if (pos != null && mounted) {
        setState(() => _currentPosition = pos);
        await _tryCenterAndMarker();
        if (!mounted) return;
        await _updateUserAnnotation(pos);
      }
    }

    _tab1CenteredOnce = true;
  }

  void _onMapCreatedTab2(MapboxMap mapboxMap) async {
    _mapboxMapTab2 = mapboxMap;
    if (!_geoJsonLoaded || _geoJsonData == null) return;
    await MapboxHelper.createCountryLayer(mapboxMap, _geoJsonString!);
    await mapboxMap.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(0, 20)),
        zoom: 1.0,
      ),
      MapAnimationOptions(duration: 800),
    );
    await _loadSharedCountriesAndColor();
  }

  // ─────────────────────────────────────────────
  // Zoom helpers
  // ─────────────────────────────────────────────

  Future<void> _zoomIn() async {
    if (_mapboxMap == null) return;
    final cameraState = await _mapboxMap!.getCameraState();
    await _mapboxMap!.flyTo(
      CameraOptions(zoom: (cameraState.zoom ?? 0) + 1),
      MapAnimationOptions(duration: 300),
    );
  }

  Future<void> _zoomOut() async {
    if (_mapboxMap == null) return;
    final cameraState = await _mapboxMap!.getCameraState();
    await _mapboxMap!.flyTo(
      CameraOptions(zoom: (cameraState.zoom ?? 0) - 1),
      MapAnimationOptions(duration: 300),
    );
  }

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 2,
        title: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: Colors.blue.shade50,
          ),
          labelColor: Colors.blue.shade900,
          unselectedLabelColor: Colors.grey.shade500,
          tabs: const [
            Tab(
              icon: Text('👥', style: TextStyle(fontSize: 22)),
              child: Text('Friends', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Tab(
              icon: Text('🌍', style: TextStyle(fontSize: 22)),
              child: Text('Heat Map', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                IndexedStack(
                  index: _tabController.index,
                  children: [
                    // Tab 1 — Friends
                    Stack(
                      children: [
                        MapWidget(
                          styleUri: "mapbox://styles/eneawss/cmnuakps2000301r3evyohdi9",
                          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                            Factory<OneSequenceGestureRecognizer>(
                              () => EagerGestureRecognizer(),
                            ),
                          },
                          onMapCreated: _onMapCreated,
                        ),
                      ],
                    ),
                    // Tab 2 — Heat Map
                    Stack(
                      children: [
                        MapWidget(
                          styleUri: "mapbox://styles/eneawss/cmnw92pjy000p01s78vso81m0",
                          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                            Factory<OneSequenceGestureRecognizer>(
                              () => EagerGestureRecognizer(),
                            ),
                          },
                          onMapCreated: _onMapCreatedTab2,
                        ),
                        Positioned(
                          right: 16,
                          top: 16,
                          child: FloatingActionButton.extended(
                            heroTag: 'share_location_tab2',
                            icon: const Icon(Icons.location_on),
                            label: const Text('Share Location'),
                            onPressed: _shareLocationAndColorCountry,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}