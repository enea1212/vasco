import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'dart:convert';

class MapboxHelper {
    /// Ascunde complet overlay-ul peste țări (fără să șteargă layerul)
    static Future<void> removeCountryLayer(MapboxMap mapboxMap) async {
      try {
        await mapboxMap.style.setStyleLayerProperty('country-fill', 'fill-opacity', 0.0);
        await mapboxMap.style.setStyleLayerProperty('country-fill', 'fill-color', 0x00000000);
      } catch (_) {}
    }
  /// Creează sursa și layerul pentru harta cu țări
  static Future<void> createCountryLayer(MapboxMap mapboxMap, String geoJsonString) async {
    await mapboxMap.style.addSource(GeoJsonSource(
      id: 'countries',
      data: geoJsonString,
    ));
    await mapboxMap.style.addLayer(FillLayer(
      id: 'country-fill',
      sourceId: 'countries',
      fillColor: 0x00000000,
      fillOpacity: 1.0,
    ));
  }

  /// Colorează țările selectate
  static Future<void> colorCountries(MapboxMap? map, List<Map<String, String>> countries) async {
    if (map == null) return;
    if (countries.isEmpty) {
      await removeCountryLayer(map);
      return;
    }
    final filters = countries.map((c) => ["==", ["get", c['key']], c['value']]).toList();
    final filterExpression = filters.length == 1
        ? json.encode(filters[0])
        : json.encode(["any", ...filters]);
    await map.style.setStyleLayerProperty(
      'country-fill',
      'filter',
      filterExpression,
    );
    await map.style.setStyleLayerProperty(
      'country-fill',
      'fill-color',
      "#FFFFFF",
    );
  }

  /// Găsește țara pentru o poziție
  static Map<String, String>? detectCountry(double lat, double lng, Map<String, dynamic> geoJsonData) {
    for (final feature in geoJsonData['features']) {
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
          for (final key in [
            'ISO3166-1-Alpha-3',
            'ISO_A3',
            'iso_a3',
            'ADM0_A3',
            'ISO3166-1-Alpha-2',
            'ISO_A2',
            'name',
            'ADMIN',
          ]) {
            final val = props[key];
            if (val != null && val.toString().isNotEmpty && val.toString() != '-99') {
              return {'key': key, 'value': val.toString()};
            }
          }
        }
        break;
      }
    }
    return null;
  }

  /// Algoritm point-in-polygon
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
