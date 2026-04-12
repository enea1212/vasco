import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}


class _MapPageState extends State<MapPage> {
  bool _isLoading = true;
  MapboxMap? _mapboxMap;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      await geo.Geolocator.requestPermission();
    }
    setState(() => _isLoading = false);
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                MapWidget(
                  styleUri: "mapbox://styles/eneawss/cmnuakps2000301r3evyohdi9",
                  gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                    Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
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
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}