import 'dart:typed_data';

/// Populated during the splash so MapPage has everything ready on first mount.
class MapDataCache {
  MapDataCache._();

  static String? geoJson;
  static Map<String, dynamic>? geoJsonData;
  static Uint8List? profilePhotoBytes; // raw HTTP bytes for the profile photo

  static bool get geoJsonReady => geoJson != null;
}
