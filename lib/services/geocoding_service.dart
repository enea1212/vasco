import 'dart:convert';
import 'package:http/http.dart' as http;

class GeocodingService {
  static Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json&lat=$lat&lon=$lng&accept-language=ro',
      );
      final response = await http.get(uri, headers: {
        'User-Agent': 'VascoApp/1.0',
      });
      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      final address = data['address'] as Map<String, dynamic>?;
      if (address == null) return null;

      final city = address['city']
          ?? address['town']
          ?? address['village']
          ?? address['municipality']
          ?? address['suburb']
          ?? address['county'];
      final country = address['country'];

      if (city != null && country != null) return '$city, $country';
      if (country != null) return country as String;
      return null;
    } catch (_) {
      return null;
    }
  }
}
