import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class MyPhotoService {
  static const String _collection = 'location_photos';

  static Future<void> uploadPhoto({
    required String userId,
    required String displayName,
    required String? userPhotoUrl,
    required double latitude,
    required double longitude,
    required File imageFile,
    String? countryName,
    String? locationName,
    String? spotifySong,
    String? spotifyArtist,
    String? spotifyAlbumArt,
    List<String> coAuthorIds = const [],
  }) async {
    final id = const Uuid().v4();
    final ref = FirebaseStorage.instance.ref('location_photos/$id.jpg');
    await ref.putFile(imageFile);
    final downloadUrl = await ref.getDownloadURL();

    final cleanCoAuthors =
        coAuthorIds.where((u) => u.isNotEmpty && u != userId).toSet().toList();

    final data = <String, dynamic>{
      'userId': userId,
      'displayName': displayName,
      'userPhotoUrl': userPhotoUrl ?? '',
      'latitude': latitude,
      'longitude': longitude,
      'imageUrl': downloadUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'likesCount': 0,
      'commentsCount': 0,
      'coAuthorIds': cleanCoAuthors,
      'pendingCoAuthorIds': cleanCoAuthors,
      'acceptedCoAuthorIds': <String>[],
    };
    if (countryName != null) data['countryName'] = countryName;
    if (locationName != null) data['locationName'] = locationName;
    if (spotifySong != null) data['spotifySong'] = spotifySong;
    if (spotifyArtist != null) data['spotifyArtist'] = spotifyArtist;
    if (spotifyAlbumArt != null) data['spotifyAlbumArt'] = spotifyAlbumArt;
    await FirebaseFirestore.instance.collection(_collection).doc(id).set(data);
  }

  static Future<List<Map<String, dynamic>>> fetchPhotosNear({
    required double latitude,
    required double longitude,
    required double radiusKm,
    String? onlyUserId,
  }) async {
    Query query = FirebaseFirestore.instance.collection(_collection);
    if (onlyUserId != null) {
      query = query.where('userId', isEqualTo: onlyUserId);
    }
    final snapshot = await query.get();

    final results = <Map<String, dynamic>>[];
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final lat = (data['latitude'] as num).toDouble();
      final lng = (data['longitude'] as num).toDouble();
      if (_distanceKm(latitude, longitude, lat, lng) <= radiusKm) {
        results.add({...data, 'id': doc.id});
      }
    }

    results.sort((a, b) {
      final ta = a['createdAt'] as Timestamp?;
      final tb = b['createdAt'] as Timestamp?;
      if (ta == null || tb == null) return 0;
      return tb.compareTo(ta);
    });
    return results;
  }

  static Future<List<Map<String, dynamic>>> fetchAllPhotos({
    String? onlyUserId,
  }) async {
    Query query = FirebaseFirestore.instance.collection(_collection);
    if (onlyUserId != null) {
      query = query.where('userId', isEqualTo: onlyUserId);
    }
    final snapshot = await query.get();

    return snapshot.docs
        .map((d) => {...(d.data() as Map<String, dynamic>), 'id': d.id})
        .toList();
  }

  static double _distanceKm(
    double lat1, double lng1, double lat2, double lng2,
  ) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
            sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
}
