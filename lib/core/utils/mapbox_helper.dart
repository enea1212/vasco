import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class MapboxHelper {
  static const String _sourceId = 'composite';
  static const String _sourceLayer = 'country_boundaries';
  static const String _blueLayerId = 'country-boundaries copy';

  static final List<String> _visitedIsoCodes = [];
  static String? _detectedBorderLayerId;

  static Future<void> initFeatureState(MapboxMap map) async {
    await _detectBorderLayer(map);
    await _applyFilter(map);
  }

  static Future<void> _detectBorderLayer(MapboxMap map) async {
    try {
      final layers = await map.style.getStyleLayers();
      for (final layer in layers) {
        final layerId = layer?.id;
        if (layerId == null || layerId == _blueLayerId) continue;
        try {
          final sourceLayerProp = await map.style.getStyleLayerProperty(layerId, 'source-layer');
          final sourceProp = await map.style.getStyleLayerProperty(layerId, 'source');
          final sourceLayerVal = sourceLayerProp.value?.toString() ?? '';
          final sourceVal = sourceProp.value?.toString() ?? '';
          if (sourceLayerVal.contains(_sourceLayer) && sourceVal.contains(_sourceId)) {
            _detectedBorderLayerId = layerId;
            debugPrint('[DEBUG] Border layer detectat: $layerId');
            break;
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[DEBUG] Nu s-a putut detecta border layer: $e');
    }
  }

  static Future<void> colorCountries(
      MapboxMap? map, List<Map<String, String>> countries) async {
    if (map == null) return;
    _visitedIsoCodes.clear();
    for (final country in countries) {
      final String? isoValue = country['value'];
      if (isoValue != null && isoValue.isNotEmpty) {
        _visitedIsoCodes.add(isoValue);
      }
    }
    await _applyFilter(map);
  }

  static Future<void> _applyFilter(MapboxMap map) async {
    try {
      final String filterJson;
      if (_visitedIsoCodes.isEmpty) {
        filterJson = json.encode(['all']);
      } else {
        final List<dynamic> filterExpression = [
          'all',
          ...(_visitedIsoCodes.map((iso) => [
                '!=',
                ['get', 'iso_3166_1'],
                iso,
              ]))
        ];
        filterJson = json.encode(filterExpression);
        debugPrint('[DEBUG] Filtru aplicat pentru: $_visitedIsoCodes');
      }
      await map.style.setStyleLayerProperty(_blueLayerId, 'filter', filterJson);
      if (_detectedBorderLayerId != null) {
        try {
          await map.style.setStyleLayerProperty(
              _detectedBorderLayerId!, 'filter', filterJson);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[DEBUG] Eroare la aplicarea filtrului: $e');
    }
  }

  static Map<String, String>? detectCountry(
      double lat, double lng, Map<String, dynamic> geoJsonData) {
    for (final feature in geoJsonData['features']) {
      final geometry = feature['geometry'];
      if (geometry == null) continue;
      final String type = geometry['type'] as String;
      bool found = false;
      if (type == 'Polygon') {
        final List rings = geometry['coordinates'] as List;
        if (_pointInPolygon(lng, lat, rings[0] as List)) found = true;
      } else if (type == 'MultiPolygon') {
        final List polygons = geometry['coordinates'] as List;
        for (final polygon in polygons) {
          if (_pointInPolygon(lng, lat, (polygon as List)[0] as List)) {
            found = true;
            break;
          }
        }
      }
      if (found) {
        final props = feature['properties'] as Map<String, dynamic>?;
        if (props != null) {
          for (final key in ['ISO3166-1-Alpha-2', 'ISO_A2', 'iso_a2']) {
            final val = props[key];
            if (val != null && val.toString().isNotEmpty && val.toString() != '-99') {
              return {'key': 'ISO_A2', 'value': val.toString()};
            }
          }
        }
      }
    }
    return null;
  }

  static bool _pointInPolygon(double lng, double lat, List ring) {
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
