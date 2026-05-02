import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geohash_plus/geohash_plus.dart';
import 'package:flutter/foundation.dart';

class LocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Funcția principală care se apelează când utilizatorul intră în aplicație
  Future<void> updateCurrentUserLocation(String userId) async {
    try {
      // 1. Verificăm permisiunile de locație
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Serviciul de locație este dezactivat.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Permisiunea de locație a fost respinsă.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Permisiunea de locație este respinsă permanent.');
        return;
      }

      // 2. Obținem coordonatele actuale
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium, // Poți folosi 'medium' pentru a salva baterie
      );

      // 3. Generăm GeoHash-ul
      // Precizia 9 înseamnă aproximativ o suprafață de 4.7m x 4.7m.
      String geoHash = GeoHash.encode(position.latitude, position.longitude, precision: 9).hash;

      // 4. Actualizăm documentul utilizatorului în Firestore
      await _firestore.collection('users').doc(userId).update({
        'location': {
          'geohash': geoHash,
          'lat': position.latitude,
          'lng': position.longitude,
        },
        'lastActive': FieldValue.serverTimestamp(), // Actualizăm și activitatea!
      });

      debugPrint('Locație actualizată cu succes: $geoHash');

    } catch (e) {
      debugPrint('Eroare la actualizarea locației: $e');
    }
  }
}