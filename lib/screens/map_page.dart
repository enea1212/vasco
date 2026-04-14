import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:geolocator/geolocator.dart' as geo;

class MapPage extends StatefulWidget {
  const MapPage({Key? key}) : super(key: key);

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  bool _isLoading = true;
  MapboxMap? _mapboxMap;
  geo.Position? _currentPosition;
  PointAnnotationManager? _pointAnnotationManager;
  bool _mapReady = false;
  MapboxMap? _mapboxMapTab2;
  String? _geoJsonString;
  bool _geoJsonLoaded = false;

  // FIX 1: Store decoded GeoJSON as Map to avoid double-decode
  Map<String, dynamic>? _geoJsonData;

  @override
  void initState() {
    super.initState();
    _loadGeoJson();
  }

  Future<void> _loadGeoJson() async {
    _geoJsonString = await rootBundle.loadString('assets/custom.geo.json');
    // FIX 1: Decode once and store
    _geoJsonData = json.decode(_geoJsonString!) as Map<String, dynamic>;
    setState(() {
      _geoJsonLoaded = true;
      _isLoading = false;
    });
  }

  // FIX 2: Request location permission explicitly before getting position
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
            content: Text('Permisiunea de localizare este blocată permanent. Activează din Setări.'),
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.map), text: 'Harta'),
              Tab(icon: Icon(Icons.public), text: 'Glob'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  // Tab 1: Harta actuala cu functionalitati
                  Stack(
                    children: [
                      MapWidget(
                        styleUri: "mapbox://styles/eneawss/cmnuakps2000301r3evyohdi9",
                        gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                          Factory<OneSequenceGestureRecognizer>(
                              () => EagerGestureRecognizer()),
                        },
                        onMapCreated: _onMapCreated,
                      ),
                      Positioned(
                        left: 16,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FloatingActionButton(
                                heroTag: 'zoom_in',
                                mini: true,
                                onPressed: _zoomIn,
                                child: const Icon(Icons.add),
                              ),
                              const SizedBox(height: 12),
                              FloatingActionButton(
                                heroTag: 'zoom_out',
                                mini: true,
                                onPressed: _zoomOut,
                                child: const Icon(Icons.remove),
                              ),
                              const SizedBox(height: 24),
                              FloatingActionButton(
                                heroTag: 'my_location',
                                mini: true,
                                backgroundColor: Colors.blue,
                                onPressed: _centerOnCurrentLocation,
                                child: const Icon(Icons.my_location),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Tab 2: Glob 3D
                  Stack(
                    children: [
                      MapWidget(
                        styleUri: "mapbox://styles/eneawss/cmnw92pjy000p01s78vso81m0",
                        gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                          Factory<OneSequenceGestureRecognizer>(
                              () => EagerGestureRecognizer()),
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
      ),
    );
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    setState(() {
      _mapReady = true;
    });
  }

  Future<void> _centerOnCurrentLocation() async {
    debugPrint('[DEBUG] Pressed My Location button');
    // FIX 2: Use the new permission-aware method
    final pos = await _getLocationWithPermission();
    if (pos == null) return;

    debugPrint('[DEBUG] Position obtained: ${pos.latitude}, ${pos.longitude}');
    setState(() {
      _currentPosition = pos;
    });
    await _tryCenterAndMarker();
  }

  Future<void> _zoomIn() async {
    if (_mapboxMap != null) {
      final cameraState = await _mapboxMap!.getCameraState();
      await _mapboxMap!.flyTo(
        CameraOptions(zoom: (cameraState.zoom ?? 0) + 1),
        MapAnimationOptions(duration: 300),
      );
    }
  }

  Future<void> _zoomOut() async {
    if (_mapboxMap != null) {
      final cameraState = await _mapboxMap!.getCameraState();
      await _mapboxMap!.flyTo(
        CameraOptions(zoom: (cameraState.zoom ?? 0) - 1),
        MapAnimationOptions(duration: 300),
      );
    }
  }

  Future<void> _tryCenterAndMarker() async {
    if (_mapboxMap == null || _currentPosition == null) {
      debugPrint('[DEBUG] mapboxMap or currentPosition is null');
      return;
    }
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

  void _onMapCreatedTab2(MapboxMap mapboxMap) async {
    _mapboxMapTab2 = mapboxMap;
    if (!_geoJsonLoaded || _geoJsonData == null) return;

    // FIX 1: Pass the raw string to GeoJsonSource (not the decoded object)
    await mapboxMap.style.addSource(GeoJsonSource(
      id: 'countries',
      data: _geoJsonString,
    ));
    await mapboxMap.style.addLayer(FillLayer(
      id: 'country-fill',
      sourceId: 'countries',
      fillColor: Colors.transparent.value,
      fillOpacity: 0.6,
    ));
  }

  Future<void> _shareLocationAndColorCountry() async {
    if (!_geoJsonLoaded || _geoJsonData == null || _mapboxMapTab2 == null) return;

    // FIX 2: Use permission-aware location getter
    final pos = await _getLocationWithPermission();
    if (pos == null) return;

    final double lat = pos.latitude;
    final double lng = pos.longitude;
    debugPrint('[DEBUG] Share location: lat=$lat, lng=$lng');

    // FIX 3: Try multiple known property keys for country identifier
    String? foundCountryKey;
    String? foundCountryValue;

    for (final feature in _geoJsonData!['features']) {
      final geometry = feature['geometry'];
      if (geometry == null) continue;
      final String type = geometry['type'] as String;

      bool found = false;

      if (type == 'Polygon') {
        final List rings = geometry['coordinates'] as List;
        if (_pointInPolygon(lng, lat, rings[0] as List)) {
          found = true;
        }
      } else if (type == 'MultiPolygon') {
        final List polygons = geometry['coordinates'] as List;
        for (final polygon in polygons) {
          final List rings = polygon as List;
          if (_pointInPolygon(lng, lat, rings[0] as List)) {
            found = true;
            break;
          }
        }
      }

      if (found) {
        final props = feature['properties'] as Map<String, dynamic>?;
        if (props != null) {
          // FIX 3: Try multiple possible property keys in order of preference
          for (final key in ['ISO3166-1-Alpha-3', 'ISO_A3', 'iso_a3', 'ADM0_A3', 'ISO3166-1-Alpha-2', 'ISO_A2', 'name', 'ADMIN']) {
            final val = props[key];
            if (val != null && val.toString().isNotEmpty && val.toString() != '-99') {
              foundCountryKey = key;
              foundCountryValue = val.toString();
              debugPrint('[DEBUG] Matched property: $key = $foundCountryValue');
              break;
            }
          }

          // Debug: print all available properties to help diagnose
          debugPrint('[DEBUG] All feature properties: ${props.keys.toList()}');
        }
        break;
      }
    }

    debugPrint('[DEBUG] Found key=$foundCountryKey value=$foundCountryValue');

    if (foundCountryKey != null && foundCountryValue != null) {
      // FIX 4: Serialize filter as JSON string to ensure correct Mapbox parsing
      final filterExpression = json.encode([
        "==",
        ["get", foundCountryKey],
        foundCountryValue,
      ]);

      try {
        await _mapboxMapTab2!.style.setStyleLayerProperty(
          'country-fill',
          'filter',
          filterExpression,
        );
        await _mapboxMapTab2!.style.setStyleLayerProperty(
          'country-fill',
          'fill-color',
          "#FFFFFF",
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Țara detectată: $foundCountryValue')),
          );
        }
      } catch (e) {
        debugPrint('[DEBUG] Error applying filter: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Eroare la aplicarea filtrului: $e')),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nu s-a putut detecta țara!')),
        );
      }
    }
  }

  /// Ray casting algorithm.
  bool _pointInPolygon(double lng, double lat, List ring) {
    bool inside = false;
    final int n = ring.length;
    int j = n - 1;
    for (int i = 0; i < n; i++) {
      final double xi = (ring[i][0] as num).toDouble();
      final double yi = (ring[i][1] as num).toDouble();
      final double xj = (ring[j][0] as num).toDouble();
      final double yj = (ring[j][1] as num).toDouble();

      final bool intersect = ((yi > lat) != (yj > lat)) &&
          (lng < (xj - xi) * (lat - yi) / (yj - yi + 1e-12) + xi);

      if (intersect) inside = !inside;
      j = i;
    }
    return inside;
  }
}