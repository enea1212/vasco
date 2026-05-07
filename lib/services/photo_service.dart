import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../helpers/heatmap_helper.dart';

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
  }) async {
    final id = const Uuid().v4();
    final ref = FirebaseStorage.instance.ref('location_photos/$id.jpg');
    await ref.putFile(imageFile);
    final downloadUrl = await ref.getDownloadURL();

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
      if (MyHeatmapHelper.distanceKm(latitude, longitude, lat, lng) <= radiusKm) {
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
}