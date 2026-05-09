import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

class FeedCacheService {
  static const String boxName = 'feed_cache';
  static const String _postsKey = 'posts';

  static Box get _box => Hive.box(boxName);

  static List<Map<String, dynamic>> loadPosts() {
    final raw = _box.get(_postsKey);
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<void> saveSnapshot(QuerySnapshot snapshot) async {
    final posts = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return <String, dynamic>{'id': doc.id, ..._encodeMap(data)};
    }).toList();
    await _box.put(_postsKey, posts);
  }

  static Map<String, dynamic> _encodeMap(Map<String, dynamic> data) {
    return data.map((key, value) => MapEntry(key, _encodeValue(value)));
  }

  static dynamic _encodeValue(dynamic value) {
    if (value is Timestamp) {
      return {'__timestampMillis': value.millisecondsSinceEpoch};
    }
    if (value is Map) {
      return value.map(
        (key, nested) => MapEntry(key.toString(), _encodeValue(nested)),
      );
    }
    if (value is List) {
      return value.map(_encodeValue).toList();
    }
    return value;
  }

  static Map<String, dynamic> decodePost(Map<String, dynamic> cachedPost) {
    return cachedPost.map((key, value) => MapEntry(key, _decodeValue(value)));
  }

  static dynamic _decodeValue(dynamic value) {
    if (value is Map) {
      final timestampMillis = value['__timestampMillis'];
      if (timestampMillis is int) {
        return Timestamp.fromMillisecondsSinceEpoch(timestampMillis);
      }
      return value.map(
        (key, nested) => MapEntry(key.toString(), _decodeValue(nested)),
      );
    }
    if (value is List) {
      return value.map(_decodeValue).toList();
    }
    return value;
  }
}
